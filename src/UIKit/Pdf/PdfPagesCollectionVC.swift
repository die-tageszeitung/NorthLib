//
//  PdfPagesCollectionVC.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 14.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

//PagePDFVC array von pages mit Image und page
/// Provides functionallity to view, zoom in PDF Pages. Swipe on Side Corner shows next/prev Page if available
open class PdfPagesCollectionVC : ImageCollectionVC, CanRotate{
  open override var preventEdgeTapToNavigate: Bool { false }
  public var cellScrollIndicatorInsets:UIEdgeInsets?
  public var cellVerticalScrollIndicatorInsets:UIEdgeInsets?
  public var cellHorizontalScrollIndicatorInsets:UIEdgeInsets?
  public var useTopGradient = true
  var whenScrolledHandler : WhenScrolledHandler?
  let topGradient = VerticalGradientView()
  public func whenScrolled(minRatio: CGFloat, _ closure: @escaping (CGFloat) -> ()) {
    whenScrolledHandler = (minRatio, closure)
  }
  
  public var menuItems: [(title: String, icon: String, closure: (Any?)->())] = []
    
  public var pdfModel : PdfModel? {
    didSet{
      updateData()
    }
  }
  
  
  func updateData(){
    guard let model = pdfModel else { return }
    self.index = model.index
    super.count = model.count
    self.collectionView?.reloadData()
  }
  
  public init(data:PdfModel, useTopGradient: Bool) {
    self.pdfModel = data
    self.useTopGradient = useTopGradient
    super.init()
    updateData()
  }
  
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    self.iosLower14?.pageControlMaxDotsCount = Device.singleton == .iPad ? 25 : 9
    self.iosHigher14?.pageControlMaxDotsCount = self.pdfModel?.count ?? 0
    self.pageControl?.layer.shadowColor = UIColor.lightGray.cgColor
    self.pageControl?.layer.shadowRadius = 3.0
    self.pageControl?.layer.shadowOffset = CGSize(width: 0, height: 0)
    self.pageControl?.layer.shadowOpacity = 1.0
    self.pageControl?.pageIndicatorTintColor = UIColor.white
    self.pageControl?.currentPageIndicatorTintColor = UIColor.red//Const.SetColor.CIColor.color
    self.pinBottomToSafeArea = false
    setupTopGradient()
    self.view.backgroundColor = .black ///fix bg color on rotate was white even of .clear set
  }
  
  func setupTopGradient() {
    guard useTopGradient else { return }
    topGradient.pinHeight(UIWindow.topInset)
    self.view.addSubview(topGradient)
    pin(topGradient.left, to: self.view.left)
    pin(topGradient.right, to: self.view.right)
    pin(topGradient.top, to: self.view.top)
  }

  open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    handleTraitsChange(size)
  }

  open override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    //PDF>Article>Rotate>PDF: fix layout pos
    if let ziv = self.currentView as? ZoomedImageViewSpec {
      onMainAfter(0.3) {
        ziv.invalidateLayout()
      }
    }
    handleTraitsChange(self.view.frame.size)
  }

  func handleTraitsChange(_ toSize:CGSize) {
    //on iPhone in Landscape, there is no status Bar
    topGradient.isHidden = UIDevice.current.orientation.isLandscape && Device.isIphone
  }
  
  public override func didReceiveMemoryWarning() {
    print("☠️☠️☠️\nRECEIVE MEMORY WARNING\n☠️☠️☠️☠️\nPdfPagesCollectionVC->didReceiveMemoryWarning\n   ")
  }

  open override func setupViewProvider(){
    viewProvider { [weak self] (index, oview) in
      guard let self = self else { return UIView() }
      let dataItem = self.pdfModel?.item(atIndex: index)
      if let ziv = oview as? ZoomedImageView {
        if ziv.optionalImage as? ZoomedPdfImage == dataItem as? ZoomedPdfImage {
          return ziv
        }
        
        if ziv.optionalImage != nil {
          ziv.optionalImage?.image = nil
          ziv.optionalImage = nil
        }
        
        ziv.optionalImage = dataItem
        dataItem?.renderFullscreenImageIfNeeded { [weak self] success in
          self?.handleRenderFinished(success, ziv)
        }
        return ziv
      }
      else {
        let ziv = ZoomedImageView(optionalImage: dataItem)
        ziv.useExtendedLayoutAdjustments = true
        ziv.scrollView.insetsLayoutMarginsFromSafeArea = true
        ziv.scrollView.contentInsetAdjustmentBehavior = .scrollableAxes
        ziv.whenScrolledHandler = self.whenScrolledHandler
        if let insets = self.cellScrollIndicatorInsets{
          ziv.scrollView.scrollIndicatorInsets = insets
        }
        if let insets = self.cellVerticalScrollIndicatorInsets{
          ziv.scrollView.verticalScrollIndicatorInsets = insets
        }
        if let insets = self.cellHorizontalScrollIndicatorInsets{
          ziv.scrollView.horizontalScrollIndicatorInsets = insets
        }
        ziv.backgroundColor = .clear
        ziv.scrollView.backgroundColor = .clear //.red/black work .clear not WTF
        ziv.onTap { [weak self] (oimg, x, y) in
          guard let self = self else { return }
          self.zoomedImageViewTapped(oimg, x, y)
        }
        ziv.onHighResImgNeeded(zoomFactor: 1.1) { (optionalImage, finishedCallback) in
          guard let oPdfImg = optionalImage as? ZoomedPdfImageSpec else { return }
          oPdfImg.renderImageWithNextScale(finishedCallback:finishedCallback)
        }
        dataItem?.renderFullscreenImageIfNeeded { [weak self] success in
          self?.handleRenderFinished(success, ziv)
        }
        return ziv
      }
    }
    /*...ToDo: disable this, disables the black page 
    onEndDisplayCell { (_, optionalView) in
      guard let ziv = optionalView as? ZoomedImageView,
            let _pdfImg = ziv.optionalImage as? ZoomedPdfImageSpec else { return }
      var pdfImg = _pdfImg
      if ziv.imageView.image == pdfImg.image {
        pdfImg.image = nil
        ziv.imageView.image = nil
      }
    }*/
    
    onDisplay { [weak self] (idx, optionalView, isFromScroll) in
      guard let ziv = optionalView as? ZoomedImageView,
            let pdfImg = ziv.optionalImage as? ZoomedPdfImageSpec else { return }
      ziv.menu.menu = self?.menuItems ?? []
      ///enables scrolling on page, even if page is much smaller, so tolbar can (dis)appear on scroll
//      ziv.scrollView.contentInset = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
      if ziv.imageView.image == nil
      {
        ziv.optionalImage = pdfImg
        ziv.imageView.image = pdfImg.image
        pdfImg.renderFullscreenImageIfNeeded { [weak self] success in
          self?.handleRenderFinished(success, ziv)
        }
      }
    }
  }
  
  open func handleRenderFinished(_ success:Bool, _ ziv:ZoomedImageView){
    if success == false { return }
    onMain {
      ziv.scrollView.setZoomScale(1.0, animated: false)
      ziv.scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: false)
    }
  }
}
