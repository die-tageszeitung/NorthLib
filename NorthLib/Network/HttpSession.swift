//
//  HttpSession.swift
//
//  Created by Norbert Thies on 16.05.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import UIKit

/// DlFile describes a file that is downloadable from a HTTP server
public protocol DlFile {
  /// Name of file on server (will be appended to a base URL)
  var name: String { get }
  /// Modification time of file
  var moTime: Date { get }
  /// Size in bytes
  var size: Int64 { get }
  /// SHA256 checksuum
  var sha256: String { get }
  /// Expected mime type (if any)
  var mimeType: String? { get }  
} // DlFile

public extension DlFile {  
  /// exists checks whether self already is stored in the given directory,
  /// aside from pure existence the size and moTime are also checked
  func exists(inDir: String) -> Bool {
    let f = File(dir: inDir, fname: name)
    return f.exists && (f.mTime == moTime) && (f.size == size)
  }
  
  func existsIgnoringTime(inDir: String) -> Bool {
    let f = File(dir: inDir, fname: name)
    return f.exists && (f.size == size)
  }
}

/// Error(s) that may be encountered during HTTP operations
public enum HttpError: LocalizedError {
  /// unknown or invalid URL
  case invalidURL(String)
  /// HTTP status code signals an error
  case serverError(Int)
  /// Unexpected Mime Type received
  case unexpectedMimeType(String)
  /// Unexpected file size encountered
  case unexpectedFileSize(Int64, Int64)
  /// Invalid SHA256
  case invalidSHA256(String)
  
  public var description: String {
    switch self {
      case .invalidURL(let url): return "Invalid URL: \(url)"
      case .serverError(let statusCode): return "HTTP Server Error: \(statusCode)"
      case .unexpectedMimeType(let mtype): return "Unexpected Mime Type: \(mtype)"
      case .unexpectedFileSize(let toSize, let expected): 
        return "Unexpected File Size: \(toSize), expected: \(expected)"
      case .invalidSHA256(let sha256): return "Invalid SHA256: \(sha256)"
    }
  }    
  public var errorDescription: String? { return description }
}


extension URLRequest: ToString {
  
  /// Access request specific HTTP headers
  public subscript(hdr: String) -> String? {
    get { return self.value(forHTTPHeaderField: hdr) }
    set { setValue(newValue, forHTTPHeaderField: hdr) }
  }
  
  public func toString() -> String {
    var ret: String = "URLRequest: \(self.url?.absoluteString ?? "[undefined URL]")"
    if let rtype = self.httpMethod { ret += " (\(rtype))" }
    if let data = self.httpBody { ret += ", data: \(data.count) bytes" }
    return ret
  }
  
} // URLRequest


public extension URLResponse {
  /// Access response specific HTTP headers
  subscript(hdr: String) -> String? {
    get { 
      guard let resp = self as? HTTPURLResponse else { return nil }
      return resp.allHeaderFields[hdr] as? String
    }
  }
}  // URLResponse


/// Notifications sent for downloaded data
extension Notification.Name {
  public static let httpSessionDownload = NSNotification.Name("httpSessionDownload")
}


/**
 A HttpJob uses an URLSessionTask to perform a HTTP request.
 */
open class HttpJob: DoesLog {
  
  /// Log debug messages if HttpSession does
  public var isDebugLogging: Bool { return HttpSession.isDebug }
  /// The task performing the request in its own thread
  public var task: URLSessionTask
  /// The task ID
  public var tid: Int { return task.taskIdentifier }
  /// If an error was encountered, this variable points to it
  public var httpError: Error?
  /// returns true if an error was encountered
  public var wasError: Bool { return httpError != nil }
  /// Result of operation
  public var result: Result<Data?,Error> { 
    if wasError { return .failure(httpError!) }
    else { return .success(receivedData) }
  }
  /// The URL of the object downloading
  public var url: String? { task.originalRequest?.url?.absoluteString }
  /// Is end of transmission
  public var isEOT: Bool = false
  /// Expected mime type
  public var expectedMimeType: String?
  /// Pathname of file downloading data to
  private var filename: String?
  
  /// returns true if the job is performing a download task
  public var isDownload: Bool { task is URLSessionDownloadTask }
  public var request: URLRequest? { return task.originalRequest }
  public var response: HTTPURLResponse? { return task.response as? HTTPURLResponse }

  // closure to call upon Error or completion
  fileprivate var closure: ((HttpJob)->())?
  // closure to call upon progress
  fileprivate var progressClosure: ((HttpJob, Data?)->())?
  // Data received via GET/POST
  fileprivate var receivedData: Data?
  
  /// Define closure to call upon progress updates
  public func onProgress(closure: @escaping (HttpJob, Data?)->()) 
    { progressClosure = closure }

  /// Initializes with an existing URLSessionTask and a closure to call upon
  /// error or completion.
  public init(task: URLSessionTask, filename: String? = nil,
              closure: @escaping(HttpJob)->()) {
    self.task = task
    self.filename = filename
    self.closure = closure
  }
  
  // A file has been downloaded
  fileprivate func fileDownloaded(file: URL) {
    var fn = self.filename
    if fn == nil { fn = tmppath() }
    debug("Task \(tid): downloaded \(File.basename(fn!))")
    File(file).move(to: fn!)
  }
  
  // Calls the closure
  fileprivate func close(error: Error? = nil, fileReceived: URL? = nil) {
    self.httpError = error
    if let file = fileReceived, error == nil {
      fileDownloaded(file: file)
    }
    isEOT = true
    if isDownload { notifyDownload() }
    closure?(self)
  }
 
  // Calls the progress closure on the main thread
  fileprivate func progress(data: Data? = nil) {
    if !isEOT { progressClosure?(self, data) }
  }

  // Notify completion of download
  fileprivate func notifyDownload() {
    let nc = NotificationCenter.default
    nc.post(name: Notification.Name.httpSessionDownload, object: self)
  }
  
  // Data received
  fileprivate func dataReceived(data: Data) {
    if self.receivedData != nil { self.receivedData!.append(data) }
    else { self.receivedData = data }
    progress(data: data)
  }

} // HttpJob


/** 
 A HttpSession uses Apple's URLSession to communicate with a remote
 server via HTTP(S). 
 
 Each HTTP request is performed using a HttpJob object, that is an encapsulation
 of an URLSessionTask.
 */
open class HttpSession: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate, URLSessionDataDelegate, DoesLog {
  
  /// Perform debug logging?
  public static var isDebug: Bool = true
  public var isDebugLogging: Bool { return HttpSession.isDebug }

  /// Dictionary of background completion handlers 
  public static var bgCompletionHandlers: [String:()->()] = [:]  
  // Optional name of (background) session
  fileprivate var name: String  
  // HTTP header to send with HTTP request
  public var header: [String:String] = [:]  
  
  /// Configure as background session
  public var isBackground = false { didSet { _config = nil } }
  /// Set doCache to true to enable caching
  public var isCache = false { didSet { _config = nil } }
  /// Allow mobile network operations
  public var allowMobile = true { didSet { _config = nil } }
  /// Set waitForAvailability to true if a connection should wait for network availability
  public var waitForAvailability = false { didSet { _config = nil } }

  fileprivate var _config: URLSessionConfiguration? { didSet { _session = nil } }
  /// Session configuration
  public var config: URLSessionConfiguration {
    if _config == nil { _config = getConfig() }
    return _config!
  }
  
  public var _session: URLSession?  
  /// URLSession
  public var session: URLSession {
    if _session == nil {
      _session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    return _session!
  }
  
  // Number of HttpSession incarnations
  fileprivate static var incarnations: Int = 0
  fileprivate lazy var syncQueue: DispatchQueue = {
    HttpSession.incarnations += 1
    let qname = "HttpSession.\(HttpSession.incarnations)"
    return DispatchQueue(label: qname)
  }()
  
  // Dictionary of running HttpJobs
  fileprivate var jobs: [Int:HttpJob] = [:]
  
  /// Return Job for given task ID
  public func job(_ tid: Int) -> HttpJob? {
    syncQueue.sync { jobs[tid] }
  }
  
  /// Create a new HTTPJob with given task
  public func createJob(task: URLSessionTask, filename: String? = nil,
                        closure: @escaping(HttpJob)->()) {
    let job = HttpJob(task: task, filename: filename, closure: closure)
    debug("New HTTP Job \(job.tid) created: \(job.url ?? "[undefined URL]")")
    syncQueue.sync {
      jobs[job.tid] = job
    }
    job.task.resume()
  }
  
  /// Close a job with given task ID
  public func closeJob(tid: Int, error: Error? = nil, fileReceived: URL? = nil) {
    var job: HttpJob?
    syncQueue.sync {
      job = jobs[tid]
      jobs[tid] = nil
    }
    if let job = job {
      debug("Closing HTTP Job \(job.tid): \(job.url ?? "[undefined URL]")")
      job.close(error: error, fileReceived: fileReceived)
    }
  }
  
  fileprivate func getConfig() -> URLSessionConfiguration {
    let config = isBackground ? 
      URLSessionConfiguration.background(withIdentifier: name) : 
      URLSessionConfiguration.default
    if isBackground {
      config.networkServiceType = .background
      config.isDiscretionary = true
      config.sessionSendsLaunchEvents = false
    }
    else {
      config.networkServiceType = .responsiveData
      config.isDiscretionary = false
    }
    config.httpCookieStorage = HTTPCookieStorage.shared
    config.httpCookieAcceptPolicy = .onlyFromMainDocumentDomain
    config.httpShouldSetCookies = true
    config.urlCredentialStorage = URLCredentialStorage.shared
    config.httpAdditionalHeaders = [:]
    config.waitsForConnectivity = false
    if isCache {
      config.urlCache = URLCache.shared
      config.requestCachePolicy = .useProtocolCachePolicy
    }
    else {
      config.urlCache = nil
      config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    }
    config.allowsCellularAccess = allowMobile
    config.waitsForConnectivity = waitForAvailability
    return config
  }
  
  // notification handler called upon termination
  @objc fileprivate func onTermination() {
    debug("will shortly been terminated")
  }
  
  // notification handler called when loosing focus
  @objc fileprivate func onBackground() {
    debug("will go to background")
  }
  
  // Use a unique name to identify this session
  public init(name: String, isBackground: Bool = false) {
    self.name = name
    self.isBackground = isBackground
    super.init()
    let nc = NotificationCenter.default
    nc.addObserver(self, selector: #selector(onBackground), 
      name: UIApplication.willResignActiveNotification, object: nil)
    nc.addObserver(self, selector: #selector(onTermination), 
      name: UIApplication.willTerminateNotification, object: nil)
  }
  
  // Factory method producing a background session
  static public func background(_ name: String) -> HttpSession {
    return HttpSession(name: name, isBackground: true)
  }
  
  // produce URLRequest from URL url
  fileprivate func request(url: URL) -> Result<URLRequest,Error> {
    var req = URLRequest(url: url)
    for (key,val) in header {
      req[key] = val
    }
    return .success(req)
  }

  // produce URLRequest from String url
  fileprivate func request(url: String) -> Result<URLRequest,Error> {
    guard let rurl = URL(string: url) else { 
      return .failure(error(HttpError.invalidURL(url))) 
    }
    return request(url: rurl)
  }

  /// Get some data from a web server
  public func get(_ url: String, from: Int = 0, returnOnMain: Bool = true,
                  closure: @escaping(Result<Data?,Error>)->()) {
    let res = request(url: url)
    guard var req = try? res.get()
      else { closure(.failure(res.error()!)); return }
    req.httpMethod = "GET"
    if from != 0 { req["Range"] = "bytes=\(from)-" }
    let task = session.dataTask(with: req)
    createJob(task: task) { (job) in
      if returnOnMain { onMain { closure(job.result) } }
      else { closure(job.result) }
    }
  }
  
  /// Post data and retrieve response
  public func post(_ url: String, data: Data, returnOnMain: Bool = true,
                   closure: @escaping(Result<Data?,Error>)->()) {
    let res = request(url: url)
    guard var req = try? res.get()
      else { closure(.failure(res.error()!)); return }
    req.httpMethod = "POST"
    req.httpBody = data
    let task = session.dataTask(with: req)
    createJob(task: task) { (job) in
      if returnOnMain { onMain { closure(job.result) } }
      else { closure(job.result) }
    }
  }
    
  /**
   Downloads the passed DlFile data from the base URL of a server and checks it's 
   size and SHA256.
   
   If the file has already been downloaded and its size and motime are identical 
   to those given in the DlFile, then no download is performed.
   */
  public func downloadDlFile(baseUrl: String, file: DlFile, toDir: String,
                             cacheDir: String? = nil,
                             closure: @escaping(Result<HttpJob?,Error>)->()) {
    if file.exists(inDir: toDir) { closure(.success(nil)) }
    else if let cache = cacheDir, file.exists(inDir: cache) {
      let src = File(cache + "/" + file.name)
      src.copy(to: toDir + "/" + file.name)
      closure(.success(nil))
    }
    else {
      debug("download: \(file.name) - doesn't exist in \(File.basename(toDir))")
      let url = "\(baseUrl)/\(file.name)"
      let toFile = File(dir: toDir, fname: file.name)
      let res = request(url: url)
      guard var req = try? res.get()
        else { closure(.failure(res.error()!)); return }
      req.httpMethod = "GET"
      let task = session.downloadTask(with: req)
      Dir(toDir).create()
      createJob(task: task, filename: toFile.path) { [weak self] job in
        if job.wasError { closure(.failure(job.httpError!)) }
        else { 
          var err: Error? = nil
          toFile.mTime = file.moTime
          if toFile.size != file.size 
            { err = HttpError.unexpectedFileSize(toFile.size, file.size) }
          else if toFile.sha256 != file.sha256
            { err = HttpError.invalidSHA256(toFile.sha256) }
          else { closure(.success(job)) }
          if let err = err { 
            self?.error(err)
            self?.log("* Warning: File \(file.name) successfully downloaded " +
                      "but size and/or checksum is incorrect" )
            // TODO: Report error when the higher layers have been fixed
            closure(.success(job))
            // closure(.failure(err)) 
          }
        }
      }
    }
  }
  
  // MARK: - URLSessionDelegate Protocol
  
  // Is called when all tasks are finished or cancelled
  public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
    logIf(error)
    debug("Session finished or cancelled")
  }
  
  // Background processing complete - call background completion handler
  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    log("Background session '\(name)' finished")
    if let closure = HttpSession.bgCompletionHandlers[name] {
      // completion handler must be called on main queue
      DispatchQueue.main.async { closure() }
      HttpSession.bgCompletionHandlers[name] = nil
    }
  }
  
  // Authentication info is requested
  public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, 
      completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    //debug("Session authentication challenge received: \(challenge.protectionSpace)")
    completionHandler(.performDefaultHandling, nil)
  }
  
  // MARK: - URLSessionTaskDelegate Protocol
  
  // Task has finished data transfer
  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError completionError: Swift.Error?) {
    let tid = task.taskIdentifier
    var err = completionError
    if let resp = task.response as? HTTPURLResponse {
      let statusCode = resp.statusCode
      if !(200...299).contains(statusCode) {
        err = HttpError.serverError(statusCode)
      }
    }
    if err != nil { 
      error("Task \(tid): Download failed.")
      error(err!) 
    }
    else { debug("Task \(tid): Finished data transfer successfully") }
    closeJob(tid: tid, error: err)
  }
  
  // Server requests "redirect" (not in background)
  public func urlSession(_ session: URLSession, task: URLSessionTask, 
                         willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, 
                         completionHandler: @escaping (URLRequest?) -> Void) {
    let tid = task.taskIdentifier
    debug("Task \(tid): Redirect to \(request.url?.absoluteString ?? "[unknown]") received")
    completionHandler(request)
  }
  
  // Upload: data sent to server
  public func urlSession(_ session: URLSession, task: URLSessionTask, 
                         didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
    let tid = task.taskIdentifier
    debug("Task \(tid): Upload data: \(bytesSent) bytes sent, \(totalBytesSent) total bytes sent, \(totalBytesExpectedToSend) total size")
  }
  
  // Upload data: need more data
  public func urlSession(_ session: URLSession, task: URLSessionTask, 
                         needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
    let tid = task.taskIdentifier
    debug("Task \(tid): Upload data: need more data")
  }
  
  // Task authentication challenge received
  public func urlSession(_ session: URLSession, task: URLSessionTask, 
                         didReceive challenge: URLAuthenticationChallenge, 
                         completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    //debug("Task \(task.taskIdentifier): Task authentication challenge received")
  }
  
  // Delayed background task is ready to run
  public func urlSession(_ session: URLSession, task: URLSessionTask, 
    willBeginDelayedRequest request: URLRequest, 
    completionHandler: @escaping (URLSession.DelayedRequestDisposition, 
                                  URLRequest?) -> Void) {
    let tid = task.taskIdentifier
    debug("Task \(tid): Delayed background task is ready to run")
    completionHandler(.continueLoading, nil)
  }
  
  // Task is waiting for network availability (may be reflected in the UI)
  public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
    let tid = task.taskIdentifier
    debug("Task \(tid): Task is waiting for network availability")
  }
  
  // Task metrics received
  public func urlSession(_ session: URLSession, task: URLSessionTask, 
                         didFinishCollecting metrics: URLSessionTaskMetrics) {
    let tid = task.taskIdentifier
    if #available(iOS 13.0, *) {
      let sent = metrics.transactionMetrics[0].countOfRequestBodyBytesSent
      let received = metrics.transactionMetrics[0].countOfResponseBodyBytesReceived
      debug("Task \(tid): Task metrics received - \(sent) bytes sent, \(received) bytes received")
    } else {
      debug("Task \(tid): Task metrics received")
    }
  }
  
  // MARK: - URLSessionDownloadDelegate Protocol
  
  // Download has been finished
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, 
    didFinishDownloadingTo location: URL) {
    var err: Error? = nil
    let tid = downloadTask.taskIdentifier
    if let job = job(tid) { 
      if let resp = job.response {
        let statusCode = resp.statusCode
        if !(200...299).contains(statusCode) {
          err = HttpError.serverError(statusCode)
          error(err!)
        }
      }
      debug("Task \(tid): Download completed to: .../\(location.lastPathComponent)")
      closeJob(tid: tid, error: err, fileReceived: location)
    }
  }
  
  // Paused download has been resumed
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, 
                         didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
    let tid = downloadTask.taskIdentifier
    debug("Task \(tid): Resume paused Download")
  }
  
  // Data received and written to file
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, 
                         didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                         totalBytesExpectedToWrite: Int64) {
    let tid = downloadTask.taskIdentifier
    if let job = job(tid) { job.progress() }
    //debug("Task \(tid): Data received: \(bytesWritten) bytes written to file")
  }
  
  // MARK: - URLSessionDataDelegate Protocol
  
  // Data received
  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    let tid = dataTask.taskIdentifier
    //debug("Task \(tid): Data received: \(data.count) bytes")
    if let job = job(tid) { job.dataReceived(data: data) }
  }
  
  // Data task was converted to download task
  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, 
                         didBecome downloadTask: URLSessionDownloadTask) {
    let tid = dataTask.taskIdentifier
    if let job = job(tid) { job.task = downloadTask }
    debug("Task \(tid): Data task converted to download task")
  }
  
  // Data task was converted to stream task
  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, 
                         didBecome streamTask: URLSessionStreamTask) {
    let tid = dataTask.taskIdentifier
    if let job = job(tid) { job.task = streamTask }
    debug("Task \(tid): Data task converted to stream task")
  }
  
  // Initial reply from server received
  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, 
    didReceive response: URLResponse, completionHandler: 
    @escaping (URLSession.ResponseDisposition) -> Void) {
    let tid = dataTask.taskIdentifier
    guard let job = job(tid) else { return }
    var err: Error?
    if let response = response as? HTTPURLResponse {
      debug("Task \(tid): Initial reply from server received: \(response.statusCode)")
      if (200...299).contains(response.statusCode) {
        if let mtype = job.expectedMimeType, mtype != response.mimeType {
          err = HttpError.unexpectedMimeType(response.mimeType ?? "[undefined]")
        }
        else { completionHandler(.allow); return }
      }
      else { err = HttpError.serverError(response.statusCode) }
      completionHandler(.cancel)
      closeJob(tid: tid, error: err)
    }
  }
  
  // Caching policy requested
  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, 
                         willCacheResponse proposedResponse: CachedURLResponse, completionHandler: 
    @escaping (CachedURLResponse?) -> Void) {
    let tid = dataTask.taskIdentifier
    debug("Task \(tid): Caching policy requested")
    completionHandler(proposedResponse)
  }

} // HttpSession

/// A class for downloading an array of DlFile's
open class HttpLoader: ToString, DoesLog {
  /// HttpSession to use for downloading
  var session: HttpSession
  /// Base Url to download from
  var baseUrl: String
  /// Directory to download to
  var toDir: String
  /// Optional cache directory to try before going online
  var cacheDir: String?
  /// nb. of files downloaded
  public var downloaded = 0
  /// nb. bytes downloaded
  public var downloadSize: Int64 = 0
  /// total nb. bytes to download
  public var totalSize: Int64 = 0
  /// nb. of files already available
  public var available = 0
  /// nb. of errors
  public var errors = 0
  /// Last Error
  public var lastError: Error?
  /// Closure to call when finished
  public var closure: ((HttpLoader)->())?
  /// Closure to call when before/after single file download
  public var progressClosure: ((HttpLoader, Int64, Int64)->())?
  /// Semaphore used to wait for a single download to finish
  private var semaphore = DispatchSemaphore(value: 0)
  
  public func toString() -> String {
    var ret = "downloaded: \(downloaded), "
    ret += "available: \(available), "
    ret += "errors: \(errors)"
    if downloaded > 0 { ret += ", DL size: \(downloadSize)" }
    return ret
  }
  
  /// Init with base URL and destination directory
  public init(session: HttpSession, baseUrl: String, toDir: String,
              fromCacheDir: String? = nil) {
    self.session = session
    self.baseUrl = baseUrl
    self.toDir = toDir
    self.cacheDir = fromCacheDir
  }
  
  // count download
  fileprivate func count(_ res: Result<HttpJob?,Error>, size: Int64) {
    switch res {
    case .success(let job): 
      if job == nil { available += 1 } 
      else { 
        downloaded += 1
        downloadSize += size
      }     
    case .failure(let err):
      errors += 1
      lastError = err
    }
    semaphore.signal()
  }
    
  // Download next file in list
  func downloadNext(file: DlFile) {
    session.downloadDlFile(baseUrl: baseUrl, file: file, toDir: toDir,
                           cacheDir: self.cacheDir) { [weak self] res in
      guard let self = self else { return }
      self.count(res, size: file.size)
      if let progressClosure = self.progressClosure, file.size > 0 {
        onMain { progressClosure(self, self.downloadSize, self.totalSize) }
      }
    }
  }

  // Download array of DlFiles
  public func download(_ files: [DlFile], 
                       onProgress: ((HttpLoader, Int64, Int64)->())? = nil,
                       atEnd: @escaping (HttpLoader)->()) {
    self.closure = atEnd
    self.progressClosure = onProgress
    DispatchQueue.global(qos: .background).async { [weak self] in
      guard let self = self else { return }
      var toDownload: [DlFile] = []
      self.downloadSize = 0
      for file in files {
        if !file.exists(inDir: self.toDir) {
          toDownload += file
          self.totalSize += file.size
        }
      }
      onMain { self.progressClosure?(self, 0, self.totalSize) }
      for file in toDownload {
        self.downloadNext(file: file)
        _ = self.semaphore.wait(timeout: .now() + 5)
      }
      onMain { [weak self] in
        self?.closure?(self!)
      }
    }
  }
  
} // HttpLoader
