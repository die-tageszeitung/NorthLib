//
//  WebView.swift
//
//  Created by Norbert Thies on 01.08.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit
import WebKit
import SafariServices

/// A JSCall-Object describes a native call from JavaScript to Swift
open class JSCall: DoesLog, ToString {
  
  /// name of the NativeBridge object
  public var objectName = ""
  /// name of the method called
  public var method = ""
  /// callback ID
  public var callback: Int?
  /// array of arguments
  public var args: [Any]?
  /// WebView object receiving the call
  public weak var webView: WebView?
  // should callback be called delayed
  public var delayCallback = false
  
  /// A new JSCall object is created using a WKScriptMessage
  public init(_ msg: WKScriptMessage) throws {
    if let dict = msg.body as? Dictionary<String,Any> {
      objectName = msg.name
      webView = msg.webView as? WebView
      if let m = dict["method"] as? String {
        method = m
        callback = dict["callback"] as? Int
        args = dict["args"] as? [Any]
      }
      else { throw exception( "JSCall without name of method" ) }
    }
    else { throw exception( "JSCall without proper message body" ) }
  }
  
  /// Call back to JS
  public func callback(arg: Any, isDelayed: Bool = false) {
    if let callbackIndex = self.callback,
      !delayCallback || isDelayed {
      let dict: [String:Any] = ["callback": callbackIndex, "result": arg]
      let callbackJson = dict.json
      let execString = "\(self.objectName).callback(\(callbackJson))"
      webView?.jsexec(execString, closure: nil)
    }
  }
  
  /// Return arguments as String
  public func arguments2s(delimiter: String = "") -> String {
    var ret = ""
    if let args = args, args.count > 0 {
      for arg in args {
        if let str = arg as? CustomStringConvertible {
          if ret.isEmpty { ret = str.description }
          else { ret += "\(delimiter)\(str.description)" }
        }
      }
    }
    return ret
  }
  
  public func toString() -> String {
    var ret = "JSCall: \(objectName).\(method)\n"
    if let cb = callback { ret += "  callback ID: \(cb)" }
    if let args = args, args.count > 0 {
      ret += "\n  \(args.count) Argument(s):"
      for arg in args {
        if let str = arg as? CustomStringConvertible {
          ret += "\n    \(type(of: arg)) \"\(str.description)\""
        }
      }
    }
    return ret
  }
  
} // class JSCall

/// A JSBridgeObject describes a JavaScript object containing
/// methods that are passed to native functions
open class JSBridgeObject: DoesLog {
  
  /// Name of JS object
  public var name: String
  /// Dictionary of JS function names to native closures
  public var functions: [String:(JSCall)->Any] = [:]
  
  /// calls a native closure
  public func call(_ jscall: JSCall) {
    if let f = functions[jscall.method] {
      let method = jscall.method
      if method != "log" && method != "alert" {
        debug( "From JS: '\(jscall.objectName).\(jscall.method)' called" )
      }
      let retval = f(jscall)
      jscall.callback(arg: retval)
    }
    else {
      error( "From JS: undefined function '\(jscall.objectName).\(jscall.method)' called" )
    }
  }
  
  /// Initialize with name of JS object
  public init(name: String) { 
    self.name = name 
    addfunc("log") { jscall in
      self.log("JS: \(jscall.arguments2s())")
      return NSNull()
    }
    addfunc("alert") { jscall in
      Alert.message(message: jscall.arguments2s())
      return NSNull()
    }
  }
  
  /// Add a JS function defined by a native closure
  public func addfunc(_ name: String, closure: @escaping (JSCall)->Any) {
    self.functions[name] = closure
  }

  /// The JS code defining the JS class for the bridge object:
  public static var js: String = """
  /// The NativeBridge offers an interface to iOS native functions. By default
  /// every bridge offers the functions 'log' and 'alert'.
  class NativeBridge {

    /// Initialize with a String defining the name of the bridge object,
    /// this name is also used on the native side to identify this object.
    constructor(bridgeName) {
      this.bridgeName = bridgeName;
      this.callbacks = {};
      this.lastId = 1;
    }

    /// call a native function named 'method', give a callback function 'func'
    /// and a number of arguments to pass to the native side as native objects.
    call(method, func, ...args) {
      var nativeCall = {};
      nativeCall.method = method;
      if ( func != undefined && typeof func == "function" ) {
        nativeCall.callback = this.lastId;
        this.callbacks[this.lastId] = func;
        this.lastId++;
      }
      if ( args.length > 0 ) {
        nativeCall.args = args;
      }
      let str = "webkit.messageHandlers." + this.bridgeName + ".postMessage(nativeCall)"
      try { eval(str) }
      catch (error) {
        this.log("Native call error: " + error )
      }
    }
    
    /// Is called by the native side to call the callback function
    callback(ret) {
      if (ret.callback) {
        var func = this.callbacks[ret.callback];
        if ( func ) {
          delete this.callbacks[ret.callback];
          func.apply( null, [ret.result] );
        }
      }
    } 
    
    /// Send a log message to the native side
    log(...args) {
      var callArgs = ["log", undefined];
      callArgs = callArgs.concat(args);
      this.call.apply(this, callArgs);
    }
    
    /// Pop up a native alert message
    alert(...args) {
      var callArgs = ["alert", undefined];
      callArgs = callArgs.concat(args);
      this.call.apply(this, callArgs);    
    }
    
  }  // class NativeBridge

  /// Define window.alert and console.log as bridge functions
  function log2bridge(bridge) {
    console.log = function (...args) { bridge.log.apply(bridge, args); };
    window.alert = function (...args) { bridge.alert.apply(bridge, args); };
  }

  """
  
} // class JSBridgeObject


/// Get String representation of WKNavigationType
extension WKNavigationType: ToString {
  public func toString() -> String {
    switch self {
      case .linkActivated:   return "linkActivated"
      case .formSubmitted:   return "formSubmitted"
      case .backForward:     return "backForward"
      case .reload:          return "reload"
      case .formResubmitted: return "formResubmitted"
      case .other:           return "other"
      default:               return "undefined"
    }
  }
}

/// Get String representation of WKNavigationAction
extension WKNavigationAction: ToString {
  public func toString() -> String {
    "\(navigationType.toString()): \(File.basename(request.description))"
  }
}

open class WebView: WKWebView, WKScriptMessageHandler,
                    WKNavigationDelegate, WKUIDelegate {

  /// JS NativeBridge objects
  public var bridgeObjects: [String:JSBridgeObject] = [:]
  
  /// Directory which local web pages may access for resources
  public var baseDir: String?
  public var baseUrl: URL? { 
    if let d = baseDir { return URL(fileURLWithPath: d) } 
    else { return nil } 
  }
  /// The original URL to load
  public var originalUrl: URL?
  
  /// Number of load errors
  private var errorCount: Int = 0
  /// Max. number of ongoing errors
  private let maxErrorCount = 5
  
  
  public func release(){
    self.whenAvailable { _ in }
    //self.configuration.userContentController.removeAllScriptMessageHandlers()//iOS14
    for obj in bridgeObjects {
      self.configuration.userContentController.removeScriptMessageHandler(forName: obj.key)
    }
//    NotificationCenter.default.removeObserver(self)
  }
  
  /// The closures to call when content has been loaded
  @Callback<WebView>
  public var whenLoaded: Callback<WebView>.Store
  
  /// The closures to call when a link has been pressed
  /// The content part of the argument passed to the closures
  /// will be (from: URL?, to: URL?)
  @Callback<(from: URL?, to: URL?)>
  public var whenLinkPressed: Callback<(from: URL?, to: URL?)>.Store
  
  /// The closures to call when a load error has been detected
  /// The content passed will be err: Error
  @Callback<Error>
  public var whenLoadError: Callback<Error>.Store
      
  /// Set to true when Bridge JS has been loaded
  private var isBridgeLoaded = false
  
  /// Inject Bridge JS code into WebView
  public func injectBridges() {
    if !isBridgeLoaded {
      Task {
        do {
          try await jsexec(JSBridgeObject.js)
          for bridge in bridgeObjects {
            try await jsexec("var \(bridge.key) = new NativeBridge(\"\(bridge.key)\")")
          }
          isBridgeLoaded = true
        }
        catch {
          self.error("Can't inject JS Bridges:\n  \(error)")
        }
      }
    }
  }
  
  /// Define Bridge Object
  public func addBridge(_ object: JSBridgeObject, isExec: Bool = false) {
    self.bridgeObjects[object.name] = object
    self.configuration.userContentController.add(self, name: object.name)
    if isExec { injectBridges() }
  }
  
  /// Perform console.log and window.alert via bridge
  public func log2bridge(name: String) {
    if let bridge = bridgeObjects[name] {
      self.jsexec("log2bridge(\(bridge.name))")
    }
  }
  
  /// Perform console.log and window.alert via bridge
  public func log2bridge(_ bridge: JSBridgeObject) {
    self.jsexec("log2bridge(\(bridge.name))")
  }
  
  /// jsexec executes the passed string as JavaScript expression using
  /// evaluateJavaScript, if a closure is given, it is only called when
  /// there is no error.
  public func jsexec(_ expr: String, closure: ((Any?)->Void)? = nil) {
    self.evaluateJavaScript(expr) {
      [weak self] (retval, error) in
      if let err = error {
        self?.error("JavaScript error: " + err.localizedDescription +
          "\n  in: '\(expr)'")
      }
      else {
        if let callback = closure {
          callback(retval)
        }
      }
    }
  }
  
  /// jsexec executes the passed string as JavaScript expression using
  /// evaluateJavaScript.
  @discardableResult
  public func jsexec(_ expr: String) async throws -> Any? {
    let ret: Result<Any?,Error> = await withCheckedContinuation { continuation in
      evaluateJavaScript(expr) { (retval, err) in
        var result: Result<Any?,Error>
        if err != nil { result = .failure(err!) }
        else { result = .success(retval) }
        continuation.resume(returning: result)
      }
    }
    if let val = ret.value() { return val }
    else {
      throw error("JavaScript error: \(ret.error()!)\n  in: '\(expr)'")
    }
  }
  
  /// calls a native closure
  public func call(_ jscall: JSCall) {
    if let bo = bridgeObjects[jscall.objectName] {
      bo.call(jscall)
    }
    else {
      error("From JS: undefined bridge object '\(jscall.objectName) used")
    }
  }
  
  @discardableResult
  public func load(url: URL, whenFinished: (()->())? = nil) -> WKNavigation? {
    if let closure = whenFinished { whenLoaded { _ in closure() } }
    if isLoading { stopLoading() }
    self.originalUrl = url
    self.errorCount = 0
    if url.isFileURL {
      debug("load: \(url.lastPathComponent), base: \(self.baseUrl?.absoluteString ?? "nil")")
      var base = self.baseUrl
      if base == nil { base = url.deletingLastPathComponent() }
      return loadFileURL(url, allowingReadAccessTo: base!)
    }
    else {
      let request = URLRequest(url: url)
      return load(request)
    }
  }
  
  @discardableResult
  public func load(_ string: String, whenFinished: (()->())? = nil) -> WKNavigation? {
    if let url = URL(string: string) {
      return load(url: url, whenFinished: whenFinished)
    }
    else { return nil }
  }
  
  @discardableResult
  public func load(html: String, whenFinished: (()->())? = nil) -> WKNavigation? {
    if let closure = whenFinished { whenLoaded { _ in closure() } }
    self.errorCount = 0
    return loadHTMLString(html, baseURL: baseUrl)
  }
  
  public private(set) var scrollDelegate = WebViewScrollDelegate()
  
  /// listen for download to refresh content instread of reload multiple times after load failed, may reduce battery impact
  /// if using this soon: thimk about any.html contains any.jpg > html loaded before jpg > need to refresh after jpg loaded!
//  @objc public func handleDownloadNotification(notification: Notification) {
//    if self.errorCount == 0 {
//      log("no need to reload for \(self.originalUrl)")
//      return
//    }
//    guard let url = self.originalUrl else { return }
//    log("notif filename: \((notification.object as? HttpJob)?.filename) url: \(url.lastPathComponent)")
//    self.load(url: url)
//  }
  
  
  public func setup() {
    self.navigationDelegate = self
    self.uiDelegate = self
    self.scrollView.delegate = scrollDelegate
//    NotificationCenter.default.addObserver(self,
//      selector: #selector(handleDownloadNotification),
//      name: Notification.Name.httpSessionDownload, object: nil)
  }
  
  override public init(frame: CGRect, configuration: WKWebViewConfiguration? = nil) {
    var config = configuration
    if config == nil { config = WKWebViewConfiguration() }
    super.init(frame: frame, configuration: config!)
    setup()
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  public func scrollToTop() {
    scrollView.setContentOffset(CGPoint(x:0, y:0), animated: false)
  }
  
  /// Passes the WebView's content as PDF to the given closure
  @available(iOS 14.0, *)
  public func pdf(closure: @escaping (Data?)->()) {
    createPDF { res in closure(res.value()) }
  }
  
  private func nav2a(webView: WKWebView, nav: WKNavigationAction) -> String {
    if let wv = webView as? WebView {
      let url = wv.url?.lastPathComponent ?? "[undefined url]"
      let orig = wv.originalUrl?.lastPathComponent ?? "[undefined url]"
      return "\(url) (orig \(orig)): \(nav.toString())"
    }  
    else { return "[not a WebView]" }
  }
  
  // MARK: - WKScriptMessageHandler protocol
  public func userContentController(_ userContentController: WKUserContentController,
                                    didReceive message: WKScriptMessage) {
    if let jsCall = try? JSCall( message ) {
      call( jsCall)
    }
  }
  
  // MARK: - WKNavigationDelegate protocol
  public func webView(_ webView: WKWebView, decidePolicyFor nav: WKNavigationAction,
                      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
//    debug(nav2a(webView: webView, nav: nav))
    if let wv = webView as? WebView {
      let from = wv.originalUrl?.absoluteString
      let to = nav.request.description
      if from != to, to != "about:blank" {
        let content = (wv.originalUrl, URL(string: to))
        if $whenLinkPressed.count > 0 {
          $whenLinkPressed.notify(sender: self, content: content)
          decisionHandler(.cancel)
        }
        else { decisionHandler(.allow) }
      }
      else { decisionHandler(.allow) }
    }
  }
  
  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    self.errorCount = 0
    isBridgeLoaded = false
    $whenLoaded.notify(sender: self, content: self)
  }
  
  private func handleLoadError(err: Error) {
    stopLoading()
    errorCount += 1
    
    if let failUrl = (err as? URLError)?.failingURL,
       let loadUrl = url,
       loadUrl != failUrl {
      log("Warning recive error for: \(failUrl), but loading: \(loadUrl)")
      return
    }
    
    if let curl = url, File(curl).exists {
      debug("File exist but could not be loaded, try to reload url: \(curl) err count:\(errorCount)")
      onMain(after: 0.1) { [weak self] in
        guard let url = self?.originalUrl else { return }
        self?.load(URLRequest(url: url))
      }
      return
    }
    
    if self.errorCount >= self.maxErrorCount {
      error(err)
      error("Load failed after \(maxErrorCount) retries")
      $whenLoadError.notify(sender: self, content: err)
    }
    else {
      debug("Load error after \(errorCount) retries:\n  \(err)")
      onMain(after: 0.1 * 2**errorCount) { [weak self] in
        guard let url = self?.originalUrl else { return }
        if self?.errorCount == 0 { return }
        self?.load(URLRequest(url: url))
      }
    }
  }
  
  public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                      withError err: Error) {
    handleLoadError(err: err)
  }
  
  public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!,
                      withError err: Error) {
    handleLoadError(err: err)
  }
  
  // MARK: - WKUIDelegate protocol
  
  public func webView(_ webView: WKWebView,
                      runJavaScriptAlertPanelWithMessage message: String,
                      initiatedByFrame frame: WKFrameInfo,
                      completionHandler: @escaping () -> Void) {
    let ac = UIAlertController(title: "JavaScript", message: message,
               preferredStyle: UIAlertController.Style.alert)
    ac.defaultStyle()
    ac.addAction(UIAlertAction(title: "OK",
                               style: UIAlertAction.Style.cancel) { _ in
      completionHandler() })
    UIViewController.top()?.present(ac, animated: true)
  }
  
} // class WebView

// MARK: - UIScrollViewDelegate protocol
public class WebViewScrollDelegate: NSObject, UIScrollViewDelegate{
    
  // content y offset at start of dragging
  private var startDragging: CGFloat?
  
  /// The closures to call when content scrolled more than scrollRatio
  /// The closures get the content arg scrollRatio: CGFloat
  @Callback<CGFloat>
  public var whenScrolled: Callback<CGFloat>.Store
  
  /// The minimum scroll ratio
  public var minScrollRatio: CGFloat = 0
  
  /// The closure to call when some dragging (scrolling with finger down) has been done
  /// The closures get the content arg scrollRatio: CGFloat which is the number of
  /// points scrolled down divided by the content's height
  @Callback<CGFloat>
  public var whenDragged: Callback<CGFloat>.Store
  
  /// The closures to call when content is scrolling
  /// The closures get the content arg scrollOffset: CGFloat
  @Callback<CGFloat>
  public var scrollViewDidScroll: Callback<CGFloat>.Store
  
  /// The closures to call when end dragging
  @Callback<CGFloat>
  public var scrollViewDidEndDragging: Callback<CGFloat>.Store
  
  /// The closures to call when end dragging
  @Callback<CGPoint>
  public var scrollViewDidEndScrolling: Callback<CGPoint>.Store
  
  /// The closures to call when begindragging
  @Callback<CGFloat>
  public var scrollViewWillBeginDragging: Callback<CGFloat>.Store
  
  /// Define closures to call when the end of the web content will become
  /// visible, the content arg is atEnd: Bool.
  @Callback<Bool>
  public var atEndOfContent: Callback<Bool>.Store
  
  
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    if $scrollViewDidScroll.needsNotification {
      $scrollViewDidScroll.notify(sender: self, content: scrollView.contentOffset.y)
    }
  }
  
  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    startDragging = scrollView.contentOffset.y
    if $scrollViewWillBeginDragging.needsNotification {
      $scrollViewWillBeginDragging.notify(sender: self, content: scrollView.contentOffset.y)
    }
    
  }
  
  public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if let sd = startDragging, $whenScrolled.needsNotification {
      let scrolled = sd - scrollView.contentOffset.y
      let ratio = scrolled / scrollView.bounds.size.height
      if abs(ratio) >= minScrollRatio {
        $whenScrolled.notify(sender: self, content: ratio)
      }
    }
    startDragging = nil
    if $whenDragged.needsNotification {
      let ratio = scrollView.contentOffset.y / scrollView.contentSize.height
      $whenDragged.notify(sender: self, content: ratio)
    }
    if $scrollViewDidEndDragging.needsNotification {
      $scrollViewDidEndDragging.notify(sender: self, content: scrollView.contentOffset.y)
    }
    let horizontalScrollable
    = scrollView.frame.size.width + scrollView.contentOffset.x + 10
    < scrollView.contentSize.width
    if horizontalScrollable,
       decelerate == false,
       $scrollViewDidEndScrolling.needsNotification {
      $scrollViewDidEndScrolling.notify(sender: self,
                                        content: scrollView.contentOffset)
    }
  }
  
  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    if $scrollViewDidEndScrolling.needsNotification {
      $scrollViewDidEndScrolling.notify(sender: self,
                                        content: scrollView.contentOffset)
    }
  }
  
  // When dragging stops, check whether the end of content is visible
  public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                        withVelocity velocity: CGPoint,
                                        targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    if $atEndOfContent.needsNotification {
      let offset = targetContentOffset.pointee.y
      $atEndOfContent.notify(sender: self,
                             content: isAtEndOfContent(scrollView: scrollView,
                                                       offset: offset))
    }
  }
  
  /// Returns true if at a given offset the end of the content is visible
  /// (in vertical direction)
  public func isAtEndOfContent(scrollView: UIScrollView, offset: CGFloat) -> Bool {
    let end = scrollView.contentSize.height
    return (offset + scrollView.bounds.size.height) >= end
  }
  
}


/**
 An embedded WebView with a button at the bottom which is displayed when the 
 WebView has been scrolled to its vertical end. In addition a cross (or X) button 
 can be displayed using the "onX"-Method to define a closure that is called when 
 the X-Button has been pressed.
 */
open class ButtonedWebView: UIView {
  
  public class LabelButton: UIView, Touchable {
    public var tapRecognizer = TapRecognizer()
    public var label = UILabel()
    private var bwv: ButtonedWebView!
    public var text: String? { 
      get { label.text }
      set { label.text = newValue; bwv.adaptLayoutConstraints() }     
    }
    public var textColor: UIColor {
      get { label.textColor }
      set { label.textColor = newValue }
    }
    public var font: UIFont {
      get { label.font }
      set { label.font = newValue }
    }
    public var hasContent: Bool { text != nil }
    init(bwv: ButtonedWebView) {
      self.bwv = bwv
      super.init(frame: CGRect())
      self.addSubview(label)
      self.isUserInteractionEnabled = true
      label.backgroundColor = .clear
      pin(label.centerX, to: self.centerX)
      pin(label.centerY, to: self.centerY)
      pinHeight(50)
      pinWidth(250)
    }    
    required init?(coder: NSCoder) { super.init(coder: coder) }
  } 
  
  public var webView: WebView
  /// The label acting as a button
  public lazy var buttonLabel = LabelButton(bwv: self)
  /// The X-Button (may be used to close the webview)
  public var xButton:ButtonControl
  /// Distance between button and bottom as well as button and webview
  public var buttonMargin: CGFloat = 8 { didSet { adaptLayoutConstraints() } }
  private var isButtonVisible = false
  
  public var toggleBottomButton = true {
    didSet {
      if !toggleBottomButton { isButtonVisible = true }
    }
  }
  
  private var buttonBottomConstraint: NSLayoutConstraint?
  private var webViewBottomConstraint: NSLayoutConstraint?
  
  /// These closures are called when the buttonLabel has been pressed
  @Callback<String?>
  public var onTap: Callback<String?>.Store
  
  /// These closures are called when the X-Button has been pressed
  @Callback
  public var onX: Callback<Void>.Store
  
  private func adaptLayoutConstraints() {
    let willShow = buttonLabel.hasContent && isButtonVisible
    let buttonDist = willShow ? -buttonMargin : buttonLabel.frame.height
    let webViewDist = willShow ? -buttonMargin : 0
    buttonBottomConstraint?.isActive = false
    webViewBottomConstraint?.isActive = false
    buttonBottomConstraint = pin(buttonLabel.bottom, to: self.bottom, dist: buttonDist)
    webViewBottomConstraint = pin(webView.bottom, to: buttonLabel.top, dist: webViewDist)
    layoutIfNeeded()
  }  
  
  private func adaptLayout(animated: Bool = false) {
    if animated {
      UIView.animate(seconds: 0.5) { [weak self] in 
        self?.adaptLayoutConstraints()
      }
    } 
    else { adaptLayoutConstraints() }
  }
  
  private func setup() {
    self.backgroundColor = .white
    self.addSubview(webView)
    self.addSubview(buttonLabel)
    self.addSubview(xButton)
    pin(webView.top, to: self.top)
    pin(webView.left, to: self.left)
    pin(webView.right, to: self.right)
    pin(buttonLabel.centerX, to: self.centerX)
    pin(xButton.right, to: self.right, dist: -15)
    pin(xButton.top, to: self.topGuide(), dist: 5)
    if let xButton = xButton as? Button<CircledXView> {
      xButton.pinHeight(35)
      xButton.pinWidth(35)
      xButton.color = .black
      xButton.buttonView.isCircle = true
      xButton.buttonView.circleColor = UIColor.rgb(0xdddddd)
      xButton.buttonView.color = UIColor.rgb(0x707070)
      xButton.buttonView.innerCircleFactor = 0.5
    }
    xButton.isHidden = true
    xButton.onPress { [weak self] _ in
      guard let self = self else { return }
      self.$onX.notify(sender: self)
    }
    $onX.whenActivated { [weak self] isActive in
      self?.xButton.isHidden = !isActive
    }
    webView.scrollDelegate.atEndOfContent { [weak self] isAtEnd in
      guard let self = self else { return }
      guard toggleBottomButton else { return }
      if self.isButtonVisible != isAtEnd {
        self.isButtonVisible = isAtEnd
        self.adaptLayout(animated: true)
      }
    }
    buttonLabel.onTap { [weak self] _ in
      guard let self = self else { return }
      self.$onTap.notify(sender: self, content: self.buttonLabel.text)
    }
  }
  
  public override init(frame: CGRect) {
    self.xButton = Button<CircledXView>()
    self.webView = WebView()
    super.init(frame: frame)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    self.xButton = Button<CircledXView>()
    self.webView = WebView()
    super.init(coder: coder)
    setup()
  }
  
  public init(customXButton:ButtonControl, configuration: WKWebViewConfiguration?) {
    self.xButton = customXButton
    self.webView = WebView(frame: .zero, configuration: configuration)
    super.init(frame: .zero)
    setup()
  }
    
  public override func layoutSubviews() {
    adaptLayoutConstraints()
  }
}
