//
//  BackgroundSession.swift
//
//  Created by Norbert Thies on 24.02.25.
//  Copyright © 2025 Norbert Thies. All rights reserved.
//

import Foundation

/// Error(s) that may be encountered during BackgroundSession download operations
public enum BgSessionError: LocalizedError {
  /// Download with same url is already running
  case noDirectory(String)
  case invalidName(String)
  
  public var description: String {
    switch self {
      case .noDirectory(let dir):  return "Background download: no directory: \(dir)"
      case .invalidName(let name): return "Background download: invalid name: \(name)"
    }
  }
  public var errorDescription: String? { return description }
}

/// Represents a single download task entry.
fileprivate struct DownloadTaskData: Codable, DoesLog {
  let id: String
  let url: String
  let destPath: String
  let isUnzip: Bool
  var finished: Bool = false
  var failedCount: Int = 0
}

fileprivate extension UserDefaults {
  private static let key = "BackgroundSessionDownloadTasks"
  
  var downloadTasks: [DownloadTaskData]? {
    get {
      if let data = data(forKey: Self.key) {
        return try? JSONDecoder().decode([DownloadTaskData].self, from: data)
      }
      return nil
    }
    set {
      if let newValue = newValue {
        let data = try? JSONEncoder().encode(newValue)
        set(data, forKey: Self.key)
      } else {
        removeObject(forKey: Self.key)
      }
    }
  }
}

/// A thread-safe store for managing download task data using UserDefaults.
fileprivate class DownloadTaskStore: DoesLog {
  private let queue = DispatchQueue(label: "de.taz.downloadTasks.queue", attributes: .concurrent)
  private var _tasks: [DownloadTaskData] = []
  
  /// Returns a snapshot of all stored tasks.
  var tasks: [DownloadTaskData] { queue.sync {_tasks} }
  
  init() {
    // Init from UserDefaults
    if let saved = UserDefaults().downloadTasks {
      _tasks = saved
      log("DownloadTaskStore initialized with \(saved.count) tasks from UserDefaults")
    }
  }
  
  private var newId: String {
    queue.sync {
      let next = _tasks
        .compactMap { Int($0.id) }
        .max()
        .map { $0 + 1 } ?? 1
      return String(next)
    }
  }
  
  fileprivate func newDownloadTaskData(for urlString: String, destPath: String, unzip: Bool) -> DownloadTaskData? {
    let dlTask = DownloadTaskData(id: newId, url: urlString, destPath: destPath, isUnzip: unzip)
    append(dlTask)
    return dlTask
  }
  
  private func append(_ task: DownloadTaskData) {
    queue.async(flags: .barrier) {[weak self] in
      guard let self = self else { return }
      _tasks.append(task)
      UserDefaults().downloadTasks = _tasks
    }
  }
  
  func save(_ task: DownloadTaskData) {
    queue.async(flags: .barrier) {[weak self] in
      guard let self = self else { return }
      if let index = _tasks.firstIndex(where: { $0.id == task.id }) {
        _tasks[index] = task
        log("item with \(task.id) updated")
      } else {
        _tasks.append(task)
        log("item with \(task.id) saved")
      }
      UserDefaults().downloadTasks = _tasks
    }
  }
  
  func remove(task: DownloadTaskData) {
    queue.async(flags: .barrier) {[weak self] in
      guard let self = self else { return }
      _tasks.removeAll { $0.id == task.id }
      UserDefaults().downloadTasks = _tasks
    }
  }
  
  func removeAll() {
    queue.async(flags: .barrier) {[weak self] in
      guard let self = self else { return }
      _tasks = []
      UserDefaults().downloadTasks = []
    }
  }
  
  func get(item withId: String?) -> DownloadTaskData? {
    guard let id = withId else { return nil }
    return queue.sync {[weak self] in
      guard let self = self else { return nil }
      return _tasks.first { $0.id == id }
    }
  }
}

/// One BackgroundSession is used to download files (optionally unzipping it)
/// from an HTTP(S) URL.
///
/// Unlike downloads via ``HttpSession`` this class uses a system process to
/// download files. This process decides when to start the download (eg. waiting
/// for network availability). When the system has completed the download to
/// a temporary file it informs a BackgroundSession object about the availability
/// of the data. During that time the system may have suspended the app. In that
/// case it restarts the app and delivers an event to the recreated BackgroundSession
/// object.
///
/// Downloads using BackgroundSession object are usually performed in the background
/// (eg. upon delivery of a push notification) or when large files have to be
/// transfered.
///
/// To download a file from the URL _url_ to a directory _dir_ perform the
/// following steps:
///
/// ```swift
///   func dlCallback(err: Error?) {
///     // download has been completed, handle eventual error
///   }
///   ...
///   do {
///     let bgs = try BackgroundSession(url, callback: dlCallback)
///     bgs.download(toDir: dir)
///   }
///   catch ...
/// ```
/// The initializer may throw an Error which should be handled. _dlCallback_
/// is called when the download is complete and has been moved to _dir_. The
/// Error _err_ is nil when no errors occurred, otherwise it indicates the type
/// of error.
/// To handle the case of app suspension you have to provide a method
///
/// ```swift
///   application(_:handleEventsForBackgroundURLSession:completionHandler:)
/// ```
///
/// in your _UIApplicationDelegate_. This method must call
///
/// ```swift
/// BackgroundSession.resume(name: identifier, completionHandler: completionHandler,
///                          callback: dlCallback)
/// ```
/// The _identifier_ must be the same as the _handleEventsForBackgroundURLSession_
/// parameter passed to the _UIApplicationDelegate_ function.
/// This method recreates the BackgroundSession, informs the system via
/// _completionHandler_ that the session is ready to receive events.
///
/// To download and implictly unpack a zip file use ``downloadZip(toDir:)``
/// in the example. The downloaded file will be removed after unpacking
/// all files from it.
///
/// To recreate the BackgroundSession upon app suspension some data is preserved
/// using UserDefaults. If the app crashes it may happen that this data remains
/// in the user's defaults store. To remove this data completely (and that of
/// other background sessions) use ``cleanupUserDefaults()``.
///
/// Background Downloads can also handled in App foreground State!
///
/// For the app to use background downloads and remote notifications under iOS
/// you should add the following capabilities to your Info.plist:
/// ```xml
///  <key>UIBackgroundModes</key>
///  <array>
///    <string>fetch</string>
///    <string>processing</string>
///    <string>remote-notification</string>
///  </array>
/// ```
/// To check for these values at runtime use:
/// - ``App.mayBackgroundFetch``
/// - ``App.mayBackgroundProcess``
/// - ``App.mayBackgroundNotification``
///
open class BackgroundSession: HttpSession {
  
  let maxFailCount = 3
  
  @Default("lastDownloadTaskIdentifier")
  var lastDownloadTaskIdentifier: Int
  
  private static let backgroundSessionName = "de.taz.download.backgroundsession"
  
  public override var isDebugLogging: Bool { false }
  
  // The callback informing the caller about success/failure
  fileprivate var callback: (String, Error?)->() = {_, _ in}
  // The iOS completion handler
  fileprivate var completionHandler: (()->())?
  // The download tasks for cancelation and resuming?
  fileprivate var tasks: [URLSessionDownloadTask] = []
  fileprivate var taskStore = DownloadTaskStore()
  
  public var hasOpenDownloads: Bool {
    if tasks.count > 0 { return true }
    return taskStore.tasks.count > 0
  }
  
  public static func cleanupUserDefaults() {
    UserDefaults().downloadTasks = []
  }
  
  /// Cancels and invalidates the session
  fileprivate func cleanup() {
    log("BackgroundSession cleanup tasks: \(tasks.count) and taskStore: \(taskStore.tasks.count)")
    for task in tasks { task.cancel() }
    taskStore.removeAll()
    tasks = []
    session.invalidateAndCancel()
    debug("Invalidated session \(name)")
  }
  
  /// Factory method returning an already defined session (if it has been previously created)
  ///
  /// This method should be called when the download is complete, the app has been
  /// restartet and the UIApplicationDelegate method
  /// ```swift
  ///   application(_:handleEventsForBackgroundURLSession:completionHandler:)
  /// ```
  /// is called.
  ///
  /// - Parameters:
  ///   - name: identifier passed to the application delegate
  ///   - completionHandler: the completionHandler passed to the application delegate
  ///   - callback: closure to call when download is finished, if successful,
  ///               the passed Error value is nil
  ///
  /// - Returns: the previously defined BackgroundSession
  ///
  /// - Throws: `BgSessionError.alreadyInUse` if a session for the same URL is already in use
  /// - Throws: `BgSessionError.invalidName` if name is not a number
  /// - Throws: `BgSessionError.notFound` if a session named _name_ is undefined
  ///
  static public func resumeBackgroundURLSession(name: String, completionHandler: @escaping ()->(),
                                                callback: @escaping (String, Error?)->()) {
    let session = shared(callback: callback)
    session.log("resume Downloads for session: \(name)")
    session.completionHandler = completionHandler
    
    session.session.getAllTasks{ tasks in
      session.log("found \(tasks.count) tasks to handle")
      for task in tasks {
        session.log("→ Task ID: \(String(describing: task.taskDescription)) | URL: \(String(describing: task.originalRequest?.url?.absoluteString)) | State: \(task.state.rawValue)")
        if task.state == .suspended {
          session.log("Resuming suspended task: \(String(describing: task.taskDescription))")
          task.resume()
        } else {
          session.log("Task already running or completed: \(String(describing: task.taskDescription))")
        }
      }
    }
  }
  
  /// Resumes all Downloads with the specified priority.
  /// - Parameters:
  ///   - archived: Also resume UserDefaults archived Download Tasks
  ///   - completion: Called when download finishes or fails.
  public func resume(archived: Bool, priority: Float = URLSessionTask.defaultPriority){
    let priority = max(0.0, min(priority, 1.0))
    var runningTasks = [String]()
    log(tasks.isEmpty
        ? "resume: no currentTasks"
        : "resume: \(tasks.count) currentTasks")
    
    for task in tasks {
      runningTasks.appendIfPresent(task.taskDescription)
      if task.state == .suspended {
        task.priority = priority
        log("...resuming suspended task: \(task.taskDescription ?? "-")")
        task.resume()
      }
    }
    
    session.getAllTasks{ [weak self] tasks in
      guard let self = self else { return }
      guard !tasks.isEmpty else {
        log("No System tasks to resume found")
        return
      }
      log("\(tasks.count) System tasks to resume found")
      for task in tasks {
        task.priority = priority
        if let id = task.taskDescription {
          if runningTasks.contains(id) { continue }
        }
        if task.state == .suspended {
          log("...Resuming suspended task: \(task.taskDescription ?? "-")")
          task.resume()
        } else {
          log("...Task \(task.taskDescription ?? "-"), URL: \(task.originalRequest?.url?.absoluteString ?? "-"), State: \(task.state.rawValue) already running or completed")
        }
      }
    }
    
    guard archived else { return }
    log("Resume \(taskStore.tasks.count) archived tasks if not yet running")
    
    for downloadTaskData in taskStore.tasks {
      if runningTasks.contains(downloadTaskData.id) { continue }
      log("...Resuming archived task: \(downloadTaskData.id) url: \(downloadTaskData.url)")
      startDownload(data: downloadTaskData, priority: priority)
    }
  }
  
  // Initiate background download
  public func download(urlString: String, destPath: String, unzip: Bool, priority: Float = 0.5) {
    guard URL(string: urlString) != nil else {
      callback(urlString, error(HttpError.invalidURL(urlString)))
      return
    }
    guard Dir(destPath).exists else {
      callback(urlString, error(BgSessionError.noDirectory(destPath)))
      return
    }
    
    guard let data = taskStore.newDownloadTaskData(for: urlString, destPath: destPath, unzip: unzip) else {
      log("Background download failed for url: \(urlString) ")
      return
    }
    
    startDownload(data: data)
    log("Background download started with id: \(data.id) url: \(urlString) destPath: \(destPath) isUnzip: \(unzip)")
  }
  
  /// Starts a background download task with the specified priority.
  /// - Parameters:
  ///   - data: The DownloadTaskData object to download.
  ///   - priority: A value between 0.0 (low) and 1.0 (high). Values outside this range are clamped.
  fileprivate func startDownload(data: DownloadTaskData, priority: Float = URLSessionTask.defaultPriority) {
    
    let priority = max(0.0, min(priority, 1.0))
    
    guard let rurl = URL(string: data.url) else {
      callback(data.url, error(HttpError.invalidURL(data.url)))
      return
    }
    let task = session.downloadTask(with: rurl)
    task.taskDescription = data.id
    task.priority = priority
    if tasks.contains(where: { $0.taskDescription == data.id }) == false {
      tasks.append(task)
    }
    task.resume()
  }
  
  // Background download failed
  fileprivate func logStatus(source: String) {
    session.getAllTasks {[weak self] tasks in
      guard let self = self else { return }
      let incompleetedTasks = tasks.filter { $0.state != .completed }
      log("Check from: \(source) remaining tasks:\n Session.open(\(incompleetedTasks.count))\n Session.total(\(tasks.count))\n Owned(\(self.tasks.count))\n Store(\(self.taskStore.tasks.count))")
    }
  }
  
  private func handleDownloadedFile(tempPath: String, for downloadTask: URLSessionDownloadTask) {
    guard var item = taskStore.get(item: downloadTask.taskDescription) else {
      log("No Download Task Item found with ID \(String(describing: downloadTask.taskDescription)), url: \(String(describing: downloadTask.originalRequest?.url))")
      return
    }
    log("Handle for Task with ID \(String(describing: downloadTask.taskDescription)), url: \(String(describing: downloadTask.originalRequest?.url))")
    
    let tempFile = File(tempPath)
    
    ///additionally check and handle missing target dir error here, its maybe deleted meanwhile!?
    guard Dir(item.destPath).exists else {
      tempFile.remove()
      taskStore.remove(task: item)
      callback(item.url, error(BgSessionError.noDirectory(item.destPath)))
      return
    }
    
    if item.isUnzip {
      let zf = ZipFile(path: tempPath)
      do {
        try zf.unpack(toDir: item.destPath)
        log("Zip file unpacked to \(item.destPath)")
      }
      catch let error {
        log("unzip failed: \(error)")
        tempFile.remove()
        taskStore.remove(task: item)
        callback(item.url, error)
        return
      }
    }
    else {
      let filename = item.url.lastPathComponent
      let dest = "\(item.destPath)/\(filename)"
      tempFile.move(to: item.destPath)
      log("file downloaded to \(dest)")
    }
    item.finished = true
    taskStore.save(item)
  }
  
  // MARK: - URLSessionDelegate Protocol
  // Background processing complete - call background completion handler
  @_documentation(visibility: private)
  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    log("Background session finished \(taskStore.tasks.count) tasks open")
    logStatus(source: "urlSessionDidFinishEvents")
    cleanup()
    completionHandler?()
    completionHandler = nil
  }
  
  // MARK: - URLSessionTaskDelegate Protocol
  
  // Task has finished data transfer
  @_documentation(visibility: private)
  public override func urlSession(_ session: URLSession, task: URLSessionTask,
                                  didCompleteWithError completionError: Swift.Error?) {
    log("Task: '\(String(describing: task.taskDescription))' didComplete err: \(String(describing: completionError))")
    var err: Error? = nil
    if let resp = task.response as? HTTPURLResponse {
      let statusCode = resp.statusCode
      if !(200...299).contains(statusCode) {
        log("...HTTP Error!!")
        err = HttpError.serverError(statusCode)
      }
    }
    
    guard var item = taskStore.get(item: task.taskDescription) else {
      log("No Download Task Item found with ID \(String(describing: task.taskDescription)), url: \(String(describing: task.originalRequest?.url))")
      callback(task.originalRequest?.url?.absoluteString ?? "unknown", err ?? completionError)
      return
    }
    
    if err == nil, completionError != nil, item.failedCount < maxFailCount { ///Retry!
      item.failedCount += 1
      startDownload(data: item, priority: task.priority)
      taskStore.save(item)
    }
    else {
      callback(item.url, err ?? completionError)
      taskStore.remove(task: item)
    }
  }
  
  // MARK: - URLSessionDownloadDelegate Protocol
  
  // Download has been finished
  @_documentation(visibility: private)
  public override func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                  didFinishDownloadingTo location: URL) {
    handleDownloadedFile(tempPath: location.path, for: downloadTask)
  }
  
  
  // MARK: - Factory & Singleton
  fileprivate static var _shared: BackgroundSession?
  
  /// Returns the shared BackgroundSession instance using a background URLSession.
  /// Always uses a background session, even if the app is in the foreground.
  /// Ensures consistent download handling across app lifecycle (foreground/background).
  ///
  /// - Parameter callback: Completion handler called when a download finishes.
  /// - Returns: Shared BackgroundSession instance.
  public static func shared(callback: @escaping (String, Error?) -> Void) -> BackgroundSession {
    if _shared == nil {
      _shared = BackgroundSession(name: backgroundSessionName, isBackground: true)
    }
    _shared?.callback = callback
    return _shared!
  }
} // BackgroundSession
