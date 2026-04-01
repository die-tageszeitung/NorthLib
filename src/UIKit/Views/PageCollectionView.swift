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
  
  fileprivate var initialIndex: Int? = nil
  var isResizing = false
  var resizingTargetIndex: Int?
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
  private static let reuseCellId = "pageCollectionViewCell"
  
  
  // A closure providing the optional views to display
  public var provider: ((Int, OptionalView?)->OptionalView)? = nil
  
  /// Defines the closure which delivers the views to display
  open func viewProvider(provider: @escaping (Int, OptionalView?)->OptionalView) {
    self.provider = provider
  }
  
  // Scroll to the cell at position index
  open func scrollto(_ idx: Int, animated: Bool = false) {
    if isResizing { return } // 🔥 FIX
    
    guard idx < self.count,
          idx != centerIndex else { return }
    
    scrollToItem(at: IndexPath(item: idx, section: 0),
                 at: .left,
                 animated: animated)
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
//    let idx: Int? = oidx ?? _index
    if let idx = oidx ?? index,
       let cell = cellForItem(at: IndexPath(item: idx, section: 0)) as? PageCell {
      if let ziv = cell.page as? ZoomedImageView {
        ziv.doUpdateMinimumZoomScale()
      }
      return cell.page
    }
    else { return nil }
  }
  
  /// Returns the view at a given index (if that view is visible)
  open func view(at idx: Int? = nil) -> UIView? {
    optionalView(at: idx)?.activeView
  }
  
  public func fixScrollPosition(toIndex: Int? = nil) {
    guard count > 0 else { return }
    let targetIndex = toIndex ?? index ?? derivedIndex
    let safeIndex = max(0, min(targetIndex, count - 1))
    
    layoutIfNeeded()
    
    scrollToItem(at: IndexPath(item: safeIndex, section: 0),
                 at: .left,
                 animated: false)
    
    index = safeIndex
    log(">>>> fixScrollPosition toIndex: \(toIndex ?? -1), targetIndex: \(targetIndex), safeIndex: \(safeIndex)")
  }
  
  fileprivate var derivedIndex: Int {
    if isResizing { return index ?? 0 } // 🔥 FIX
    guard bounds.width > 0 else { return 0 }
    let idx = Int(round(contentOffset.x / bounds.width))
    return max(0, min(idx, count - 1))
  }
 
  /// Index of current page, change it to scroll to a certain cell
  open var index: Int? {
    didSet {
      if isResizing { return } // 🔥🔥🔥 WICHTIG
      guard oldValue != index else { return }
      log(">>>> set new index: \(index ?? -1)")
      
      if let idx = index {
        callOnDisplay(idx: idx, oview: optionalView(at: idx))
      }
      
      guard let idx = index,
            idx != centerIndex else { return }
      
      scrollto(idx)
    }
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
  open func insert(at idx: Int) {/*TBD*/  }
  
  /// Delete a page at a given index
  open func delete(at idx: Int) {/*TBD*/  }
  
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
  
  // closure to execute on end display
  fileprivate var onEndDisplayClosures: [(Int, OptionalView?)->()] = []
  
  /// Define closure to call when a cell is not displayed
  public func onEndDisplayCell(closure: @escaping (Int, OptionalView?)->()) {
    onEndDisplayClosures += closure
  }

  /// Call all onDisplay closures
  fileprivate func callOnDisplay(idx: Int, oview: OptionalView?)
  { for cl in onDisplayClosures.values { cl(idx, oview) } }
  
  // MARK: *** Lifecycle ***
  

  
  open override func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    if superview != nil, let idx = index, centerIndex != idx {
      ///set initial index, if needed
      scrollto(idx, animated: false)
    }
  }
  
  public init(frame: CGRect, layout: UICollectionViewFlowLayout =
    UICollectionViewFlowLayout()) {
    super.init(frame: frame, collectionViewLayout: layout)
    setup()
  }
  
  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  public convenience init() { self.init(frame: CGRect()) }
} // PageCollectionView


// MARK: - UICollectionViewDelegate -
extension PageCollectionView {
  public func collectionView(_ collectionView: UICollectionView,
                             didEndDisplaying cell: UICollectionViewCell,
                             forItemAt indexPath: IndexPath) {
    guard let pageCell = cell as? PageCell else {
      return
    }
    for cl in onEndDisplayClosures {
      cl(indexPath.row, pageCell.page)
    }
  }

}
// MARK: - UICollectionViewDataSource -
extension PageCollectionView {
  open func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
  
  open func collectionView(_ collectionView: UICollectionView,
                           numberOfItemsInSection section: Int) -> Int { self.count }
  
  open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    if let cell = collectionView.dequeueReusableCell(withReuseIdentifier:
      PageCollectionView.reuseCellId, for: indexPath) as? PageCell {
      let itemIndex = indexPath.item
      debug("index \(itemIndex) requested in cell \(address(cell))")
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
  
  fileprivate var centerIndex: Int? {
    guard bounds.width > 0 else { return nil }
    let idx = Int(round(contentOffset.x / bounds.width))
    return max(0, min(idx, count - 1))
  }
   
  fileprivate var centerIndex2: Int? {
    let center = CGPoint(x: bounds.midX + contentOffset.x, y: bounds.midY)
    return indexPathForItem(at: center)?.row
  }
  
  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    if isResizing { return } // 🔥 FIX
//    if !isDragging && !isDecelerating { return }
    let idx = centerIndex
    self.log(">>>> scrollViewDidEndDecelerating setIndex: \(idx ?? -2)")
    index = idx
  }
  
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    guard bounds.width > 0 else { return }
    
    // während Resize keinen Index updaten
    if isResizing { return }
  }
}

fileprivate extension PageCollectionView {
  
  var cellWidth: CGFloat { bounds.size.width }
  
  // Return index at a given scroll offset
  func offset2index(_ offset: CGFloat) -> Int {
    let i = offset / cellWidth
    return Int(round(i))
  }
  
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
    contentView.subviews.forEach { $0.removeFromSuperview() }
    contentView.addSubview(view)
    pin(view, to: contentView)
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
  
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
} // PageCell
