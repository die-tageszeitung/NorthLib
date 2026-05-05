//
//  WebPagerVC.swift
//  NorthLib
//
//  Created by Ringo Müller on 04.05.26.
//

import UIKit

// MARK: - Pager (3 WebViews max)

public final class WebViewPager {
  
  fileprivate(set) var currentIndex: Int = 0 {
    didSet {
      for cl in onDisplayClosures.values { cl(currentIndex, nil) }
    }
  }
  
  // An array of closures, each is to call when the displayed page changes
  fileprivate var onDisplayClosures: [String:(Int, OptionalView?)->()] = [:]
  
  @discardableResult
  /// Define closure to call when a cell is newly displayed
  public func onDisplay(closure: @escaping (Int, OptionalView?)->()) -> String? {
    let key = "closure: \(onDisplayClosures.count)"
    onDisplayClosures[key] = closure
    return key
  }
  
  
  private(set) var prev: OptionalWebView?
  private(set) var current: OptionalWebView?
  private(set) var next: OptionalWebView?
  
  var webviews: [OptionalWebView] {
    [prev, current, next].compactMap { $0 }
  }
  
  /// The bridge (if any) to use for JS interaction
  public var bridge: JSBridgeObject?
  
  public var indicatorStyle:  UIScrollView.IndicatorStyle = .default
  
  //    private let urls: [URL]
  public var urls: [WebViewUrl] = []
  public var baseDir: String?
  fileprivate var initWebView: ((OptionalWebView) -> Void)?
  
  init(urls: [WebViewUrl],
       baseDir: String?) {
    self.urls = urls
    self.baseDir = baseDir
  }
  
  private func make(index: Int) -> OptionalWebView {
    let owv = OptionalWebView(url: urls[index], baseDir: baseDir)
    initWebView?(owv)
    
    if let bridge = self.bridge {
      owv.webView?.addBridge(bridge)
      owv.webView?.scrollView.indicatorStyle = self.indicatorStyle
    }
    return owv
  }
  
  func setup(at index: Int) {
    currentIndex = index
    
    current = make(index: index)
    
    prev = (index > 0) ? make(index: index - 1) : nil
    next = (index < urls.count - 1) ? make(index: index + 1) : nil
  }
  
  func moveForward() {
    guard currentIndex < urls.count - 1 else { return }
    
    prev = current
    current = next
    currentIndex += 1
    
    let newIndex = currentIndex + 1
    next = (newIndex < urls.count) ? make(index: newIndex) : nil
  }
  
  func moveBackward() {
    guard currentIndex > 0 else { return }
    
    next = current
    current = prev
    currentIndex -= 1
    
    let newIndex = currentIndex - 1
    prev = (newIndex >= 0) ? make(index: newIndex) : nil
  }
}

// MARK: - ViewController

open class WebPagerVC: UIViewController, UIScrollViewDelegate {
  
  /// The closures to call when content has been loaded
  @Callback<WebView>
  public var whenLoaded: Callback<WebView>.Store
  
  /// The closures to call when a link has been pressed
  /// The content part of the argument passed to the closures
  /// will be (from: URL?, to: URL?)
  @Callback<(from: URL?, to: URL?)>
  public var whenLinkPressed: Callback<(from: URL?, to: URL?)>.Store
  
  // The closures to call when the webview has been scrolled more than 5%
  @Callback<CGFloat>
  public var whenScrolled: Callback<CGFloat>.Store
  
  // End of content closures
  @Callback<Bool>
  public var atEndOfContent: Callback<Bool>.Store
  
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
  
  open var addtionalBarHeight: CGFloat { return 0.0 }
  open var textLineHeight: CGFloat { return 0.0 }
  
  public let scrollView = UIScrollView()
  
  public var index: Int { pager.currentIndex }
  
  /// The bridge (if any) to use for JS interaction
  public var bridge: JSBridgeObject? {
    get { pager.bridge }
    set { pager.bridge = newValue }
  }
  public var indicatorStyle: UIScrollView.IndicatorStyle{
    pager.indicatorStyle
  }
  
  public var pager: WebViewPager
  private var initialIndex: Int?
  
  public var currentWebView: WebView? { pager.current?.activeView as? WebView }
  
  public var defaultAccessibilityView:UIView?
  
  open override func willMove(toParent parent: UIViewController?) {
    super.willMove(toParent: parent)
    guard let idx = self.initialIndex, parent != nil else { return }
    scrollTo(index: idx)
    self.initialIndex = nil
  }
  
  @discardableResult
  /// Define closure to call when a cell is newly displayed
  public func onDisplay(closure: @escaping (Int, OptionalView?)->()) -> String? {
    return pager.onDisplay(closure: closure)
  }
  
  open func handleRightTap() -> Bool{
    if UIAccessibility.isVoiceOverRunning { return false }
    guard let sv = self.currentWebView?.scrollView,
          sv.contentOffset.y + 2 + sv.frame.size.height < sv.contentSize.height
    else { return false }
    let y = min(sv.contentOffset.y + sv.frame.size.height - self.addtionalBarHeight - self.textLineHeight,
                sv.contentSize.height - sv.frame.size.height + self.addtionalBarHeight)
    sv.setContentOffset(CGPoint(x: 0, y: y), animated: true)
    sv.flashScrollIndicators()
    return true
  }
  
  open func handleLeftTap() -> Bool{
    if UIAccessibility.isVoiceOverRunning { return false }
    guard let sv = self.currentWebView?.scrollView,
          sv.contentOffset.y - 2 > 0
    else { return false }
    let y = max(sv.contentOffset.y - sv.frame.size.height + self.addtionalBarHeight + self.textLineHeight, 0)
    sv.setContentOffset(CGPoint(x: 0, y: y), animated: true)
    sv.flashScrollIndicators()
    return true
  }
  
  open func reloadAllWebViews(){
    let bottomInset = 52 + UIWindow.bottomInset
    pager.webviews.forEach{(val) in
      if let wv = val.webView {
        wv.reload()
        wv.scrollView.indicatorStyle = indicatorStyle
        wv.scrollView.scrollIndicatorInsets
        = UIEdgeInsets(top: 64, left: 0, bottom: bottomInset , right: 0)
      }
    }
  }
  public func gotoUrl(url: URL) {
    var idx = 0
    for u in pager.urls {
      if u.url.nonPublicURL == url.nonPublicURL {
        if self.view.window != nil {
          self.scrollTo(index: idx)
        }
        else {
          initialIndex = idx
        }
        debug("found at index: \(idx)")
        return
      }
      idx += 1
    }
  }
  
  // MARK: - Lifecycle
  public init(urls: [WebViewUrl], baseDir: String?) {
    pager = WebViewPager(urls: urls, baseDir: baseDir)
    super.init(nibName: nil, bundle: nil)
    pager.initWebView = { [weak self] owv in
      self?.initWebView(oView: owv)
    }
  }
  
  required public init?(coder: NSCoder) {
    fatalError()
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    setupContainers()
    setupScrollView()
    pager.setup(at: initialIndex ?? 0)
    layoutPages()
  }
  
  // MARK: - Setup
  
  private func setupScrollView() {
    scrollView.isPagingEnabled = true
    scrollView.bounces = true
    scrollView.delegate = self
    scrollView.isDirectionalLockEnabled = true
    scrollView.showsHorizontalScrollIndicator = false
    view.addSubview(scrollView)
    pin(scrollView.top, to: view.topGuide())
    pin(scrollView.bottom, to: view.bottom)
    pin(scrollView.left, to: view.left)
    pin(scrollView.right, to: view.right)
  }
  
  // MARK: - Layout
  
  var oldSize: CGSize = .zero
  
  private let prevContainer = UIView()
  private let currentContainer = UIView()
  private let nextContainer = UIView()
  
  private func setupContainers() {
    [prevContainer, currentContainer, nextContainer].forEach {
      scrollView.addSubview($0)
    }
  }
  
  open override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if oldSize == view.bounds.size { return }///important to avoid infinite loop
    oldSize = view.bounds.size
    layoutPages(resetOffset: false) // 🔑 wichtig!
  }
  
  private func layoutPages(resetOffset: Bool = true) {
    let w = oldSize.width
    let h = oldSize.height
    guard w > 0 else { return }
    
    var containers: [UIView] = []
    
    if pager.prev != nil {
      containers.append(prevContainer)
    }
    
    containers.append(currentContainer)
    
    if pager.next != nil {
      containers.append(nextContainer)
    }
    
    // Frames setzen
    for (i, container) in containers.enumerated() {
      container.frame = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h)
    }
    
    scrollView.contentSize = CGSize(width: CGFloat(containers.count) * w, height: h)
    
    // 👉 Content sauber zuweisen
    update(container: prevContainer, with: pager.prev)
    update(container: currentContainer, with: pager.current)
    update(container: nextContainer, with: pager.next)
    
    // 👉 Offset nur wenn nötig
    if resetOffset {
      let targetX: CGFloat = (pager.prev != nil) ? w : 0
      scrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: false)
      log("-->layoutPages resetOffset setContentOffset to x: \(targetX) for containers.count: \(containers.count)")
    }
    else {
      log("-->layoutPages no resetOffset for containers.count: \(containers.count)")
    }
  }
  
  private func update(container: UIView, with page: OptionalWebView?) {
    guard let view = page?.mainView else {
      container.isHidden = true
      return
    }
    
    container.isHidden = false
    
    if view.superview !== container {
      container.subviews.forEach { $0.removeFromSuperview() }
      
      view.frame = container.bounds
      container.addSubview(view)
    } else {
      view.frame = container.bounds
    }
  }
  
  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    commitPaging()
  }
  
  public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    commitPaging()
  }
  
  public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                  withVelocity velocity: CGPoint,
                                  targetContentOffset: UnsafeMutablePointer<CGPoint>) {
       let w = scrollView.bounds.width
       let targetX = targetContentOffset.pointee.x
       let centerX: CGFloat = (pager.prev != nil) ? w : 0
       if targetX > centerX {
           pendingDirection = .forward
           log("→ forward center:\(centerX) target:\(targetX)")
       }
       else if targetX < centerX {
           pendingDirection = .backward
           log("→ backward center:\(centerX) target:\(targetX)")
       }
       else {
           pendingDirection = .none
           log("→ none center:\(centerX) target:\(targetX)")
       }
       // 👉 snap zurück zur aktuellen Seite
//       targetContentOffset.pointee.x = centerX
   }
  
  private enum PageDirection {  case none, forward, backward  }
  private var pendingDirection: PageDirection = .none
  
  private func commitPaging() {
    switch pendingDirection {
      case .forward:
        if pager.currentIndex < pager.urls.count - 1 {
          pager.moveForward()
          log("-->commitPaging moved forward to index \(pager.currentIndex)")
        }
        else {
          log("-->commitPaging moved forward skip")
        }
      case .backward:
        if pager.currentIndex > 0 {
          pager.moveBackward()
          log("-->commitPaging moved backward to index \(pager.currentIndex)")
        }
        else {
          log("-->commitPaging moved backward skip")
        }
        
      case .none:
        log("-->commitPaging no move")
        break
    }
    pendingDirection = .none
    layoutPages()
  }
  
  // MARK: - External Navigation
  public func scrollTo(index: Int, animated: Bool = false) {
    guard index >= 0, index < pager.urls.count else { return }
    pager.setup(at: index)
    layoutPages()
    if animated {
      scrollView.setContentOffset(
        CGPoint(x: scrollView.bounds.width, y: 0),
        animated: true
      )
    }
  }
  
  // MARK: - WebView Setup Hook
  private func initWebView(oView: OptionalWebView) {
    let bottomInset = 52 + UIWindow.bottomInset
    oView.webView?.scrollView.scrollIndicatorInsets =
    UIEdgeInsets(top: 58, left: 0, bottom: bottomInset, right: 0)
    
    guard let webView = oView.webView else { return }
    let url = webView.originalUrl?.lastPathComponent ?? "[undefined URL]"
    webView.whenLoadError { [weak self] err in
      self?.error("WebView Load Error on \"\(url)\":\n  \(err.description)")
    }
    webView.whenLinkPressed { [weak self] arg in
      self?.$whenLinkPressed.notify(sender: self, content: arg)
    }
    webView.whenLoaded { [weak self] wv in
      self?.$whenLoaded.notify(sender: self, content: wv)
    }
    webView.scrollDelegate.whenScrolled { [weak self] ratio in
      self?.$whenScrolled.notify(sender: self, content: ratio)
    }
    webView.scrollDelegate.atEndOfContent { [weak self] isAtEnd in
      self?.$atEndOfContent.notify(sender: self, content: isAtEnd)
    }
    webView.scrollDelegate.scrollViewWillBeginDragging { [weak self] ratio in
      self?.$scrollViewWillBeginDragging.notify(sender: self, content: ratio)
    }
    
    webView.scrollDelegate.scrollViewDidEndScrolling { [weak self] offset in
      self?.$scrollViewDidEndScrolling.notify(sender: self, content: offset)
    }
    
    webView.scrollDelegate.scrollViewDidEndDragging { [weak self] ratio in
      self?.$scrollViewDidEndDragging.notify(sender: self, content: ratio)
    }
    
    webView.scrollDelegate.scrollViewDidScroll {  [weak self] ratio in
      self?.$scrollViewDidScroll.notify(sender: self, content: ratio)
    }
  }
}

//extension WebPagerVC {
//  open func handleRightTap() -> Bool{
//    if UIAccessibility.isVoiceOverRunning { return false }
//    guard let sv = self.currentWebView?.scrollView,
//          sv.contentOffset.y + 2 + sv.frame.size.height < sv.contentSize.height
//    else { return false }
//    let y = min(sv.contentOffset.y + sv.frame.size.height - self.addtionalBarHeight - self.textLineHeight,
//                sv.contentSize.height - sv.frame.size.height + self.addtionalBarHeight)
//    sv.setContentOffset(CGPoint(x: 0, y: y), animated: true)
//    sv.flashScrollIndicators()
//    return true
//  }
//
//  open func handleLeftTap() -> Bool{
//    if UIAccessibility.isVoiceOverRunning { return false }
//    guard let sv = self.currentWebView?.scrollView,
//    sv.contentOffset.y - 2 > 0
//    else { return false }
//    let y = max(sv.contentOffset.y - sv.frame.size.height + self.addtionalBarHeight + self.textLineHeight, 0)
//    sv.setContentOffset(CGPoint(x: 0, y: y), animated: true)
//    sv.flashScrollIndicators()
//    return true
//  }
//}



//  public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
//    guard gestureRecognizer === scrollView.panGestureRecognizer else {
//      return true
//    }
//    let velocity = scrollView.panGestureRecognizer.velocity(in: scrollView)
//    // 👉 nur starten wenn horizontal dominiert
//    return abs(velocity.x) > abs(velocity.y)
//  }
//}
