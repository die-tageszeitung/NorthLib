//
//  PageCollectionView.swift
//
//  Created by Norbert Thies on 09.07.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

/**
A PageCollectionView (PCV) is a UICollectionView subclass presenting a number of
views in a horizontally scrollable, page-like layout.

The PCV displays a list of views (called pages) that are laid out side by side.
As of the refactoring in March 2026, each page is sized to fill the entire
bounds of the collection view (full-screen paging).

Previously, the layout supported relative sizing using configurable factors
(e.g. relativePageWidth, relativeSpacing) to create partially visible neighboring
pages. However, this flexible sizing approach was not used in practice and added
unnecessary complexity. During the March 2026 refactoring, this logic was removed
in favor of a simpler, more predictable full-width paging behavior.

By default, the PCV uses a UICollectionViewFlowLayout but you may specify any
FlowLayout subclass using the initializer.

PCV.isPagingEnabled = true is now enabled by default to provide a classic paging
experience (one full page per swipe). The currently visible page is determined
by the cell centered within the collection view after scrolling ends.
*/
open class PageCollectionView: UICollectionView, UICollectionViewDelegate,
  UICollectionViewDataSource, UIScrollViewDelegate, UICollectionViewDelegateFlowLayout {
  
  internal var initialIndex: Int? = nil
  
  var parentName = "unknown"
  
  private var lastKnownSize: CGSize = .zero

  /// scroll from left to right or vice versa
  open var scrollFromLeftToRight: Bool = false {
    didSet { 
      if scrollFromLeftToRight {
        transform = CGAffineTransform(rotationAngle: CGFloat.pi)
      }
      else { transform = .identity }
      reloadData()
    }
  }
  
  fileprivate static var countView = 0  // #PageCollectionViews instantiated
  fileprivate static let reuseCellId = "pageCollectionViewCell"
  
  
  // A closure providing the optional views to display
  public var provider: ((Int, OptionalView?)->OptionalView)? = nil
  
  /// Defines the closure which delivers the views to display
  open func viewProvider(provider: @escaping (Int, OptionalView?)->OptionalView) {
    self.provider = provider
  }
   
  open override func willMove(toWindow newWindow: UIWindow?) {
    if let idx = initialIndex,
       let nw = newWindow {
      //Layout if bounds changed (for full with pagecollection view)
      if nw.bounds.size.width > 0,
         nw.bounds.size.width != frame.size.width { doLayout() }
      ///required also, if frame != zero == layouted once to ensure correct offset in wv
      ///case 1: initialIndex is set correctly especially in imagecollectionview
      ///case 2: correct layout, top margin in webcollectionview
      initialIndex = nil
      scrollToIndex(idx, animated: false)
    }
    super.willMove(toWindow: newWindow)
  }
  
  public var currentIndex: Int {
      let center = CGPoint(
          x: contentOffset.x + bounds.width / 2,
          y: bounds.height / 2
      )
    let idx = indexPathForItem(at: center)?.item ?? 0
    self.log("=> currentIndex: \(idx)")
    return idx
  }
  
  internal func setIndex(_ idx: Int) {
    self.log("=> pagecolview.setIndex: \(idx) skip?:\(resizing)")
    guard resizing == false else { return }
    if window == nil { initialIndex = idx }
    else{ scrollToIndex(idx, animated: false) }
  }
  
  // Scroll to the cell at position index
  open func scrollToIndex(_ idx: Int, animated: Bool = false) {
    guard idx >= 0, idx < count else { return }
    scrollToItem(
      at: IndexPath(item: idx, section: 0),
      at: .left,
      animated: animated
    )
    log("=> cv.scrollToIndex: \(idx)")
    callOnDisplay(idx: idx, oview: optionalView(at: idx))
  }
  
  // Setup the PCV
  private func setup() {
    guard let layout = self.collectionViewLayout as? UICollectionViewFlowLayout
      else { return }
    isPagingEnabled = true
    backgroundColor = UIColor.clear
    contentInsetAdjustmentBehavior = .never
    register(PageCell.self, forCellWithReuseIdentifier: PageCollectionView.reuseCellId)
    layout.scrollDirection = .horizontal
    layout.sectionInset = .zero
    layout.minimumLineSpacing = 0.0
    isAccessibilityElement = false
    ///It seams this has no direct effect
    //isPrefetchingEnabled = true
    showsHorizontalScrollIndicator = false
    showsVerticalScrollIndicator = false
    delegate = self
    dataSource = self
    if scrollFromLeftToRight {
      transform = CGAffineTransform(rotationAngle: CGFloat.pi)
    }
  }
  
  /// Returns the optional view at a given index (if that view is visible)
  open func optionalView(at oidx: Int? = nil) -> OptionalView? {
    let idx = oidx ?? lastIndex ?? 0
    
    if let cell = cellForItem(at: IndexPath(item: idx, section: 0)) as? PageCell {
      if let ziv = cell.page as? ZoomedImageView {
        ziv.doUpdateMinimumZoomScale()
      }
      return cell.page
    }
    return nil
  }
  
  /// Returns the view at a given index (if that view is visible)
  open func view(at idx: Int? = nil) -> UIView? {
    optionalView(at: idx)?.activeView
  }
  
  
  fileprivate var _count: Int = 0
  
  /// Define and change the number of views to display, will reload data
  open var count: Int {
    get { return _count }
    set { 
      _count = newValue
      reloadData()
    }
  }
  
  /// Insert a new page at (in front of) a given index
  open func insert(at idx: Int) {
    _count += 1
    guard self.superview != nil,
          var updatedIndex: Int = lastIndex else { return }

    if idx < updatedIndex { updatedIndex += 1 }
    ///**WARNING** Inserting elements before the current index moves the focus to this item
    ///no matter if flag remembersLastFocusedIndexPath is set
    ///ensure index set correctly
    insertItems(at: [IndexPath(item: idx, section: 0)])
    callOnDisplay(idx: updatedIndex, oview: optionalView(at: updatedIndex))
  }
  
  /// Delete a page at a given index
  open func delete(at idx: Int) {
    _count -= 1
    guard self.superview != nil,
          var updatedIndex: Int = lastIndex else { return }

    if idx < updatedIndex { updatedIndex = max(0, updatedIndex-1) }
    deleteItems(at: [IndexPath(item: idx, section: 0)])
    callOnDisplay(idx: updatedIndex, oview: optionalView(at: updatedIndex))
  }
  
  /// Reload a single view
  open func reload(index: Int) { reloadItems(at: [IndexPath(item: index, section: 0)]) }
  
  // An array of closures, each is to call when the displayed page changes
  fileprivate var onDisplayClosures: [String:(Int, OptionalView?)->()] = [:]
   
  /// Define closure to call when a cell is newly displayed  
  public func onDisplay(closure: @escaping (Int, OptionalView?)->()) -> String? {
    let key = "closure: \(onDisplayClosures.count)"
    onDisplayClosures[key] = closure
    return key
  }
  
  /// removes a closure to call when a cell is newly displayed  from closures by given key
  public func removeOnDisplay(forKey: String) {
    onDisplayClosures[forKey] = nil
  }
  
  public private(set) var lastIndex: Int?
  var resizing = false 
  
  /// Call all onDisplay closures
  fileprivate func callOnDisplay(idx: Int, oview: OptionalView?){
    guard resizing == false,
          lastIndex != idx else { return }
    lastIndex = idx
    ///WARNING CURRENT INDEX IS SOMETIMES WRONG!!
    log("=> cv.callOnDisplay lastIndex: \(idx) currentIndex: \(currentIndex)")
    for cl in onDisplayClosures.values { cl(idx, oview) }
  }
  
  // MARK: *** Lifecycle ***
  public init(frame: CGRect, layout: UICollectionViewFlowLayout =
              PageFlowLayout()) {
    super.init(frame: frame, collectionViewLayout: layout)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  public convenience init() { self.init(frame: CGRect()) }
} // PageCollectionView


// MARK: - UICollectionViewDataSource -
extension PageCollectionView {
  open func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
  
  open func collectionView(_ collectionView: UICollectionView,
                           numberOfItemsInSection section: Int) -> Int { self.count }
  
  open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    if let cell = collectionView
      .dequeueReusableCell(withReuseIdentifier: PageCollectionView.reuseCellId,
                           for: indexPath) as? PageCell {
      let itemIndex = indexPath.item
      debug("+=> cellForItemAt \(itemIndex) requested returning cell \(address(cell)) for parent: \(parentName)")
      cell.update(pcv: self, idx: itemIndex)
      return cell
    }
    return PageCell()
  }
}
  
// MARK: - UICollectionViewDelegateFlowLayout -
extension PageCollectionView {
  public func collectionView(_ collectionView: UICollectionView,
    layout collectionViewLayout: UICollectionViewLayout,
                             sizeForItemAt indexPath: IndexPath) -> CGSize {
    self.bounds.size
  }
}

// MARK: - UIScrollViewDelegate -
extension PageCollectionView {
     
  public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate {
      let idx = currentIndex
      log("=> cv.scrollViewDidEndDragging: \(idx)")
      callOnDisplay(idx: idx, oview: optionalView(at: idx))
    }
  }
  
  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    let idx = currentIndex
    log("=> cv.scrollViewDidEndDecelerating: \(idx)")
    callOnDisplay(idx: idx, oview: optionalView(at: idx))
  }
  
  // When dragging stops, position collection view to a complete page
  public func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                        withVelocity velocity: CGPoint,
                                        targetContentOffset: UnsafeMutablePointer<CGPoint>) {
    let center = CGPoint(x: targetContentOffset.pointee.x, y: bounds.midY)
    guard let idx = indexPathForItem(at: center)?.item else { return }
    log("=> cv.scrollViewWillEndDragging: \(idx)")
    callOnDisplay(idx: idx, oview: optionalView(at: idx))
  }
}

fileprivate extension PageCollectionView {
  
  var cellWidth: CGFloat { bounds.size.width }
  
  // Return scroll offset of given index
  func index2offset(_ idx: Int) -> CGFloat { cellWidth * CGFloat(idx) }
}

/// The collection view cell to present in a page like fashion
fileprivate class PageCell: UICollectionViewCell {
  /// The page to display
  var page: OptionalView?
  /// The view to display
  var pageView: UIView? { return page?.activeView }
  
  // Rotate view if necessary
  private func rotateView(_ view: UIView, doRotate: Bool) {
    if doRotate {
      view.transform = CGAffineTransform(rotationAngle: -CGFloat.pi)
    }
    else { view.transform = .identity }
  }
  
  // Add view to page cell
  private func addView(_ view: UIView, doRotate: Bool) {
    rotateView(view, doRotate: doRotate)
    contentView.subviews.forEach {[weak self] sv in
      if sv != self?.spinner { sv.removeFromSuperview() }
    }
    contentView.addSubview(view)
    pin(view, to: contentView)
    onMainAfter(1.0) {[weak self] in
      self?.spinner.stopAnimating()
      self?.spinner.isHidden = true
    }
  }
  
  /// Request view from provider and put it into a PageCell
  func update(pcv: PageCollectionView, idx: Int) {
    if let provider = pcv.provider {
      let page = provider(idx, self.page)
      self.page = page
      page.whenAvailable { [weak self] in
        if let view = page.mainView {
          self?.addView(view, doRotate: pcv.scrollFromLeftToRight)
        }
      }
      if page.isAvailable {
        if let view = page.mainView {
          addView(view, doRotate: pcv.scrollFromLeftToRight)
        }
      }
      else {
        if let view = page.waitingView {
          addView(view, doRotate: pcv.scrollFromLeftToRight)
        }
      }
    }
  }
  
  private var spinner: UIActivityIndicatorView = UIActivityIndicatorView()
  
  override func prepareForReuse() {
    super.prepareForReuse()
    spinner.startAnimating()
    spinner.isHidden = false
  }
  
  func setup(){
    self.contentView.addSubview(spinner)
    spinner.centerAxis()
    spinner.isHidden = false
    spinner.startAnimating()
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
} // PageCell

public class PageFlowLayout: UICollectionViewFlowLayout {
  public override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
    if let context = context as? UICollectionViewFlowLayoutInvalidationContext {
      context.invalidateFlowLayoutDelegateMetrics = true
      context.invalidateFlowLayoutAttributes = true
    }
    super.invalidateLayout(with: context)
  }
}
