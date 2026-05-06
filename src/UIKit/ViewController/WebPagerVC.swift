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
  
  // MARK: - Side Tapping
  @Default("edgeTapToNavigate")
  public var edgeTapToNavigate: Bool
  
  @Default("edgeTapToNavigateVisible2")
  public var edgeTapToNavigateVisible2: Bool
  
  fileprivate var onRightTapClosure: (()->(Bool))?
  fileprivate var onLeftTapClosure: (()->(Bool))?
  public lazy var rightTapEnEdgeButton: UIView = { newRightTapEnEdgeButton }()
  public lazy var leftTapEnEdgeButton: UIView = { newLeftTapEnEdgeButton }()
  
  // MARK: - Callback/Closure Storage
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
  
  private var isInteracting = false
  
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
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateTapArea()
  }
  
  // MARK: - Setup
  
  private func setupScrollView() {
    scrollView.isPagingEnabled = true
    scrollView.bounces = true
    scrollView.delegate = self
    scrollView.isDirectionalLockEnabled = true
    scrollView.showsVerticalScrollIndicator = false
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
    if oldSize == view.bounds.size { return }///important to avoid loop
    oldSize = view.bounds.size
    layoutPages(resetOffset: false)
  }
  
  private func layoutPages(resetOffset: Bool = true) {
    guard !isInteracting else { return }   // 🔥 WICHTIG
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
    
    update(container: prevContainer, with: pager.prev)
    update(container: currentContainer, with: pager.current)
    update(container: nextContainer, with: pager.next)
    
    if resetOffset {
      let targetX: CGFloat = (pager.prev != nil) ? w : 0
      scrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: false)
    }
  }
  
  private func update1(container: UIView, with page: OptionalWebView?) {
    guard let view = page?.mainView else {
      container.isHidden = true
      return
    }
    
    container.isHidden = false
    if view.superview !== container {
      DispatchQueue.main.async {
        container.subviews.forEach {
          if let wv = $0 as? WebView { wv.release() }
          $0.removeFromSuperview()
        }
        view.frame = container.bounds
        container.addSubview(view)
      }
    } else {
      view.frame = container.bounds
    }
  }
  
  private func update(container: UIView, with page: OptionalWebView?) {
    guard let view = page?.mainView else {
      container.isHidden = true
      return
    }

    container.isHidden = false

    if view.superview !== container {
      // ❗️NICHT async
      container.subviews.forEach {
        if let wv = $0 as? WebView { wv.release() }
        $0.removeFromSuperview()
      }

      view.frame = container.bounds
      container.addSubview(view)
    } else {
      view.frame = container.bounds
    }
  }
  
  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    guard scrollView == self.scrollView else { return }
    isInteracting = true
  }
  
  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    guard scrollView == self.scrollView else { return }
    isInteracting = false
    commitPaging()

  }
  
  public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    guard scrollView == self.scrollView else { return }
    isInteracting = false
    commitPaging()
    
  }
  
  public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                        withVelocity velocity: CGPoint,
                                        targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    let w = scrollView.bounds.width
    let targetX = targetContentOffset.pointee.x
    let centerX: CGFloat = (pager.prev != nil) ? w : 0
    if targetX > centerX { pendingDirection = .forward }
    else if targetX < centerX { pendingDirection = .backward }
    else { pendingDirection = .none }
  }
  
  private enum PageDirection {  case none, forward, backward  }
  private var pendingDirection: PageDirection = .none
  
  private func commitPaging1() {
    switch pendingDirection {
      case .forward:
        if pager.currentIndex < pager.urls.count - 1 { pager.moveForward() }
      case .backward:
        if pager.currentIndex > 0 { pager.moveBackward() }
      case .none:  break
    }
    pendingDirection = .none
    layoutPages()
  }
  
  private func commitPaging() {
    let oldIndex = pager.currentIndex

    switch pendingDirection {
      case .forward:
        if pager.currentIndex < pager.urls.count - 1 { pager.moveForward() }
      case .backward:
        if pager.currentIndex > 0 { pager.moveBackward() }
      case .none:
        break
    }

    pendingDirection = .none

    // 👉 Nur wenn sich wirklich was geändert hat
    if pager.currentIndex != oldIndex {
      layoutPages()
    }
  }
  
  // MARK: - External Navigation
  public func scrollTo(index: Int, animated: Bool = false) {
    guard index >= 0, index < pager.urls.count else { return }
    let diff = index - pager.currentIndex
    // 👉 Nur EIN Schritt → animieren
    if animated && abs(diff) == 1 {
      pendingDirection = diff > 0 ? .forward : .backward
      let w = scrollView.bounds.width
      let currentX = scrollView.contentOffset.x
      let targetX: CGFloat = diff > 0
      ? currentX + w   // nach rechts → next
      : currentX - w   // nach links → prev
      scrollView.setContentOffset(
        CGPoint(x: targetX, y: 0),
        animated: true
      )
    } else {
      // 👉 Mehr als 1 Schritt → direkt springen
      pager.setup(at: index)
      layoutPages()
    }
  }
}
  
extension WebPagerVC {
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

/// Side Tapping
extension WebPagerVC {
  public func updateTapArea(){
    if edgeTapToNavigate == false
    && UIAccessibility.isVoiceOverRunning == false {
      leftTapEnEdgeButton.isHidden = true
      rightTapEnEdgeButton.isHidden = true
      return
    }
    
    leftTapEnEdgeButton.isHidden = false
    rightTapEnEdgeButton.isHidden = false
    
    leftTapEnEdgeButton.backgroundColor
    = edgeTapToNavigateVisible2
    ? UIColor.gray.withAlphaComponent(0.15)
    : .clear
    leftTapEnEdgeButton.layer.borderColor
    = edgeTapToNavigateVisible2
    ? UIColor.gray.withAlphaComponent(0.25).cgColor
    : UIColor.clear.cgColor
    
    rightTapEnEdgeButton.backgroundColor
    = edgeTapToNavigateVisible2
    ? UIColor.gray.withAlphaComponent(0.15)
    : .clear
    rightTapEnEdgeButton.layer.borderColor
    = edgeTapToNavigateVisible2
    ? UIColor.gray.withAlphaComponent(0.25).cgColor
    : UIColor.clear.cgColor
    
    if leftTapEnEdgeButton.superview == nil {
      self.view.addSubview(leftTapEnEdgeButton)
      pin(leftTapEnEdgeButton, to: self.view, exclude: .right)
    }
    
    if rightTapEnEdgeButton.superview == nil {
      self.view.addSubview(rightTapEnEdgeButton)
      pin(rightTapEnEdgeButton, to: self.view, exclude: .left)
    }
  }
  
  @objc open func handleRightTap() -> Bool{
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
  
  @objc open func handleLeftTap() -> Bool{
    if UIAccessibility.isVoiceOverRunning { return false }
    guard let sv = self.currentWebView?.scrollView,
          sv.contentOffset.y - 2 > 0
    else { return false }
    let y = max(sv.contentOffset.y - sv.frame.size.height + self.addtionalBarHeight + self.textLineHeight, 0)
    sv.setContentOffset(CGPoint(x: 0, y: y), animated: true)
    sv.flashScrollIndicators()
    return true
  }
  
  /// primary right tap handler for right edge tap, is available, add scroll or zoom behaviour if needed
  /// - Parameter closure: closure to call; return true if event handled and index not needed to change
  public func onRightTap(closure: @escaping ()->(Bool)) {
    onRightTapClosure = closure
  }
  /// primary left tap handler for right edge tap, is available, add scroll or zoom behaviour if needed
  /// - Parameter closure: closure to call; return true if event handled and index not needed to change
  public func onLeftTap(closure: @escaping ()->(Bool)) {
    onLeftTapClosure = closure
  }
  
  
  private var tapEnEdgeButtonWidth: CGFloat { 28.0 }
  
  fileprivate var newLeftTapEnEdgeButton: UIView {
    let btn = UIView()
    btn.pinWidth(tapEnEdgeButtonWidth)
    btn.isAccessibilityElement = true
    btn.accessibilityLabel = "zurück"
    btn.accessibilityTraits = .button
    btn.backgroundColor = UIColor.gray.withAlphaComponent(0.15)
    btn.addBorder(.gray.withAlphaComponent(0.25))
    btn.onTapping {[weak self] _ in
      if self?.onLeftTapClosure?() == true { return }
      guard let idx = self?.index, idx > 0 else { return }
      self?.scrollTo(index: idx-1, animated: true)
//      guard UIAccessibility.isVoiceOverRunning else { return }
//      let accesibilityTarget = idx > 1 ? self?.leftTapEnEdgeButton : self?.defaultAccessibilityView ?? self?.rightTapEnEdgeButton
//      ///Read new accessibility label after delay to ensure new content is available @see onDisplay above
//      ///on change to index 0 leftTapEnEdgeButton has no label, so chosse another target to prevent focus loss
//      onMainAfter(0.6){[weak self] in UIAccessibility.post(notification: .layoutChanged, argument: accesibilityTarget)}
    }
    return btn
  }
  
  fileprivate var newRightTapEnEdgeButton: UIView {
    let btn = UIView()
    btn.pinWidth(tapEnEdgeButtonWidth)
    btn.isAccessibilityElement = true
    btn.accessibilityLabel = "weiter"
    btn.accessibilityTraits = .button
    btn.backgroundColor = UIColor.gray.withAlphaComponent(0.15)
    btn.addBorder(.gray.withAlphaComponent(0.25))
    btn.onTapping {[weak self] _ in
      if self?.onRightTapClosure?() == true { return }
      guard let self = self,
            self.index <= self.pager.urls.count - 1 else { return }
      self.scrollTo(index: self.index + 1, animated: true)
//      guard UIAccessibility.isVoiceOverRunning else { return }
//      let isLastAfterScroll = (idx + 1) >= self.collectionView.count - 1
//      let accesibilityTarget
//      = isLastAfterScroll
//      ? (self.defaultAccessibilityView ?? self.leftTapEnEdgeButton)
//      : self.rightTapEnEdgeButton
//      /// Read new accessibility label after delay to ensure new content is available @see onDisplay above
//      /// On change to last index rightTapEnEdgeButton has no label, so choose another target to prevent focus loss
//      onMainAfter(0.6){[weak self] in UIAccessibility.post(notification: .layoutChanged, argument: accesibilityTarget)}
    }
    return btn
  }
  
}
