//
//  WebPagerVC.swift
//  NorthLib
//  VC and View for paging through multiple WebViews, each showing a different local URLs
//  try to get rid of iPad Resize Bugs and Crahes with UICollectionVC
///  maybe use **UIPageViewController** in next itteration or **decouple webview from collection view cell...**
//
//  Created by Ringo Müller on 04.05.26.
//

import UIKit

// MARK: - Pager (3 WebViews max)

public final class WebViewPager: DoesLog {
  
  fileprivate var currentIndex: Int = 0
  
  // An array of closures, each is to call when the displayed page changes
  fileprivate var onDisplayClosures: [String:(Int, OptionalView?)->()] = [:]
  
  @discardableResult
  /// Define closure to call when a cell is newly displayed
  public func onDisplay(closure: @escaping (Int, OptionalView?)->()) -> String? {
    let key = "closure: \(onDisplayClosures.count)"
    onDisplayClosures[key] = closure
    return key
  }
  
  public var currentActive: UIView? { current?.activeView }
  
  private(set) var prev: OptionalWebView?
  private(set) var current: OptionalWebView?
  private(set) var next: OptionalWebView?
  
  var webviews: [OptionalWebView] {
    [prev, current, next].compactMap { $0 }
  }
  
  public func releaseWebviews(){
    webviews.forEach { $0.webView?.release() }
    prev?.webView?.removeFromSuperview()
    current?.webView?.removeFromSuperview()
    next?.webView?.removeFromSuperview()
    prev = nil
    current = nil
    next = nil
  }
  
  public var currentWebviews: [WebView] {
    [prev, current, next].compactMap { $0?.webView }
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
  
  private func rebuildAroundCurrent() {
    guard !urls.isEmpty else {
      prev = nil
      current = nil
      next = nil
      return
    }

    let idx = currentIndex

    replace(&current, with: make(index: idx))
    replace(&prev, with: idx > 0 ? make(index: idx - 1) : nil)
    replace(&next, with: idx < urls.count - 1 ? make(index: idx + 1) : nil)

    notifyDisplay()
  }
  
  public func insert(url: WebViewUrl, at index: Int) {
    let safeIndex = max(0, min(urls.count, index))
    assert(safeIndex == index, "Invalid insert index \(index)")
    if safeIndex != index { log("ERROR: clamped index \(index) -> \(safeIndex)") }
    urls.insert(url, at: safeIndex)
    if safeIndex <= currentIndex {
      currentIndex += 1
    }
    rebuildAroundCurrent()
  }
  
  public func delete(at index: Int) {
    guard index < urls.count else { return }

    urls.remove(at: index)

    if index < currentIndex {
      currentIndex -= 1
    } else if index == currentIndex {
      currentIndex = min(currentIndex, urls.count - 1)
    }
    rebuildAroundCurrent()
  }
  
  private func make(index: Int) -> OptionalWebView? {
    guard let url = urls.valueAt(index) else { return nil }
    
    let owv = OptionalWebView(url: url, baseDir: baseDir)
    initWebView?(owv)
    
    if let bridge = self.bridge {
      owv.webView?.addBridge(bridge)
      owv.webView?.scrollView.indicatorStyle = self.indicatorStyle
      owv.webView?.scrollView.contentInsetAdjustmentBehavior = .never
    }
    return owv
  }
  
  private func notifyDisplay() {
    for cl in onDisplayClosures.values { cl(currentIndex, current) }
  }
  
  private func replace(_ target: inout OptionalWebView?, with newValue: OptionalWebView?) {
    if target !== newValue {
      target?.release()
    }
    target = newValue
  }
  
  func setup(at index: Int) {
    currentIndex = index
    
    replace(&current, with: make(index: index))
    notifyDisplay()
    replace(&prev, with: index > 0 ? make(index: index - 1) : nil)
    replace(&next, with: index < urls.count - 1 ? make(index: index + 1) : nil)
  }
  
  func moveForward() {
    guard currentIndex < urls.count - 1 else { return }
    let oldPrev = prev
    prev = current
    current = next ?? make(index: currentIndex + 1)
    currentIndex += 1
    let newIndex = currentIndex + 1
    next = (newIndex < urls.count) ? make(index: newIndex) : nil
    oldPrev?.release()
    notifyDisplay()
  }
  
  func moveBackward() {
    guard currentIndex > 0 else { return }
    
    let oldNext = next
    next = current
    current = prev ?? make(index: currentIndex - 1)
    currentIndex -= 1
    let newIndex = currentIndex - 1
    prev = (newIndex >= 0) ? make(index: newIndex) : nil
    oldNext?.release()
    notifyDisplay()
  }
}

// MARK: - ViewController

open class WebPagerVC: UIViewController, UIScrollViewDelegate {
  
  // MARK: - Side Tapping
  @Default("edgeTapToNavigate")
  public var edgeTapToNavigate: Bool
  
  @Default("edgeTapToNavigateVisible2")
  public var edgeTapToNavigateVisible2: Bool
  
  public lazy var rightTapEnEdgeButton: UIView = { newRightTapEnEdgeButton }()
  public lazy var leftTapEnEdgeButton: UIView = { newLeftTapEnEdgeButton }()
  
  // MARK: - Callback/Closure Storage
  /// The closures to call when content has been loaded
  #warning("may fires more often than in WebCollectionVC")
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
  public var count: Int { pager.urls.count }
  
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
  
  /// removes a closure to call when a cell is newly displayed  from closures by given key
  public func removeOnDisplay(forKey: String) {
    return pager.onDisplayClosures[forKey] = nil
  }
  
  open func reloadAllWebViews(){
    pager.webviews.forEach{ $0.webView?.reload() }
  }
  
  public func gotoIndex(index: Int) {
    if self.view.window != nil {
      self.scrollTo(index: index)
    }
    else {
      initialIndex = index
    }
  }
  
  public func gotoUrl(path: String, file: String) {
    gotoUrl(path + "/" + file)
  }
  
  public func gotoUrl(_ url: String) {
    let url = URL(fileURLWithPath: url)
    gotoUrl(url: url)
  }
  
  public func gotoUrl(url: URL) {
    var idx = 0
    for u in pager.urls {
      if u.url.nonPublicURL == url.nonPublicURL {
        gotoIndex(index: idx)
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
  
  private var appearClosure: (()->())?
  
  /// Define closure to call when the view has appeared (and thus content is visible)
  /// compared to prev Implementation with WebCollectionVC whenLoaded my fires multiple times more!
  public func onAppear(closure: @escaping ()->()) {
    appearClosure = closure
  }
  
  open override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    appearClosure?()
  }
  
  //overwriteable
  open func releaseOnDisappear(){
    appearClosure = nil
  }
  
  // MARK: - Life Cycle
  open override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    if parent == nil { releaseOnDisappear() }
  }
  
  // MARK: - Setup
  
  private func setupScrollView() {
    scrollView.isPagingEnabled = true
    scrollView.bounces = true
    scrollView.delegate = self
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.isDirectionalLockEnabled = true
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false
    view.addSubview(scrollView)
    pin(scrollView.top, to: view.topGuide())//top for Screen, TopGuide for SystemBar Bottom (+ ca 30)
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

    let newSize = scrollView.bounds.size
    guard oldSize != newSize else { return }

    let oldWidth = oldSize.width
    oldSize = newSize

    let relativeOffset: CGFloat

    if oldWidth > 0 {
      relativeOffset = scrollView.contentOffset.x / oldWidth
    } else {
      relativeOffset = pager.prev != nil ? 1 : 0
    }

    layoutPages(resetOffset: false)

    let newOffsetX = relativeOffset * newSize.width

    scrollView.setContentOffset(
      CGPoint(x: round(newOffsetX), y: 0),
      animated: false
    )
  }
  
  private func layoutPages(resetOffset: Bool = true) {
    guard !isInteracting else { return } ///important!
    let w = oldSize.width
    let h = oldSize.height
    
    guard w > 0 else { return }
    var containers: [UIView] = []
    
    if pager.prev != nil { containers.append(prevContainer)  }
    containers.append(currentContainer)
    if pager.next != nil { containers.append(nextContainer)  }
    
    // set frames for containers
    for (i, container) in containers.enumerated() {
      container.frame = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h)
    }
    
    scrollView.contentSize
    = CGSize(width: CGFloat(containers.count) * w, height: h)
    scrollView.contentInset = .zero
    
    update(container: prevContainer, with: pager.prev)
    update(container: currentContainer, with: pager.current)
    update(container: nextContainer, with: pager.next)
    
    if resetOffset {
      let targetX: CGFloat = (pager.prev != nil) ? w : 0
      scrollView.setContentOffset(CGPoint(x: targetX, y: 0), animated: false)
    }
    onMainAfter() {[weak self] in
      self?.view.accessibilityElements = self?.accessibilityViews
    }
  }
  
  private var containerTokens: [ObjectIdentifier:Int] = [:]
  private var tokenCounter: Int = 0
  
  private func add(view: UIView, to container: UIView) {
    guard view.superview !== container else {
      view.frame = container.bounds
      return
    }
    container.subviews.forEach { $0.removeFromSuperview() }
    view.removeFromSuperview()
    view.frame = container.bounds
    container.addSubview(view)
  }
  
  private func update(container: UIView, with page: OptionalWebView?) {
    guard let page else {
      container.subviews.forEach {
        $0.removeFromSuperview()
      }
      return
    }
    
    tokenCounter += 1
    let token = tokenCounter
    containerTokens[ObjectIdentifier(container)] = token
    func isStillValid() -> Bool {
      containerTokens[ObjectIdentifier(container)] == token
    }
    if page.isAvailable == true, let view = page.mainView {
      add(view: view, to: container)
    }
    else if let waiting = page.waitingView {
      add(view: waiting, to: container)
      page.whenAvailable { [weak self, weak container, weak page] in
        guard let self, let container, let page, isStillValid(), page.isAvailable, let wv = page.mainView
        else { return }
        self.add(view: wv, to: container)
      }
    }
    else {
      container.subviews.forEach {
        if let wv = $0 as? WebView { wv.release() }
        $0.removeFromSuperview()
      }
    }
  }
  
  private func updateOld(container: UIView, with page: OptionalWebView?) {
    page?.whenAvailable { [weak self] in
      if let wv = page?.mainView { self?.add(view: wv, to: container) }
    }
    
    if page?.isAvailable == true, let view = page?.mainView {
      add(view: view, to: container)
    }
    else if let view = page?.waitingView {
      add(view: view, to: container)
    }
    else {
      //try to ensure wrong view is shown seams not to work
      add(view: UIView(), to: container)
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

    // only layout pages after change
    if pager.currentIndex != oldIndex {
      layoutPages()
    }
  }
  
  // MARK: - External Navigation
  public func scrollTo(index: Int, animated: Bool = false) {
    guard index >= 0, index < pager.urls.count else { return }
    let diff = index - pager.currentIndex
    /// only scroll animate for 1 ondex jumps
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
      // multiple jumps => no animation, direct setup
      pager.setup(at: index)
      layoutPages()
    }
  }
}
  
extension WebPagerVC {
  
  // MARK: - WebView Setup Hook
  private func initWebView(oView: OptionalWebView) {
    guard let webView = oView.webView else { return }
    
    webView.scrollView .contentInsetAdjustmentBehavior = .never
    
    let bottomInset = 52 + UIWindow.bottomInset
    webView.scrollView.scrollIndicatorInsets
    = UIEdgeInsets(top: 58, left: 0, bottom: bottomInset, right: 0)

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

extension WebPagerVC {
  public func insert(wwurl: WebViewUrl, at index: Int) {
    pager.insert(url: wwurl, at: index)
    layoutPages()
  }
  public func delete(at index: Int) {
    pager.delete(at: index)
    layoutPages()
  }
  
  public func updatePagesAfterInsertOrDelete() {
    guard count > 0 else { return }
    let idx = index < count ? index : 0
    pager.setup(at: idx)
    layoutPages()
  }
}

extension WebPagerVC: AccessibilityTargetsProvider {
  @objc open var accessibilityViews: [UIView] {
    var elements: [UIView] = []
    elements.appendIfPresent(defaultAccessibilityView)
    elements.append(leftTapEnEdgeButton)
    elements.append(rightTapEnEdgeButton)
    elements.appendIfPresent(pager.current?.activeView)
    /** Alternative to Buttons add the nearby cells
     //    let visibleCells = collectionView.visibleCells
     //    let visibleIndexPaths = visibleCells.compactMap { collectionView.indexPath(for: $0) }
     //    let sortedIndexPaths = visibleIndexPaths.sorted()
     //    for ip in sortedIndexPaths { elements.appendIfPresent(collectionView.cellForItem(at: ip))    }
     */
    return elements
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
    /// **RECALC Required?**  maybe after rotation/resize addtionalBarHeight is not updated?
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
      if self?.handleLeftTap() == true { return }
      guard let idx = self?.index, idx > 0 else { return }
      self?.scrollTo(index: idx-1, animated: true)
      guard UIAccessibility.isVoiceOverRunning else { return }
      let accesibilityTarget = idx > 1 ? self?.leftTapEnEdgeButton : self?.defaultAccessibilityView ?? self?.rightTapEnEdgeButton
      ///Read new accessibility label after delay to ensure new content is available @see onDisplay above
      ///on change to index 0 leftTapEnEdgeButton has no label, so chosse another target to prevent focus loss
      onMainAfter(0.6){
        UIAccessibility.post(notification: .layoutChanged, argument: accesibilityTarget)
      }
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
      if self?.handleRightTap() == true { return }
      guard let self = self,
            self.index <= self.pager.urls.count - 1 else { return }
      self.scrollTo(index: self.index + 1, animated: true)
      guard UIAccessibility.isVoiceOverRunning else { return }
      let isLastAfterScroll = (index + 1) >= self.count - 1
      let accesibilityTarget
      = isLastAfterScroll
      ? (self.defaultAccessibilityView ?? self.leftTapEnEdgeButton)
      : self.rightTapEnEdgeButton
      /// Read new accessibility label after delay to ensure new content is available @see onDisplay above
      /// On change to last index rightTapEnEdgeButton has no label, so choose another target to prevent focus loss
      onMainAfter(0.6){
        UIAccessibility.post(notification: .layoutChanged, argument: accesibilityTarget)
      }
    }
    return btn
  }
}
