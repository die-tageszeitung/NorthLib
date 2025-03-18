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
  
  // Synchronize thread access
  static fileprivate var spoint = Serial(label: "NorthLib.BackgroundSession")
  static fileprivate func queue(_ closure: @escaping ()->Int) -> Int
    { return spoint.queue(closure: closure) }
  
  /// Session number of _this_ session
  public private(set) var sessionNumber: Int
  
  /// Dictionary of background sessions
  public private(set) static var bgSessions: [String:BackgroundSession] = [:]
  // The callback informing the caller about success/failure
  fileprivate var callback: (Error?)->() = {_ in}
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
  // User Defaults
  fileprivate var udef = UserDefaults()
  
  // Create new session number
  fileprivate static func newSession() -> Int {
    return queue { 
      var last: Int = 0
      var udef = UserDefaults()
      var sessions: [String:Any] = [:]
      if let sess = udef.dictionary(forKey: "BackgroundSessions") {
        sessions = sess
      }
      if let tmp = sessions["lastSessionNumber"] as? Int { last = tmp }
      last += 1
      sessions["lastSessionNumber"] = last
      udef.set(sessions, forKey: "BackgroundSessions")
      return last
    }
  }
  
  // Write session configuration to user defaults
  fileprivate func persistUserDefaults() {
    var pdata: [String:Any] = [:]
    pdata["url"] = url
    pdata["destPath"] = destPath
    pdata["isUnzip"] = isUnzip
    var sessions: [String:Any] = [:]
    if let sess = udef.dictionary(forKey: "BackgroundSessions") {
      sessions = sess
    }
    sessions[name] = pdata
    udef.set(sessions, forKey: "BackgroundSessions")
  }
  
  // Recreate session from user defaults
  fileprivate static func fromUserDefaults(name: String) throws -> BackgroundSession {
    let udef = UserDefaults()
    if let sess = udef.dictionary(forKey: "BackgroundSessions"),
       let pdata = sess[name] as? [String:Any] {
      if let destPath = pdata["destPath"] as? String,
         let url = pdata["url"] as? String,
         let isUnzip = pdata["isUnzip"] as? Bool { 
        var bgs = BackgroundSession(url, name: name)
        bgs.destPath = destPath
        bgs.isUnzip = isUnzip
        return bgs
      }
    }
    throw BgSessionError.notFound(name)
  }
  
  // Remove session data from user defaults and remove session from bgSessions dictionary
  fileprivate func removeUserDefaults() {
    if var sess = udef.dictionary(forKey: "BackgroundSessions") {
      log("removed user defaults")
      sess[name] = nil
    }
    else {
      log("cannot remove user defaults: not found")
    }
  }
  
  /// Remove all BackgroundSession data from UserDefaults
  /// 
  /// There may be some session data left in UserDefaults (eg. as a result of
  /// app crashes). This method removes all BackgroundSession-related data from
  /// UserDefaults.
  /// 
  static public func cleanupUserDefaults() {
    UserDefaults().removeObject(forKey: "BackgroundSessions")
  }
  
  // Initializer used internally
  fileprivate init(_ url: String, name: String? = nil) {
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
    super.init(name: n, isBackground: true)
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
  ///   - callback: closure to call when download is finished, if successful,
  ///               the passed Error value is nil
  ///  
  /// - Throws: `BgSessionError.alreadyInUse` if a session for the same URL is already in use 
  ///   
  public convenience init(_ url: String, callback: @escaping (Error?)->()) throws {
    for (name, bgsess) in BackgroundSession.bgSessions {
      if bgsess.url == url { throw BgSessionError.alreadyInUse(url) }
    }
    self.init(url)
    self.callback = callback
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
  static public func resume(name: String, completionHandler: @escaping ()->(), 
    callback: @escaping (Error?)->()) throws -> BackgroundSession {
    guard Int(name) != nil else { throw BgSessionError.invalidName(name) }
    var bgsession: BackgroundSession
    if let bgsess = BackgroundSession.bgSessions[name] { 
      bgsession = bgsess
      bgsession.debug("Background download resume: session found: \(name)")
    }
    else { 
      bgsession = try fromUserDefaults(name: name)
      bgsession.debug("Background download resume: session recreated: \(bgsession.url)")
    }
    bgsession.callback = callback
    bgsession.completionHandler = completionHandler
    return bgsession
  }
  
  // Initiate background download
  fileprivate func download() {
    guard let rurl = URL(string: url) else { 
      callback(error(HttpError.invalidURL(url)))
      return
    }
    guard Dir(destPath!).exists else {
      callback(error(BgSessionError.noDirectory(destPath!)))
      return
    }
    task = session.downloadTask(with: rurl)
    task?.resume()
    debug("Background download started: \(name)")
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
  /// 
  /// - Parameter toDir: path to directory for storing the download
  ///
  public func download(toDir: String) {
    destPath = toDir
    persistUserDefaults()
    download()
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
  /// 
  public func downloadZip(toDir: String) {
    isUnzip = true
    download(toDir: toDir)
  }
    
  // Do some cleanup: remove user default values and remove session from bgSessions
  fileprivate func cleanup(_ err: Error? = nil) {
    removeUserDefaults()
    log("\(name) session count: \(BackgroundSession.bgSessions.count)")
    BackgroundSession.bgSessions[name] = nil
    if let err { error("Background download failed: \(err)") }
    callback(err)
  }
  
  // Background download completed successfully
  fileprivate func downloadCompleted(path: String) {
    debug("Background download completed to tmp: \(path)")
    var err: Error? = nil
    if isUnzip {
      let zf = ZipFile(path: path)
      do { 
        try zf.unpack(toDir: destPath!)
        log("Background download: zip file unpacked to \(destPath!)")
      }
      catch { err = BgSessionError.unzipFailed(error.description) }
    }
    else {
      let filename = url.lastPathComponent
      let dest = "\(destPath!)/\(filename)"
      File(path).move(to: dest)
      log("Background download: file downloaded to \(dest)")
    }
    cleanup(err)
  }
  
  // Background download failed
  fileprivate func downloadFailed(error err: Error) {
    cleanup(err)
  }
  

  // MARK: - URLSessionDelegate Protocol
  
  // Background processing complete - call background completion handler
  @_documentation(visibility: private)
  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    debug("Background session '\(name)' finished")
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
    var err = completionError
    if let resp = task.response as? HTTPURLResponse {
      let statusCode = resp.statusCode
      if !(200...299).contains(statusCode) {
        err = HttpError.serverError(statusCode)
      }
    }
    if let err { downloadFailed(error: err) }
  }
  
  // MARK: - URLSessionDownloadDelegate Protocol
  
  // Download has been finished
  @_documentation(visibility: private)
  public override func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, 
                                  didFinishDownloadingTo location: URL) {
    downloadCompleted(path: location.path)
  }

} // BackgroundSession
