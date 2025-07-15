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

fileprivate class DownloadTasks {
  private let queue = DispatchQueue(label: "de.taz.downloadTasks.queue", attributes: .concurrent)
  private var _tasks: [DownloadTaskData] = []
  
  var tasks: [DownloadTaskData] { queue.sync {_tasks} }
  
  init() {
    // Init from UserDefaults
    if let saved = UserDefaults().downloadTasks { _tasks = saved }
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
    guard Dir(destPath).exists else {
      BackgroundSession._shared?.callback(urlString, BgSessionError.noDirectory(destPath))
      return nil
    }
    let id = newId
    let dlTask = DownloadTaskData(id: id, url: urlString, destPath: destPath, isUnzip: unzip, finished: false, failedCount: 0)
    append(dlTask)
    return dlTask
  }
  
  private func append(_ task: DownloadTaskData) {
    queue.async(flags: .barrier) {
      var combinedArray = (UserDefaults().downloadTasks ?? []) + self._tasks
      combinedArray.append(task)
      
      let uniqueTasks = Dictionary(grouping: combinedArray, by: { $0.id })
        .compactMap { $0.value.first }
      
      self._tasks = uniqueTasks
      UserDefaults().downloadTasks = uniqueTasks
    }
  }
  
  func save(_ task: DownloadTaskData) {
    queue.async(flags: .barrier) {
      if let index = self._tasks.firstIndex(where: { $0.id == task.id }) {
        self._tasks[index] = task
      } else {
        self._tasks.append(task)
      }

      UserDefaults().downloadTasks = self._tasks
    }
  }
  
  func remove(task: DownloadTaskData) {
    queue.async(flags: .barrier) {
      self._tasks.removeAll { $0.id == task.id }
      UserDefaults().downloadTasks = self._tasks
    }
  }
  
  func get(item withId: String?) -> DownloadTaskData? {
    guard let id = withId else { return nil }
    return queue.sync { _tasks.first { $0.id == id } }
  }
}
//  func clear1() {
//    queue.async(flags: .barrier) {
//      self._tasks.removeAll()
//      UserDefaults().downloadTasks = []
//    }
//  }
//}

//fileprivate enum DownloadTaskState { case running, completed, failed }
  

fileprivate struct DownloadTaskData: Codable, DoesLog {
  let url: String
  let id: String
  var failedCount: Int
  var destPath: String
  let isUnzip: Bool
  var finished: Bool
  // Optional: Initializer mit Default-Werten oder Convenience-Logik
  init(id:String, url: String, destPath: String, isUnzip: Bool, finished: Bool, failedCount: Int) {
    self.url = url
    self.id = id
    self.failedCount = failedCount
    self.destPath = destPath
    self.isUnzip = isUnzip
    self.finished = finished
  }
  
  mutating func downloadedTo(path: String){
    if isUnzip {
      let zf = ZipFile(path: path)
      do {
        try zf.unpack(toDir: destPath)
        log("Background download: zip file unpacked to \(destPath)")
      }
      catch {
        log("Background download: unzip failed: \(error)")
      }
    }
    else {
      let filename = url.lastPathComponent
      let dest = "\(destPath)/\(filename)"
      File(path).move(to: destPath)
      log("Background download: file downloaded to \(dest)")
    }
    finished = true
  }
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
/// Downloads using BackgroundSession objects are usually performed in the background
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
/// in the user's defaults database. To remove this data completely (and that of
/// other background sessions) use ``cleanupUserDefaults()``.
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
  
  /**
   Foreground or Background?
   
   on app restart after killed: fetch neue sachen da starte downloads...
   
   nach Chat: "String aus DATA Json" => BAckground immer verwenden und bei vordergrund DL's
   isDiscretionary = false + task.priority = 1.0
   
   */
  private static let backgroundSessionName = "de.taz.download.backgroundsession"
  
  public override var isDebugLogging: Bool { false }
  
  // The callback informing the caller about success/failure
  fileprivate var callback: (String, Error?)->() = {_, _ in}
  // The iOS completion handler
  fileprivate var completionHandler: (()->())?
  // The download tasks for cancelation and resuming?
  fileprivate var tasks: [URLSessionDownloadTask] = []
  fileprivate var downloadTasks = DownloadTasks()
  
  public var hasOpenDownloads: Bool {
    if tasks.count > 0 { return true }
    return downloadTasks.tasks.count > 0
  }
  
  /// Cancels and invalidates the session
  fileprivate func invalidate() {
    for task in tasks {
      task.cancel()
    }
#warning("Array zurücksetzen oder nicht?")
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
    Log.log("Background download resume for session: \(name)")
    let session = shared(callback: callback)
    
    session.completionHandler = completionHandler
    
    session.session.getAllTasks{ tasks in
      session.log("BG Download: Resume found \(tasks.count) tasks")
      for task in tasks {
        session.log("BG Download: → Task ID: \(task.taskDescription ?? "-") | URL: \(task.originalRequest?.url?.absoluteString ?? "-") | State: \(task.state.rawValue)")
        if task.state == .suspended {
          session.log("BG Download: Resuming suspended task: \(task.taskDescription ?? "-")")
          task.resume()
        } else {
          session.log("BG Download: Task already running or completed: \(task.taskDescription ?? "-")")
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
        ? "BgDownload resume: no currentTasks"
        : "BgDownload resume: \(tasks.count) currentTasks")
    
    for task in tasks {
      runningTasks.appendIfPresent(task.taskDescription)
      if task.state == .suspended {
        task.priority = priority
        log("BgDownload: Resuming suspended task: \(task.taskDescription ?? "-")")
        task.resume()
      }
    }
    
    session.getAllTasks{ [weak self] tasks in
      guard let self = self else { return }
      guard !tasks.isEmpty else {
        log("BgDownload: No System tasks to resume found")
        return
      }
      log("BgDownload: \(tasks.count) System tasks to resume found")
      for task in tasks {
        task.priority = priority
        if let id = task.taskDescription {
          if runningTasks.contains(id) { continue }
        }
        if task.state == .suspended {
          log("BG Download: Resuming suspended task: \(task.taskDescription ?? "-")")
          task.resume()
        } else {
          log("BG Download: Task \(task.taskDescription ?? "-"), URL: \(task.originalRequest?.url?.absoluteString ?? "-"), State: \(task.state.rawValue) already running or completed")
        }
      }
    }
    
    guard archived else { return }
    log("BG Download: Resume \(downloadTasks.tasks.count) archived tasks if not yet running")
    
    for downloadTaskData in downloadTasks.tasks {
      if runningTasks.contains(downloadTaskData.id) { continue }
      log("BG Download: Resuming archived task: \(downloadTaskData.id) url: \(downloadTaskData.url)")
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
    
    guard let data = downloadTasks.newDownloadTaskData(for: urlString, destPath: destPath, unzip: unzip) else {
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
  fileprivate func downloadFinished(error err: Error? = nil) {
    log("Download finished. Checking pending tasks... \(err == nil ? "" : "with ERROR")")
    session.getAllTasks {[weak self] tasks in
      let remainingTasks = tasks.filter { $0.state != .completed }
      self?.log("\(remainingTasks.count > 0 ? "⚠️WARNING!":"")...\(remainingTasks.count)/\(tasks.count) tasks remaining")
      for task in remainingTasks {
        self?.log("→ Task ID: \(task.taskIdentifier) | URL: \(task.originalRequest?.url?.absoluteString ?? "-") | State: \(task.state.rawValue)")
      }
      if remainingTasks.count > 0  {
        self?.log("...do not cleanup")
        return
      }
    }
#warning("TODO MAYBE")
    //    cleanup(err)
  }
  
  
  // MARK: - URLSessionDelegate Protocol
  
  // Background processing complete - call background completion handler
  @_documentation(visibility: private)
  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    log("Background session '\(name)' finished")
    if let cb = completionHandler {
      completionHandler = nil
      DispatchQueue.main.async { cb() }
    }
  }
  
  // MARK: - URLSessionTaskDelegate Protocol
  
  // Task has finished data transfer
  @_documentation(visibility: private)
  public override func urlSession(_ session: URLSession, task: URLSessionTask,
                                  didCompleteWithError completionError: Swift.Error?) {
    log("Background session urlSession tId: '\(String(describing: task.taskDescription))' didCompleteWithError err: \(String(describing: completionError))")
    var err: Error? = nil
    if let resp = task.response as? HTTPURLResponse {
      let statusCode = resp.statusCode
      if !(200...299).contains(statusCode) {
        log("...HTTP Error!!")
        err = HttpError.serverError(statusCode)
      }
    }
    
    guard var dd = downloadTasks.get(item: task.taskDescription) else {
      log("No Download Task Item found with ID \(String(describing: task.taskDescription)), url: \(String(describing: task.originalRequest?.url)) errors: \(String(describing: completionError)) / \(String(describing: err))")
      return
    }
    
    if err == nil, completionError != nil, dd.failedCount < maxFailCount { ///Retry!
      dd.failedCount += 1
      startDownload(data: dd, priority: task.priority)
      downloadTasks.save(dd)
    }
    else {
      callback(dd.url, err ?? completionError)
      downloadTasks.remove(task: dd)
    }
  }
  
  // MARK: - URLSessionDownloadDelegate Protocol
  
  // Download has been finished
  @_documentation(visibility: private)
  public override func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                  didFinishDownloadingTo location: URL) {
    log("tId: \(downloadTask.taskDescription ?? "-") url: \(downloadTask.originalRequest?.url?.absoluteString ?? "-")")
    
    guard var dd = downloadTasks.get(item: downloadTask.taskDescription) else {
      log("No Download Task Item found with ID \(String(describing: downloadTask.taskDescription)), url: \(String(describing: downloadTask.originalRequest?.url))")
      return
    }
    
    log("Download Finished for Task with ID \(String(describing: downloadTask.taskDescription)), url: \(String(describing: downloadTask.originalRequest?.url))")
    dd.downloadedTo(path: location.path)
    downloadTasks.save(dd)
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
