//
//  PageCollectionVC.swift
//
//  Created by Norbert Thies on 10.09.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit

fileprivate var countVC = 0


open class PageCollectionVC: UIViewController {
  /// option to overwrite edge tap enabled for custom subclasses
  open var preventEdgeTapToNavigate: Bool { false }
  
  @Default("edgeTapToNavigate")
  public var edgeTapToNavigate: Bool
  
  @Default("edgeTapToNavigateVisible2")
  public var edgeTapToNavigateVisible2: Bool
  
  /// The collection view displaying OptionalViews
  open var collectionView:PageCollectionView? = PageCollectionView()
  
  /// The Layout object determining the size of the cells
  open var cvLayout: UICollectionViewFlowLayout!

  /// A closure providing the optional views to display
  open var provider: ((Int, OptionalView?)->OptionalView)? = nil
  
  /// inset from top/bottom/left/right as factor to min(width,height)
  open var inset = 0.025
    
  public var invalidateLayoutNeededOnViewWillAppear:Bool = false
  
  // The raw cell size (without bounds)
  private var rawCellsize: CGSize { return self.collectionView?.bounds.size ?? CGSize.zero }
  
  // The default margin of cells (ie. left/right/top/bottom insets)
  private var margin: CGFloat {
    let s = rawCellsize
    return min(s.height, s.width) * CGFloat(inset)
  }
  
  // The size of a cell is defined by the collection views bounds minus margins
  private var cellsize: CGSize {
    let s = rawCellsize
    return CGSize(width: s.width - 2*margin, height: s.height - 2*margin)
  }
  
  // View which is currently displayed
  public var currentView: OptionalView? { 
    if let i = index { return collectionView?.optionalView(at: i) }
    else { return nil }
  }
  
  /// Index of current view, change it to scroll to a certain cell
  open var index: Int? {
    get { return collectionView?.index }
    set {
      if collectionView?.index == nil {
        ///initially call layout if not done jet to ensure scroll to index works
        collectionView?.doLayout()
      }
      collectionView?.index = newValue
    }
  }

  /// Define and change the number of views to display, will reload data
  open var count: Int {
    get { return collectionView?.count ?? 0 }
    set { collectionView?.count = newValue }
  }
  
  private var topConstraint: NSLayoutConstraint?
  private var bottomConstraint: NSLayoutConstraint?
  
  // Pin top of collectionView
  private func pinTop() {
    topConstraint?.isActive = false
    guard let collectionView = collectionView else { return }
    if pinTopToSafeArea {
      topConstraint = pin(collectionView.top, to: self.view.topGuide())
    }
    else { topConstraint = pin(collectionView.top, to: self.view.top) }
  }
  
  // Pin bottom of collectionView
  private func pinBottom() {
    bottomConstraint?.isActive = false
    guard let collectionView = collectionView else { return }
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
  public func onDisplay(closure: @escaping (Int, OptionalView?, Bool)->()) -> String? {
    return collectionView?.onDisplay(closure: closure)
  }
  
  /// removes a closure to call when a cell is newly displayed  from closures by given key
  public func removeOnDisplay(forKey: String) {
    collectionView?.removeOnDisplay(forKey: forKey)
  }
  
  /// Define closure to call when a cell is newly displayed
  public func onEndDisplayCell(closure: @escaping (Int, OptionalView?)->()) {
    collectionView?.onEndDisplayCell(closure: closure)
  }
    
  /// Defines the closure which delivers the views to display
  open func viewProvider(provider: @escaping (Int, OptionalView?)->OptionalView) {
    collectionView?.viewProvider(provider: provider)
  }
 
  // MARK: - Life Cycle
  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    collectionView?.preventInit = false
    updateTapArea()
  }

  override open func loadView() {
    super.loadView()
    collectionView?.preventInit = true
    collectionView?.isPagingEnabled = true
    collectionView?.relativePageWidth = 1
    collectionView?.relativeSpacing = 0
    collectionView?.backgroundColor = UIColor.white
    guard let collectionView = collectionView else { return }
    self.view.addSubview(collectionView)
    pinTop()
    pinBottom()
    pin(collectionView.left, to: self.view.left)
    pin(collectionView.right, to: self.view.right)
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    if count != 0 { collectionView?.reloadData() }
    updateTapArea()
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
    btn.backgroundColor = UIColor.gray.withAlphaComponent(0.15)
    btn.addBorder(.gray.withAlphaComponent(0.25))
    btn.onTapping {[weak self] _ in
      if self?.onLeftTapClosure?() == true { return }
      guard let idx = self?.index, idx > 0 else { return }
      self?.collectionView?.scrollto(idx-1, animated: true)
      guard UIAccessibility.isVoiceOverRunning else { return }
      self?.leftTapEnEdgeButton.accessibilityLabel = nil
      onMainAfter {[weak self] in UIAccessibility.post(notification: .layoutChanged, argument: self?.leftTapEnEdgeButton)}
    }
    return btn
  }()
  public lazy var rightTapEnEdgeButton: UIView = {
    let btn = UIView()
    btn.pinWidth(tapEnEdgeButtonWidth)
    btn.isAccessibilityElement = true
    btn.accessibilityLabel = "weiter"
    btn.backgroundColor = UIColor.gray.withAlphaComponent(0.15)
    btn.addBorder(.gray.withAlphaComponent(0.25))
    btn.onTapping {[weak self] _ in
      if self?.onRightTapClosure?() == true { return }
      guard let idx = self?.index else { return }
      self?.collectionView?.scrollto(idx+1, animated: true)
      guard UIAccessibility.isVoiceOverRunning else { return }
      self?.rightTapEnEdgeButton.accessibilityLabel = nil
      onMainAfter {[weak self] in UIAccessibility.post(notification: .layoutChanged, argument: self?.rightTapEnEdgeButton)}
    }
    return btn
  }()
    
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
  
  // TODO: transition/rotation better with collectionViewLayout subclass as described in:
  // https://www.matrixprojects.net/p/uicollectionviewcell-dynamic-width/
  open override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
    super.willTransition(to: newCollection, with: coordinator)
    coordinator.animate(alongsideTransition: nil) { [weak self] ctx in
      self?.collectionView?.collectionViewLayout.invalidateLayout()
    }
  }
  
  open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    collectionView?.preventScrollIndexUpdate = true
    super.viewWillTransition(to: size, with: coordinator)
    coordinator.animateAlongsideTransition(in: nil) {[weak self] _ in
      self?.collectionView?.isHidden = true
    } completion: {[weak self] _ in
      self?.collectionView?.collectionViewLayout.invalidateLayout()
      self?.collectionView?.fixScrollPosition()
      //PDF>Rotate: fix layout pos
      if let ziv = self?.currentView as? ZoomedImageViewSpec {
        ziv.invalidateLayout()
      }
      self?.collectionView?.showAnimated(duration: 0.1)
      self?.collectionView?.preventScrollIndexUpdate = false
    }
  }
} // PageCollectionVC
