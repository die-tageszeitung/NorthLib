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
  case alreadyInUse(String)
  case unzipFailed(String)
  case noDirectory(String)
  case notFound(String)
  case invalidName(String)
  
  public var description: String {
    switch self {
      case .alreadyInUse(let url): return "Background download: already running: \(url)"
      case .unzipFailed(let msg):  return "Background download: unzip failed: \(msg)"
      case .noDirectory(let dir):  return "Background download: no directory: \(dir)"
      case .notFound(let name):    return "Background download: not found: \(name)"
      case .invalidName(let name): return "Background download: invalid name: \(name)"
    }
  }    
  public var errorDescription: String? { return description }
}


fileprivate extension UserDefaults {
  private static let bgSessKey = "BackgroundSessions"
  
  var backgroundSessions: [String: Any]? {
    get {
      dictionary(forKey: Self.bgSessKey)
    }
    set {
      if let newValue = newValue {
        set(newValue, forKey: Self.bgSessKey)
      } else {
        removeObject(forKey: Self.bgSessKey)
      }
    }
  }
}

/// A BackgroundSession is used to download one file (optionally unzipping it)
/// from an HTTP(S) URL.
/// 
/// Unlike downloads via ``HttpSession`` this class uses a system process to
/// download a file. This process decides when to start the download (eg. waiting
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
  public override var isDebugLogging: Bool { false }
  // Synchronize thread access
  static fileprivate var spoint = Serial(label: "NorthLib.BackgroundSession")
  static fileprivate func queue(_ closure: @escaping ()->Int) -> Int
  { return spoint.queue(closure: closure) }
  
  /// Session number of _this_ session
  public private(set) var sessionNumber: Int
  
  /// Dictionary of background sessions
  public private(set) static var bgSessions: [String:BackgroundSession] = [:]
  // The callback informing the caller about success/failure
  fileprivate var callback: (String, Error?)->() = {_, _ in}
  // The iOS completion handler
  fileprivate var completionHandler: (()->())?
  /// Url of file to download
  public private(set) var url: String
  /// Directory to write download to
  public private(set) var destPath: String?
  /// Should a zip-file be extracted (zip is removed after extraction)
  public private(set) var isUnzip: Bool = false
  // The download task
  fileprivate var task: URLSessionDownloadTask?
  
  // Create new session number
  fileprivate static func newSession() -> Int {
    return queue {
      var last: Int = 0
      var sessions: [String:Any] = [:]
      if let sess = UserDefaults().backgroundSessions {
        sessions = sess
      }
      if let tmp = sessions["lastSessionNumber"] as? Int {
        Log.log("found lastSessionNumber: \(tmp)")
        last = tmp
      }
      else {
        
      }
      last += 1
      sessions["lastSessionNumber"] = last
      UserDefaults().backgroundSessions = sessions
      return last
    }
  }
  
  /// Cancels and invalidates the session
  fileprivate func invalidate() {
    task?.cancel()
    session.invalidateAndCancel()
    debug("Invalidated session \(name)")
  }
  
  // Write session configuration to user defaults
  fileprivate func persistUserDefaults() {
    var pdata: [String:Any] = [:]
    pdata["url"] = url
    pdata["destPath"] = destPath
    pdata["isUnzip"] = isUnzip
    var sessions: [String:Any] = [:]
    if let sess = UserDefaults().backgroundSessions {
      sessions = sess
    }
    sessions[name] = pdata
    UserDefaults().backgroundSessions = sessions
  }
  
  // Recreate session from user defaults
  fileprivate static func fromUserDefaults(name: String, isBackground: Bool) throws -> BackgroundSession {
    if let sess = UserDefaults().backgroundSessions,
       let pdata = sess[name] as? [String:Any] {
      if let destPath = pdata["destPath"] as? String,
         let url = pdata["url"] as? String,
         let isUnzip = pdata["isUnzip"] as? Bool {
        let bgs = BackgroundSession(url, name: name, isBackground: isBackground)
        bgs.destPath = destPath
        bgs.isUnzip = isUnzip
        return bgs
      }
    }
    throw BgSessionError.notFound(name)
  }
  
  // Remove session data from user defaults and remove session from bgSessions dictionary
  fileprivate func removeUserDefaults() {
    if var sess = UserDefaults().backgroundSessions {
      log("removed user defaults")
      sess[name] = nil
      if sess.count == 1, sess["lastSessionNumber"] != nil {
        sess["lastSessionNumber"] = nil
        log("removed lastSessionNumber")
      }
      UserDefaults().backgroundSessions = sess
    }
    else {
      log("cannot remove user defaults: not found")
    }
    log("BackgroundSession count: \(UserDefaults().backgroundSessions?.count ?? -1)")
  }
  
  /// Remove all BackgroundSession data from UserDefaults
  ///
  /// There may be some session data left in UserDefaults (eg. as a result of
  /// app crashes). This method removes all BackgroundSession-related data from
  /// UserDefaults.
  ///
  static public func cleanupUserDefaults() {
    UserDefaults().backgroundSessions = nil
  }
  
  // Initializer used internally
  fileprivate init(_ url: String, name: String? = nil, isBackground: Bool) {
    var n: String
    if name == nil {
      self.sessionNumber = BackgroundSession.newSession()
      n = String(sessionNumber)
    }
    else {
      n = name!
      self.sessionNumber = Int(n)!
    }
    self.url = url
    super.init(name: n, isBackground: isBackground)
    debug("name=\(n)")
    BackgroundSession.bgSessions[n] = self
  }
  
  /// Initialize a new background session with an url to download from and
  /// a callback to inform when the download is finished or an Error has been
  /// detected.
  ///
  /// This doesn't start the download, use either ``download(toDir:)`` or
  /// ``downloadZip(toDir:)``. If this initializer doesn't fail all other
  /// error conditions are passed to the callback closure as Error value.
  /// The closure may be called on an arbitrary thread which will usually
  /// not be the main thread.
  ///
  /// - Parameters:
  ///   - url: HTTP(S) url of file to download (String)
  ///   - asBackgroundSession: true if background session should be used
  ///   - callback: closure to call when download is finished, if successful,
  ///               the passed Error value is nil
  ///
  /// - Throws: `BgSessionError.alreadyInUse` if a session for the same URL is already in use
  ///
  public convenience init(_ url: String, name: String? = nil, asBackgroundSession: Bool, callback: @escaping (String, Error?)->()) throws {
    if BackgroundSession.search(url: url) { throw BgSessionError.alreadyInUse(url) }
    ///do not use Background Session in Simulator it did not work!
    let background = Device.isSimulator ? false : asBackgroundSession
    self.init(url, name: name, isBackground:background)
    self.callback = callback
  }
  
  // Search for active (in memory) BackgroundSession
  static private func searchActive(url: String) -> Bool {
    for (_, sess) in bgSessions {
      if sess.url == url { return true; }
    }
    return false
  }
  
  // Search for BackgroundSession waiting for completion
  static private func searchWaiting(url: String) -> String? {
    if let sessions = UserDefaults().backgroundSessions {
      for (name, sess) in sessions {
        if let s = sess as? [String:Any], let surl = s["url"] as? String {
          if surl == url { return name }
        }
      }
    }
    return nil
  }
  
  public static var waitingCount: Int {
    if let sessions = UserDefaults().backgroundSessions {
      ///first item is maybe not a session its a index
      return sessions.count
    }
    return 0
  }
  
  public static func logWaiting() {
    if let sessions = UserDefaults().backgroundSessions {
      for (name, sess) in sessions {
        if let s = sess as? [String:Any], let surl = s["url"] as? String {
          Log.log("Waiting Session: \(name) url: \(surl)")
        }
        else {
          Log.log("Waiting Session: \(name) content: \(sess)")
        }
      }
    }
  }
  
  /// Search for active (in memory) BackgroundSessions or Sessions waiting to
  /// be resumed.
  ///
  /// This methods takes a String _url_ as argument and searches for BackgroundSessions
  /// downloading this _url_. Such a Session may be in memory (has been started and
  /// the App has not been suspended) or is represented via UserDefaults and is
  /// waiting to be resumed.
  ///
  /// - Parameters:
  ///   - url: the url of the file to download
  ///
  /// - Returns: true (is downloading) or false
  ///
  static public func search(url: String) -> Bool {
    return searchActive(url: url) || searchWaiting(url: url) != nil
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
  @discardableResult
  static public func resumeBackgroundURLSession(name: String, completionHandler: @escaping ()->(),
                                                callback: @escaping (String, Error?)->()) throws -> BackgroundSession {
    guard Int(name) != nil else { throw BgSessionError.invalidName(name) }
    var bgsession: BackgroundSession
    if let bgsess = BackgroundSession.bgSessions[name] {
      bgsession = bgsess
      bgsession.log("Background download resume: session found: \(name) delegate: \(String(describing: bgsession.session.delegate))")
    }
    else {
      bgsession = try fromUserDefaults(name: name, isBackground: true)
      bgsession.log("Background download resume: session recreated: \(bgsession.url) delegate: \(String(describing: bgsession.session.delegate))")
    }
    bgsession.callback = callback
    bgsession.completionHandler = completionHandler
    bgsession.session.getAllTasks { tasks in
      bgsession.log("Resume found \(tasks.count) tasks")
      for task in tasks {
        bgsession.log("→ Task ID: \(task.taskIdentifier) | URL: \(task.originalRequest?.url?.absoluteString ?? "-") | State: \(task.state.rawValue)")
        if task.state == .suspended {
          bgsession.log("Resuming suspended task: \(task.taskIdentifier)")
          task.resume()
        } else {
          bgsession.log("Task already running or completed: \(task.taskIdentifier)")
        }
      }
      if tasks.count == 0, let url = URL(string: bgsession.url) {
        // Not running → start it again!
        let request = URLRequest(url: url)
        let task = bgsession.session.downloadTask(with: request)
        task.resume()
      }
    }
    return bgsession
  }
  
  public static func restartAllArchivedDownloads(callback: @escaping (String, Error?)->()) throws {
    if let sessions = UserDefaults().backgroundSessions {
      Log.log("Restarting \(sessions.count) sessions.")
      for (name, sess) in sessions {
        if let s = sess as? [String:Any], let surl = s["url"] as? String {
          try Self.resumeBackgroundURLSession(name: name, completionHandler: {
            Log.log("Background download resume finished for \(name) url: \(surl)")
          }, callback: callback)
        }
      }
    }
  }
  
  /// Checks if there are active or completed downloads for the given session URL,
  /// and optionally cancels suspended or active tasks. Returns `true` only if
  /// active/completed tasks are found **and not cancelled** (i.e., `cancelActiveDownloads == false`).
  ///
  /// - Parameters:
  ///   - sessionWithUrl: The session URL to check for.
  ///   - cancelIfSuspended: If true, any suspended tasks will be cancelled. Default is true.
  ///   - cancelActiveDownloads: If true, running or completed tasks will be cancelled. If false, such tasks cause this method to return `true`.
  ///
  /// - Returns: `true` if an active or completed task was found **and not cancelled**; otherwise, `false`.
  public static func hasActiveDownload(
    for sessionWithUrl: String,
    cancelIfSuspended: Bool = true,
    cancelActiveDownloads: Bool
  ) -> Bool {
    Log.log("Look for active Downloads for url: \(sessionWithUrl) \(cancelIfSuspended ? "and CANCEL IF SUSPENDED" : "") \(cancelActiveDownloads ? "and CANCEL ACTIVE Downloads" : "")")
    
    for (name, sess) in bgSessions {
      guard sess.url == sessionWithUrl else { continue }
      Log.log("...session found!")
      var foundActive = false
      let semaphore = DispatchSemaphore(value: 0)
      sess.session.getAllTasks { tasks in
        Log.log("...\(tasks.count) tasks found")
        for task in tasks {
          guard task is URLSessionDownloadTask else { continue }
          switch task.state {
            case .running, .completed:
              if cancelActiveDownloads {
                Log.log("Active/completed task found – cancelling")
                task.cancel()
              } else {
                foundActive = true
              }
            case .suspended:
              if cancelIfSuspended {
                Log.log("Suspended task found – cancelling")
                task.cancel()
              }
            default:
              break
          }
        }
        if !foundActive {
          Log.log("remove session")
          sess.invalidate()
          sess.removeUserDefaults()
          BackgroundSession.bgSessions[name] = nil
        }
        semaphore.signal()
      }
      let timeoutResult = semaphore.wait(timeout: .now() + 2.0)
      if timeoutResult == .timedOut {
        Log.log("Timeout: task inspection took too long")
        return false
      }
      return foundActive
    }
    return false
  }
  
  public static func restartAllPendingDownloads() {
    Log.log("🎲 Restarting all pending downloads! bgSession Count: \(bgSessions.count)")
      // Durchlaufe alle aktiven Sessions
    for (_, sess) in bgSessions {
      // Hole alle Tasks der Session

      sess.session.getAllTasks { tasks in
        var resumedCount = 0
        for task in tasks {
          if task.state == .suspended {
            task.resume()
            resumedCount += 1
          }
        }
        Log.log("Restarted \(resumedCount) pending tasks for session: \(sess.url)")
      }
    }
  }
  
  // Initiate background download
  fileprivate func download() {
    guard let rurl = URL(string: url) else {
      callback(url, error(HttpError.invalidURL(url)))
      return
    }
    guard Dir(destPath!).exists else {
      callback(url, error(BgSessionError.noDirectory(destPath!)))
      return
    }
    task = session.downloadTask(with: rurl)
    task?.resume()
    log("Background download started: \(name) url: \(url) config: \(config)")
  }
    
  /// Download file to directory 'toDir'
  ///
  /// The download is performed via an iOS system process. During that time
  /// the calling process may be terminated. In that case it is restarted when
  /// the download is complete and the UIApplicationDelegate method
  /// ```swift
  ///   application(_:handleEventsForBackgroundURLSession:completionHandler:)
  /// ```
  /// is called.
  ///
  /// The directory _toDir_ must exist, otherwise the closure passed to the
  /// initializer is called with an Error value. If the file to download
  /// already exists at _toDir_ it will be overwritten.
  /// - Parameters:
  ///   - toDir: path to directory for storing the download
  public func download(toDir: String) {
    destPath = toDir
    persistUserDefaults()
    download()
  }
  
  public func download(files: [String], toDir: String) {
    guard files.count > 0 else {
      let err =
      NSError(domain: "de.taz.northLib.BackgroundSession", code: 1, userInfo: [NSLocalizedDescriptionKey: "No files to download"])
      callback(url, error(err))
      return
    }
    
    destPath = toDir
    persistUserDefaults()
    
    guard let rurl = URL(string: url) else {
      callback(url, error(HttpError.invalidURL(url)))
      return
    }
    
    guard Dir(destPath!).exists else {
      callback(url, error(BgSessionError.noDirectory(destPath!)))
      return
    }
    
    var enqueuedDownloadTasks = 0
    
    log("Download: \(files) from \(url) to \(destPath!)")
    
    for fileName in files {
      let sUrl = url + "/" + fileName
      guard let furl = URL(string: sUrl) else {
        log("Skip Invalid URL Download: \(sUrl)")
        continue
      }
      log("Download \(sUrl)")
      let fileTask = session.downloadTask(with: rurl)///not used so can be overwritten
      fileTask.resume()
      enqueuedDownloadTasks += 1
    }
    
    log("Background downloads started: \(name) url: \(url) config: \(config) filesCount: \(enqueuedDownloadTasks)")
    ///No Valid Downloads, nothing to wait for
    if enqueuedDownloadTasks == 0 { callback(url, error(HttpError.invalidURL(url))) }
  }
  
  /// Download zip file to directory 'toDir' (zip file will be unpacked and removed)
  ///
  /// The download is performed via an iOS system process. During that time
  /// the calling process may be terminated. In that case it is restarted when
  /// the download is complete and the UIApplicationDelegate method
  /// ```swift
  ///   application(_:handleEventsForBackgroundURLSession:completionHandler:)
  /// ```
  /// is called.
  ///
  /// The directory _toDir_ must exist, otherwise the closure passed to the
  /// initializer is called with an Error value. If the files to unpack
  /// already exist at _toDir_ they will be overwritten.
  ///
  /// - Parameter toDir: path to directory for unpacking the download to
  public func downloadZip(toDir: String) {
    isUnzip = true
    download(toDir: toDir)
  }
    
  // Do some cleanup: remove user default values and remove session from bgSessions
  fileprivate func cleanup(_ err: Error? = nil) {
    removeUserDefaults()
    log("Session: \(name) | total session count: \(BackgroundSession.bgSessions.count) err: \(String(describing: err)) ")
    BackgroundSession.bgSessions[name] = nil
    if let err { error("Background download failed for url: \(url) with error: \(err)") }
    callback(url, err)
  }
    
  /// Cleans up all known background sessions and removes stale entries.
  /// Avoids double invalidation by tracking already handled session names.
  /// maybe not needed? due ??? appdelegate resumes, error cleans
  public static func cleanupAllSessions() {
    _ = BackgroundSession.queue {
      var cleanedSessions = Set<String>()
      let dummyURL = "https://localhost/cleanup"
      
      // Invalidate all in-memory sessions
      for (name, bgSession) in bgSessions {
        if !cleanedSessions.contains(name) {
          bgSession.invalidate()
          cleanedSessions.insert(name)
        }
      }
      
      if let sessions = UserDefaults().backgroundSessions {
        for (name, _) in sessions {
            // Skip invalid session names e.g. "lastSessionNumber"
          if Int(name) == nil { continue }
          if !cleanedSessions.contains(name) {
            // Create dummy session only to invalidate it
            let dummySession = BackgroundSession(dummyURL, name: name, isBackground: true)
            dummySession.invalidate()
            cleanedSessions.insert(name)
          }
        }
      }
      // Final cleanup
      cleanupUserDefaults()
      bgSessions.removeAll()
      Log.log("BackgroundSession cleanup complete. Invalidated \(cleanedSessions.count) session(s).")
      return 0
    }
  }
  
  // Background download completed successfully
  fileprivate func downloadCompleted(path: String) {
    debug("Background download completed to tmp: \(path)")
    if isUnzip {
      let zf = ZipFile(path: path)
      do {
        try zf.unpack(toDir: destPath!)
        log("Background download: zip file unpacked to \(destPath!)")
      }
      catch { log("Background download: unzip failed: \(error)")}
    }
    else {
      let filename = url.lastPathComponent
      let dest = "\(destPath!)/\(filename)"
      File(path).move(to: dest)
      log("Background download: file downloaded to \(dest)")
    }
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
    cleanup(err)
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
    log("Background session urlSession tId: '\(task.taskIdentifier)' didCompleteWithError err: \(String(describing: completionError))")
    var err: Error? = nil
    if let resp = task.response as? HTTPURLResponse {
      let statusCode = resp.statusCode
      if !(200...299).contains(statusCode) {
        log("...HTTP Error!!")
        err = HttpError.serverError(statusCode)
      }
    }
    downloadFinished(error: err ?? completionError)
  }
  
  // MARK: - URLSessionDownloadDelegate Protocol
  
  // Download has been finished
  @_documentation(visibility: private)
  public override func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                  didFinishDownloadingTo location: URL) {
    log("Background session urlSession(URLSession, URLSessionDownloadTask, didFinishDownloadingTo URL) tId: '\(downloadTask.taskIdentifier)' ")
    downloadCompleted(path: location.path)
  }

} // BackgroundSession
