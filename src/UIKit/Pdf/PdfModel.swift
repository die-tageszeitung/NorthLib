//
//  PdfModel.swift
//  NorthLib
//
//  Created by Ringo Müller-Gromes on 15.10.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation
import PDFKit

public struct PdfDisplayOptions {
  public struct Overview{
    static let singlePageItemsPerRow:Int = 2 //need calculation later for landscape or ipad layout
    /// On some devices default ratio 0f 0.8 is too big => resized slider width due taz icon need space also
    /// result: images rendered bigger than needed @see: PdfOverviewCollectionVC
    /// collectionView.cellForItemAt...  cell.imageView.contentMode = .topLeft
    public static let sliderCoverageRatio:CGFloat = Device.isIphone ? 0.855 : 0.5
    public static let sideSpacing:CGFloat = 16.0
    public static let interItemSpacing:CGFloat = 9.0
    public static let rowSpacing:CGFloat = 40.0
    
    /// width of pdf menu slider, page sizes are calculated for this
    /// |-sideSpacing-[Page]-interItemSpacing-[Page]-sideSpacing-|
    /// |-sideSpacing-[               PanoramaPage           ]-sideSpacing-|
    public static let sliderWidth:CGFloat = {
      let screenWidth = min(UIScreen.main.bounds.size.width,
                            UIScreen.main.bounds.size.height)
      return PdfDisplayOptions.Overview.sliderCoverageRatio*screenWidth
    }()
    
    public static let fallbackPageSize:CGSize = CGSize(width: 893, height: 1332.5)
  }
}


// MARK: PdfArrayModel
public protocol PdfModel {
  var title : String? { get }
  var count : Int { get }
  var imageSizeMb : UInt64 { get }
  var currentPage : Int { get set }
  var defaultRawPageSize: CGSize? { get }
  var singlePageSize: CGSize { get }
  func item(atIndex: Int) -> ZoomedPdfImageSpec?
  var images : [ZoomedPdfImageSpec] { get }
  func size(forItem atIndex: Int) -> CGSize
  func thumbnail(atIndex: Int, finishedClosure: ((UIImage?)->())?) -> UIImage?
}

extension PdfModel {
  public func thumbnail(atIndex: Int, finishedClosure: ((UIImage?)->())?) -> UIImage? {
    guard var pdfImg = self.item(atIndex: atIndex) else {
      return nil
    }
    if let waitingImage = pdfImg.waitingImage {
      return waitingImage
    }
    
    let height = singlePageSize.height
    
    PdfRenderService.render(item: pdfImg,
                            height: height*UIScreen.main.scale,
                            screenScaled: true,
                            backgroundRenderer: true){ img in
      pdfImg.waitingImage = img
      finishedClosure?(img)
    }
    return nil
  }
}



// MARK: PdfDocModel
class PdfModelItem : PdfModel, DoesLog/*, PDFOutlineStructure*/ {
  
  var isDebugLogging: Bool { PdfRenderService.isDebug }
  
  func size(forItem atIndex: Int) -> CGSize {
    return CGSize(width: 200, height: 260)
  }
  
  private var url:URL?
  var title: String?
  var count: Int = 0
  var currentPage: Int = 0
  var defaultItemSize: CGSize?
    
  var defaultRawPageSize: CGSize?
  var singlePageSize: CGSize
  var panoPageSize: CGSize?
  
  func item(atIndex: Int) -> ZoomedPdfImageSpec? {
    return images.valueAt(atIndex)
  }
  
  var images : [ZoomedPdfImageSpec] = []
  
  var pageMeta : [Int:String] = [:]
  
  var imageSizeMb : UInt64 {
    get{
      var totalSize:UInt64 = 0
      for case let img as ZoomedPdfImage in self.images {
        log("page: \(img.pdfPageIndex ?? -1) size:\(img.image?.mbSize ?? 0)")
        totalSize += UInt64(img.image?.mbSize ?? 0)
      }
      return totalSize
    }
  }
  
  init(url:URL?) {
    singlePageSize = .zero
    guard let url = url else { return }
    guard let pdfDocument = PDFDocument(url: url) else { return }
    self.url = url
      
    self.count = pdfDocument.pageCount
    //ensure pageWidth != 0 to prevent division by zero
    //early return with guard let not possible
    //crash not allowed, ..need to used fallback values
    guard let rawPageSize = pdfDocument.page(at: 0)?.frame?.size,
          rawPageSize.width > 0 else { return }
    
    self.defaultRawPageSize = rawPageSize
    let panoPageWidth
      = PdfDisplayOptions.Overview.sliderWidth
      - 2*PdfDisplayOptions.Overview.sideSpacing
    let singlePageWidth
      = (panoPageWidth - PdfDisplayOptions.Overview.interItemSpacing)/2
    let pageHeight = singlePageWidth * rawPageSize.height / rawPageSize.width
    self.singlePageSize = CGSize(width: singlePageWidth,
                                 height: pageHeight)
    self.panoPageSize = CGSize(width: panoPageWidth,
                               height: pageHeight)
    
    for pagenumber in 0...pdfDocument.pageCount-1{
      self.images.append(ZoomedPdfImage(url: url, index: pagenumber))
    }
  }
  
  /// Pin side or not to Pin Side?
  /// 1=>0 weil Seite 1 allein stehen soll    LEFT
  /// 4=>3 weil reale Pano Page                LEFT/GIGHT
  /// 7=>6 weil seite 7 allein stehen soll    RIGHT
  let doublePages = [0, 3, 6]
  
  
  func size(forItem atIndex: Int) -> CGSize? {
    return doublePages.contains(atIndex)
      ? self.panoPageSize
      : self.singlePageSize
  }
  
  func pageTitle(forItem atIndex: Int) -> String? {
    return "Seite:\(atIndex)"
  }
}
