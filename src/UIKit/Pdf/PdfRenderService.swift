//
//  PdfRenderService.swift
//  taz.neo
//
//  Created by Ringo Müller-Gromes on 13.11.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit
import PDFKit


/// Service that renders PDF's on limited count of Threads,
/// each parallel render open its own file handle
/// to avoid memory leaks within unclosed UIGraphicsContext PDF File handles
public class PdfRenderService : DoesLog {
  
  public static var isDebug = true
  public var isDebugLogging: Bool { Self.isDebug }

  private static let sharedInstance = PdfRenderService()
  private init(){}
  
  private let userInteractiveSemaphore = DispatchSemaphore(value: 2)//How many 1:! Renderings parallel?
  private let backgroundSemaphore = DispatchSemaphore(value: 4)//How many 1:! Renderings parallel?
  
  private let userInteractiveQueue = DispatchQueue.init(label: "imageRendererQueue",
                                 qos: .userInteractive,
                                 attributes: .concurrent,
                                 autoreleaseFrequency: .workItem,
                                 target: nil)
  
  private let backgroundQueue = DispatchQueue.init(label: "backgroundImageRendererQueue",
                                 attributes: .concurrent,
                                 autoreleaseFrequency: .workItem,
                                 target: nil)
    
  public static func render(item:ZoomedPdfImageSpec,
                            scale:CGFloat = 1.0,
                            backgroundRenderer : Bool = false,
                            finishedCallback: @escaping((UIImage?)->())){
    sharedInstance.enqueueRender(item: item,
                               scale: scale,
                               backgroundRenderer : backgroundRenderer,
                               finishedCallback: finishedCallback)
  }
  
  public static func render(item:ZoomedPdfImageSpec,
                            width: CGFloat,
                            screenScaled: Bool = true,
                            backgroundRenderer : Bool = false,
                            finishedCallback: @escaping((UIImage?)->())){
    sharedInstance.enqueueRender(item: item,
                               width: width,
                               screenScaled: screenScaled,
                               backgroundRenderer : backgroundRenderer,
                               finishedCallback: finishedCallback)
  }
  
  public static func render(item:ZoomedPdfImageSpec,
                            height: CGFloat,
                            screenScaled: Bool = true,
                            backgroundRenderer : Bool = false,
                            finishedCallback: @escaping((UIImage?)->())){
    sharedInstance.enqueueRender(item: item,
                                 height: height,
                                 screenScaled: screenScaled,
                                 backgroundRenderer : backgroundRenderer,
                                 finishedCallback: finishedCallback)
  }
  
  public static func render(item:ZoomedPdfImageSpec,
                            height: CGFloat,
                            backgroundRenderer : Bool = false,
                            finishedCallback: @escaping((UIImage?)->())){
    sharedInstance.enqueueRender(item: item,
                               height: height,
                               backgroundRenderer : backgroundRenderer,
                               finishedCallback: finishedCallback)
  }
  
  private func enqueueRender(item:ZoomedPdfImageSpec,
                             scale:CGFloat = 1.0,
                             width: CGFloat? = nil,
                             height: CGFloat? = nil,
                             screenScaled: Bool = true,
                             backgroundRenderer : Bool = false,
                             finishedCallback: (@escaping(UIImage?)->())){
    let queue = backgroundRenderer ? backgroundQueue : userInteractiveQueue
    let semaphore = backgroundRenderer ? backgroundSemaphore : userInteractiveSemaphore
    
    queue.async { [weak self] in
      let debugEnqueuedStart = Date()
      guard let pdfPage = item.pdfPage else {
        finishedCallback(nil)
        return
      }
      semaphore.wait()
      let debugRenderStart = Date()
      ///Check if stopped meanwhile, then no finishedCallback !? TODO Verify logic!
      if item.renderingStoped == false {
        var img : UIImage?
        if let w = width {
          img = pdfPage.image(width: w, screenScaled)
        }
        else if let h = height {
          img = pdfPage.image(height: h, screenScaled)
        }
        else {
          img = pdfPage.image(scale:scale)
        }
        
        var additionalInfo = ""
        if let zpdfi = item as? ZoomedPdfImage {
          additionalInfo = "ZoomedPdfImage with url: \(String(describing:zpdfi.pdfUrl)) and index: \(String(describing: zpdfi.pdfPageIndex))"
        }
        else {
          additionalInfo = "A Page with Document: \(String(describing:item.pdfPage?.document?.documentURL))"
        }
        
        self?.debug("Render for: \(additionalInfo) done"
              + "\n   scale: \(scale) width: \(width ?? 0) height: \(height ?? 0) screenScaled: \(screenScaled)"
              + "\n   screenScaled: \(screenScaled) backgroundRenderer: \(backgroundRenderer)"
              + "\n   Duration since enqueued: \(Date().timeIntervalSince(debugEnqueuedStart)) "
              + "renderStart: \(Date().timeIntervalSince(debugRenderStart))")
        finishedCallback(img)
      }
      semaphore.signal()
    }
  }
}

extension PDFPage : @retroactive DoesLog {

  public var isDebugLogging: Bool { PdfRenderService.isDebug }

  fileprivate func image(scale: CGFloat = 1.0) -> UIImage? {
    var img: UIImage?
    guard let ref = self.pageRef else { return nil}
    var frame = self.frame ?? ref.getBoxRect(.cropBox)
    frame.size.width *= scale
    frame.size.height *= scale
    frame.origin.x = 0
    frame.origin.y = 0
    if frame.width > 300 {
      self.debug("TRY TO RENDER IMAGE WITH: \(frame.size)")
    }
    
    if avoidRenderDueExpectedMemoryIssue(frame, scale) { return nil }
    
    UIGraphicsBeginImageContext(frame.size)
    
    if let ctx = UIGraphicsGetCurrentContext() {
      ctx.saveGState()
      UIColor.white.set()
      ctx.fill(frame)
      ctx.translateBy(x: 0.0, y: frame.size.height)
      ctx.scaleBy(x: 1.0, y: -1.0)
      ctx.scaleBy(x: scale, y: scale)
      ctx.drawPDFPage(ref)
      img = UIGraphicsGetImageFromCurrentImageContext()
      ctx.restoreGState()
    }
    
    UIGraphicsEndImageContext()
    if frame.width > 300 {
      debug("rendered image width: \(frame.width) imagesize: \(img?.mbSize ?? 0) MB")
    }
    return img
  }
  
  private func avoidRenderDueExpectedMemoryIssue(_ frame:CGRect, _ scale:CGFloat? = nil) -> Bool {
    /// Limit to max Device RAM Usage
    var maxPercentageRamUsage : UInt64 = 45
    /// In CGContextRender iOS lower than 13.7 crash on low memory. Higher versions do not!
    var isProblematicSystemVersion = false
    
    if #available(iOS 13.7, *) { }
    else {
      maxPercentageRamUsage = 30//Page 1 from 2020-11-18 kill all plans! :-(
      isProblematicSystemVersion = true
    }
    
    let expectedImageSize = Int64(frame.size.width*frame.size.height*4)
    let maxUseableRam = Int64(maxPercentageRamUsage*ProcessInfo.processInfo.physicalMemory/100)
    let tooBig = expectedImageSize > maxUseableRam
    let scaleInfo = scale != nil ? " @\(Double(round(100*scale!)/100))x " : ""
    
    //Print Debug Info
    if isProblematicSystemVersion, tooBig {
      self.debug("⚠️ image rendering \(scaleInfo) is expected to fail! 🛑 Do Not Render! expectedImageSize: \(expectedImageSize/(1024*1024)) MB > \(maxUseableRam/(1024*1024)) MB useable RAM")
    }
    else if tooBig {
      self.debug("⚠️ image rendering \(scaleInfo) is expected to fail! expectedImageSize: \(expectedImageSize/(1024*1024)) MB > \(maxUseableRam/(1024*1024)) MB useable RAM")
    } else {
      self.debug("no expecting render issues  \(scaleInfo) expectedImageSize: \(expectedImageSize/(1024*1024)) MB, \(maxUseableRam/(1024*1024)) MB useable RAM")
    }
    return isProblematicSystemVersion && tooBig
  }

  
  fileprivate func image(width: CGFloat, _ screenScaled: Bool = true) -> UIImage? {
    guard let frame = self.frame else { return nil }
    if screenScaled == false {
      return image(scale:  width/frame.size.width)
    }
    return image(scale:  width/frame.size.width)?.scaled()
  }
  
  fileprivate func image(height: CGFloat, _ screenScaled: Bool = true) -> UIImage? {
    guard let frame = self.frame else { return nil }
    if screenScaled == false {
      return image(scale:  height/frame.size.height)
    }
    return image(scale:  height/frame.size.height)?.scaled()
  }
  
  public var frame: CGRect? { self.pageRef?.getBoxRect(.cropBox) }
}

