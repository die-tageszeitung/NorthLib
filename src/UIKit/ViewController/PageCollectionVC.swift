//
//  PageCollectionVC.swift
//
//  Created by Norbert Thies on 10.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit

open class PageCollectionVC: UIViewController {
  /// option to overwrite edge tap enabled for custom subclasses
  open var preventEdgeTapToNavigate: Bool { false }
  
  @Default("edgeTapToNavigate")
  public var edgeTapToNavigate: Bool
  
  @Default("edgeTapToNavigateVisible2")
  public var edgeTapToNavigateVisible2: Bool
  
  /// The collection view displaying OptionalViews
  open var collectionView:PageCollectionView = PageCollectionView()
  
  public var invalidateLayoutNeededOnViewWillAppear:Bool = false
  
  // View which is currently displayed
  public var currentView: OptionalView? {
    if let i = index {
      log("=> PCVC.currentView: \(i)")
      return collectionView.optionalView(at: i)
    }
    else { return nil }
  }
  
  /// Index of current view, change it to scroll to a certain cell
  open var index: Int? {
    get { collectionView.lastIndex }
    set {
      guard let idx = newValue else { return }
      collectionView.setIndex(idx)
    }
  }

  private var topConstraint: NSLayoutConstraint?
  private var bottomConstraint: NSLayoutConstraint?
  
  // Pin top of collectionView
  private func pinTop() {
    topConstraint?.isActive = false
    if pinTopToSafeArea {
      topConstraint = pin(collectionView.top, to: self.view.topGuide())
    }
    else { topConstraint = pin(collectionView.top, to: self.view.top) }
  }
  
  // Pin bottom of collectionView
  private func pinBottom() {
    bottomConstraint?.isActive = false
    if pinBottomToSafeArea {
      bottomConstraint = pin(collectionView.bottom, to: self.view.bottomGuide())
    }
    else { bottomConstraint = pin(collectionView.bottom, to: self.view.bottom) }
  }
  
  /// Pin collection view to top safe area?
  open var pinTopToSafeArea: Bool = true { didSet { pinTop() } }

  /// Pin collection view to bottom safe area?
  open var pinBottomToSafeArea: Bool = false { didSet { pinBottom() } }

  public init() { super.init(nibName: nil, bundle: nil) }
  
  public required init?(coder: NSCoder) { super.init(coder: coder) }

  @discardableResult
  /// Define closure to call when a cell is newly displayed
  public func onDisplay(closure: @escaping (Int, OptionalView?)->()) -> String? {
    return collectionView.onDisplay(closure: closure)
  }
  
  /// removes a closure to call when a cell is newly displayed  from closures by given key
  public func removeOnDisplay(forKey: String) {
    collectionView.removeOnDisplay(forKey: forKey)
  }
  
  /// Defines the closure which delivers the views to display
  open func viewProvider(provider: @escaping (Int, OptionalView?)->OptionalView) {
    collectionView.viewProvider(provider: provider)
  }
 
  //overwriteable
  open func releaseOnDisappear(){}
  
  // MARK: - Life Cycle
  open override func didMove(toParent parent: UIViewController?) {
    super.didMove(toParent: parent)
    if parent == nil { releaseOnDisappear() }
  }
  
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    updateTapArea()
  }
  
  var lastDisplayingIndex: Int? = nil
  var lastSize: CGSize = .zero

  open override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
    let size = collectionView.bounds.size
    guard size != lastSize else { return }
    lastSize = size
    layout.invalidateLayout()
    scheduleResizeCompletion()
  }
  
  override open func loadView() {
    super.loadView()
    self.view.addSubview(collectionView)
    pinTop()
    pinBottom()
    pin(collectionView.left, to: self.view.left)
    pin(collectionView.right, to: self.view.right)
    collectionView.isAccessibilityElement = false
    _ = collectionView.onDisplay {[weak self] idx, _ in
      ///prevent update twice the last index to prevent focus change loose
      guard self?.lastDisplayingIndex != idx else { return }
      self?.lastDisplayingIndex = idx
      onMainAfter(0.3) {[weak self] in
        self?.view.accessibilityElements = self?.accessibilityViews
      }
    }
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    updateTapArea()
    collectionView.parentName = "\(type(of: self))"
  }
  
  private var onRightTapClosure: (()->(Bool))?
  
  /// primary right tap handler for right edge tap, is available, add scroll or zoom behaviour if needed
  /// - Parameter closure: closure to call; return true if event handled and index not needed to change
  public func onRightTap(closure: @escaping ()->(Bool)) {
    onRightTapClosure = closure
  }
  private var onLeftTapClosure: (()->(Bool))?

  /// primary left tap handler for right edge tap, is available, add scroll or zoom behaviour if needed
  /// - Parameter closure: closure to call; return true if event handled and index not needed to change
  public func onLeftTap(closure: @escaping ()->(Bool)) {
    onLeftTapClosure = closure
  }
  
  private let tapEnEdgeButtonWidth: CGFloat = 28.0
  
  public lazy var leftTapEnEdgeButton: UIView = {
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
      self?.collectionView.scrollToIndex(idx-1, animated: true)
      guard UIAccessibility.isVoiceOverRunning else { return }
      let accesibilityTarget = idx > 1 ? self?.leftTapEnEdgeButton : self?.defaultAccessibilityView ?? self?.rightTapEnEdgeButton
      ///Read new accessibility label after delay to ensure new content is available @see onDisplay above
      ///on change to index 0 leftTapEnEdgeButton has no label, so chosse another target to prevent focus loss
      onMainAfter(0.6){[weak self] in UIAccessibility.post(notification: .layoutChanged, argument: accesibilityTarget)}
    }
    return btn
  }()
  public lazy var rightTapEnEdgeButton: UIView = {
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
            let idx = self.index,
            idx <= self.collectionView.count - 1 else { return }
      self.collectionView.scrollToIndex(idx + 1, animated: true)
      guard UIAccessibility.isVoiceOverRunning else { return }
      let isLastAfterScroll = (idx + 1) >= self.collectionView.count - 1
      let accesibilityTarget
      = isLastAfterScroll
      ? (self.defaultAccessibilityView ?? self.leftTapEnEdgeButton)
      : self.rightTapEnEdgeButton
      /// Read new accessibility label after delay to ensure new content is available @see onDisplay above
      /// On change to last index rightTapEnEdgeButton has no label, so choose another target to prevent focus loss
      onMainAfter(0.6){[weak self] in UIAccessibility.post(notification: .layoutChanged, argument: accesibilityTarget)}
    }
    return btn
  }()
  
  public var defaultAccessibilityView:UIView?
    
  public func updateTapArea(){
    if (edgeTapToNavigate == false || preventEdgeTapToNavigate == true)
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
  
  private var resizeWorkItem: DispatchWorkItem?
  private var _lastIndexBeforeResize: Int?
  private var lastIndexBeforeResize: Int? {
    set {
      guard _lastIndexBeforeResize == nil else { return }
      self.log("=> remember _lastIndexBeforeResize: \(_lastIndexBeforeResize)")
      _lastIndexBeforeResize = newValue
    }
    get { _lastIndexBeforeResize }
  }
  
  private func scheduleResizeCompletion() {
    resizeWorkItem?.cancel()
    resizeWorkItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      self.finalizeResize()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: resizeWorkItem!)
  }
  
  private func finalizeResize() {
    guard let idx = lastIndexBeforeResize else { return }
    self.log("=> vc.finalizeResize set index: \(idx) \(type(of: self))")
    self.collectionView
      .scrollToItem(at: IndexPath(item: idx, section: 0),
                    at: .centeredHorizontally,
                    animated: false
      )
    collectionView.resizing = false
    _lastIndexBeforeResize = nil
  }
  
  open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    collectionView.resizing = true
    let li = collectionView.currentIndex
    lastIndexBeforeResize = li
    self.log("=> vc.vwt: \(lastIndexBeforeResize ?? -1) <= \(li)")
    coordinator.animate(alongsideTransition: { [weak self] _ in
      let context = UICollectionViewFlowLayoutInvalidationContext()
      context.invalidateFlowLayoutDelegateMetrics = true
      context.invalidateFlowLayoutAttributes = true
      self?.collectionView.collectionViewLayout.invalidateLayout(with: context)
    }) { [weak self] _ in
      guard let idx = self?.lastIndexBeforeResize else { return }
      self?.log("=> vc.viewWillTransition finalize set index: \(idx)")
      self?.collectionView
        .scrollToItem(at: IndexPath(item: idx, section: 0),
                      at: .left,
                      animated: false
        )
    }
  }
} // PageCollectionVC

extension PageCollectionVC: AccessibilityTargetsProvider {
  @objc open var accessibilityViews: [UIView] {
    var elements: [UIView] = []
    elements.appendIfPresent(defaultAccessibilityView)
    elements.append(leftTapEnEdgeButton)
    elements.append(rightTapEnEdgeButton)
    elements.appendIfPresent(currentView?.activeView)
    /** Alternative to Buttons add the nearby cells
     //    let visibleCells = collectionView.visibleCells
     //    let visibleIndexPaths = visibleCells.compactMap { collectionView.indexPath(for: $0) }
     //    let sortedIndexPaths = visibleIndexPaths.sorted()
     //    for ip in sortedIndexPaths { elements.appendIfPresent(collectionView.cellForItem(at: ip))    }
     */
    return elements
  }
}
