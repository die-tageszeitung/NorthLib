//
//  PdfOverviewCollectionVC.swift
//  NorthLib
//
//  Created by Ringo Müller-Gromes on 14.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

/// Provides tile Overview either of various PDF Files or of various Pages of one PDF File
//may work just with IMages and delegate handles what hapen on tap
public class PdfOverviewCollectionVC : UICollectionViewController, CanRotate{
  // MARK: - Properties used in: UIScrollViewDelegate Extension
  // The closure to call when content scrolled more than scrollRatio
  private var whenScrolledClosure: ((CGFloat)->())?
  private var scrollRatio: CGFloat = 0
  // content y offset at start of dragging
  private var startDragging: CGFloat?
  private let topGradient = VerticalGradientView()
  
  /// Define the menu to display on long touch of a MomentView
  public var cellLabelFont:UIFont? = UIFont.systemFont(ofSize: 11)
  public var cellLabelActiveColor:UIColor = .white
  public var cellLabelInActiveColor:UIColor = .gray
  public var activeIndex = 0
  public var cellLabelLinesCount = 0
  public var titleCell:PdfOverviewCvcCell? { didSet {
    oldValue?.listenLabel.onTapping { _ in }
    oldValue?.listenIcon.onTapping { _ in }
    onTitleCellChangeClosure?(titleCell)
  }}
  private var onTitleCellChangeClosure: ((PdfOverviewCvcCell?) -> ())?
  public func onTitleCellChange(closure: ((PdfOverviewCvcCell?) -> ())?) {
    self.onTitleCellChangeClosure = closure
  }
  
  // MARK: - Properties
  private let reuseIdentifier = "pdfCell"
  
  var pdfModel: PdfModel?
  public var clickCallback: ((CGRect, PdfModel?)->())?
  
  public init(pdfModel: PdfModel) {//Wrong can also be pdfpage
    self.pdfModel = pdfModel
    let layout = TwoColumnUICollectionViewFlowLayout(pdfModel: pdfModel)
    layout.sectionInset = UIEdgeInsets(top: PdfDisplayOptions.Overview.sideSpacing,
                                       left: PdfDisplayOptions.Overview.sideSpacing,
                                       bottom: PdfDisplayOptions.Overview.sideSpacing,
                                       right: PdfDisplayOptions.Overview.sideSpacing)
    /// reduced currently to 0 because label not filled
    /// possible data may come from datamodel, can be: titel, Seite 1 // taz 2, Seite 14 //  die wahrheit; S. 20
    /// Daten sind da, da die PDF diese enthällt
    layout.minimumLineSpacing = PdfDisplayOptions.Overview.rowSpacing
    layout.minimumInteritemSpacing = PdfDisplayOptions.Overview.interItemSpacing - 0.5//fix misscalculation bug
    layout.scrollDirection = .vertical
    super.init(collectionViewLayout: layout)
    collectionView.layoutMargins = .zero
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    collectionView?.showsVerticalScrollIndicator = false
    collectionView?.showsHorizontalScrollIndicator = false
    // Register cell classes
    collectionView?.register(PdfOverviewCvcCell.self, forCellWithReuseIdentifier: reuseIdentifier)
    if let cv = self.collectionView, let cvsv = cv.superview {
      pin(cv.bottom, to: cvsv.bottom)
      pin(cv.top, to: cvsv.top)
      pin(cv.left, to: cvsv.leftGuide())
      pin(cv.right, to: cvsv.rightGuide())
      topGradient.pinHeight(UIWindow.topInset)
      cvsv.addSubview(topGradient)
      /// Insets fix because gradient did not work as expectet
      /// happen on Rotate in PDF e.g. on Notch iPhones either left gap or right, extend size to fix this
      pin(topGradient.left, to: cvsv.leftGuide(), dist: -UIWindow.maxInset)
      pin(topGradient.right, to: cvsv.rightGuide(), dist: UIWindow.maxInset)
      pin(topGradient.top, to: cvsv.top)
    }
  }
  
  // MARK: UICollectionViewDataSource
  public override func numberOfSections(in collectionView: UICollectionView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }
  
  public override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return pdfModel?.count ?? 0
  }
  
  public override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let _cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
    guard let cell = _cell as? PdfOverviewCvcCell,
          let pdfModel = self.pdfModel else { return _cell }
    cell.label.font = self.cellLabelFont
    cell.label.textColor = .white
    
    cell.imageView.image =  pdfModel.thumbnail(atIndex: indexPath.row, finishedClosure: { (img) in
      onMain { cell.imageView.image = img  }
    })
    
    guard let item = pdfModel.item(atIndex: indexPath.row) else {
      return cell
    }
    
    if indexPath.row == 0 { titleCell = cell }
    
    cell.label.textColor
    = indexPath.row == activeIndex
    ? cellLabelActiveColor
    : cellLabelInActiveColor
    
    cell.label.numberOfLines = self.cellLabelLinesCount
    cell.label.text = item.pageTitle
    cell.imageView.contentMode = .scaleToFill
    return cell
  }
  
  public override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let attributes = collectionView.layoutAttributesForItem(at: indexPath)
    var sourceFrame = CGRect.zero
    if let attr = attributes {
      sourceFrame = self.collectionView.convert(attr.frame, to: self.collectionView.superview?.superview)
    }
    pdfModel?.index = indexPath.row
    clickCallback?(sourceFrame, pdfModel)
  }
  
  /// Returns Cell Frame for given Index
  /// - Parameters:
  ///   - index: index of requested Frame
  ///   - fixFullFrame: if cell is out of view this returns a full cell size
  /// - Returns: frame for requested cell at index Path
  ///
  /// **Warning** Only used for Source and Target Frame to animate transition between background
  /// thumbnails and foreground full page - did not define cell's frame e.g. for change cell alignment
  /// ...unfortunately this is more complex
  public func frameAtIndex(index:Int, fixFullFrame:Bool = false) -> CGRect {
    if let attributes = collectionView.layoutAttributesForItem(at: IndexPath(row: index, section: 0)) {
      return self.collectionView.convert(attributes.frame, to: self.collectionView.superview?.superview)
    }
    return .zero
  }
  
  ///do not use releaseOnDisappear here due in slider on close remove is called: self.active.removeSubVC(self.slider)
  public func cleanup() {
    self.pdfModel = nil
    clickCallback = nil
    onTitleCellChangeClosure = nil
    titleCell = nil
  }
}

// MARK: - PdfOverviewCollectionVC
extension PdfOverviewCollectionVC {
  
  /// Define closure to call when web content has been scrolled
  public func whenScrolled( minRatio: CGFloat, _ closure: @escaping (CGFloat)->() ) {
    scrollRatio = minRatio
    whenScrolledClosure = closure
  }
  
  open override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    startDragging = scrollView.contentOffset.y
  }
  
  open override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if let sd = startDragging {
      let scrolled = sd-scrollView.contentOffset.y
      let ratio = scrolled / scrollView.bounds.size.height
      if let closure = whenScrolledClosure, abs(ratio) >= scrollRatio {
        closure(ratio)
      }
    }
    startDragging = nil
  }
}

public class TwoColumnUICollectionViewFlowLayout : UICollectionViewFlowLayout {
  
  //An array to cache the calculated attributes
  fileprivate var cachedAttributes = [UICollectionViewLayoutAttributes]()
  fileprivate var contentSize : CGSize = .zero

  let pdfModel: PdfModel
  let singlePageRatio: CGFloat
  
  public var singleItemSize:CGSize = .zero
  public var panoItemSize:CGSize = .zero
  public var collectionViewWidth:CGFloat = 0
  
  public init(pdfModel: PdfModel) {
    self.pdfModel = pdfModel
    self.singlePageRatio = max(1.2, pdfModel.singlePageSize.height/pdfModel.singlePageSize.width)
    super.init()
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  //The attributes for the item at the indexPath
  public override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    return cachedAttributes.valueAt(indexPath.item)
  }
  
  public override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    var attributesArray = [UICollectionViewLayoutAttributes]()
    for attributes in cachedAttributes {
      if attributes.frame.intersects(rect) {
        attributesArray.append(attributes)
      }
    }
    return attributesArray
  }
  
  public override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
      guard let collectionView = collectionView else { return false }
      return !newBounds.size.equalTo(collectionView.bounds.size)
  }
  
  public override func prepare() {
    super.prepare()///if not called here before/after the UICollectionViewFlowLayoutBreakForInvalidSizes occoures for each cell
    guard let collectionView = collectionView else {return}
    cachedAttributes.removeAll()
    let spacing = self.minimumInteritemSpacing
    let panoItemWidth
      = collectionView.bounds.inset(by: collectionView.layoutMargins).width
      - self.sectionInset.left
      - self.sectionInset.right
    let singleItemWidth =  max(1, panoItemWidth/2 - spacing/2)
    let itemHeight = singleItemWidth * singlePageRatio
    singleItemSize = CGSize(width: singleItemWidth, height: itemHeight)
    panoItemSize = CGSize(width: panoItemWidth, height: itemHeight)
    let rowHeight = itemHeight + self.minimumLineSpacing
    var yOffset = self.sectionInset.top
    let xLeft = self.sectionInset.left + collectionView.layoutMargins.left
    /// UI:  |-sectionInset.left-[cell]-spacing-[cell]-sectionInset.right-|
    let xRight = singleItemWidth + spacing + xLeft
    var prevPageType : PdfPageType?
    for idx in 0..<pdfModel.count {
      let indexPath = IndexPath(item: idx, section: 0)
      let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
      if let item = pdfModel.item(atIndex: idx) {
        switch (prevPageType, item.pageType) {
          case (.left, .right):
            attributes.frame = CGRect(origin: CGPoint(x: xRight, y: yOffset), size: singleItemSize)
          case (_, .double):
            yOffset += rowHeight
            attributes.frame = CGRect(origin: CGPoint(x: xLeft, y: yOffset), size: panoItemSize)
          case (.right, .right):
            yOffset += rowHeight
            attributes.frame = CGRect(origin: CGPoint(x: xRight, y: yOffset), size: singleItemSize)
          case (_, .left):
            fallthrough
          default:
            if prevPageType == nil {//row 0 is left and pano, but no stretch!
              attributes.frame = CGRect(origin: CGPoint(x: xLeft, y: yOffset), size: panoItemSize)
            }
            else {
              yOffset += rowHeight
              attributes.frame = CGRect(origin: CGPoint(x: xLeft, y: yOffset), size: singleItemSize)
            }
            
        }
        prevPageType = item.pageType
      }

      cachedAttributes.append(attributes)
    }
    contentSize = CGSize(width: collectionView.bounds.size.width,
                         height: yOffset + rowHeight)
  }
  
  public override var collectionViewContentSize: CGSize {
    get {
      return contentSize
    }
  }
}
