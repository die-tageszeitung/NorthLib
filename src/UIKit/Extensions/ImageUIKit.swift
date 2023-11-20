//
//  ImageExtensions.swift
//
//  Created by Norbert Thies on 28.02.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

public extension UIImage {
  
  /// Get Jpeg data from Image with a quality of 50%
  var jpeg: Data? { return jpegData(compressionQuality: 0.5) }
  
  /// Save the image as jpeg data to a file
  func save(to: String) {
    if let data = self.jpeg {
      try! data.write(to: URL(fileURLWithPath: to), options: [])
    }
  }
      
  /// Initialize with animated gif data
  static func animatedGif(_ data: Data) -> UIImage? {
    guard let source =  CGImageSourceCreateWithData(data as CFData, nil) 
      else { return nil }
    var images = [CGImage]()
    var delays = [Int]()
    var duration: Double = 0
    let imageCount = CGImageSourceGetCount(source)
    for i in 0..<imageCount {
      if let image = CGImageSourceCreateImageAtIndex(source, i, nil),
         let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil),
         let gifInfo = (properties as NSDictionary)[kCGImagePropertyGIFDictionary as String] as? NSDictionary,
         let gifDelay = (gifInfo[kCGImagePropertyGIFDelayTime as String] as? NSNumber)
      {
        var delay = gifDelay.floatValue
        delay = max(delay, 0.1)
        delay = min(delay, 1.0)
        images += image
        delays += Int(delay * 1000)
        duration += Double(delay)
      }
    }
    if images.count == imageCount {
      let div = gcd(delays)
      var frames = [UIImage]()
      for i in 0..<imageCount {
        let frame = UIImage(cgImage: images[i])
        var frameCount = delays[i] / div
        while frameCount > 0 { frames += frame; frameCount -= 1 }
      }
      return UIImage.animatedImage(with: frames, duration: duration)
    }
    else if images.count > 0 { return UIImage(cgImage: images[0]) }
    else { return nil }
  }
  
  /// Initialize with PDF data (use screen height to compute scale)
  static func pdf(_ data: Data,
                  width: CGFloat = UIScreen.main.bounds.width,
                  height: CGFloat = UIScreen.main.bounds.height,
                  useHeight: Bool = true) -> UIImage? {
    let doc = PdfDoc(data: data)
    guard let page0 = doc[0] else { return nil }
    if useHeight { return page0.image(height: height) }
    return page0.image(width: width)
  }
    
  /// Change Image Scale without expensive Rendering
  func scaled(_ scaleFactor:CGFloat = UIScreen.main.scale) -> UIImage {
    guard let cgi = self.cgImage else { return self }
    let img = UIImage(cgImage: cgi,
                   scale: scaleFactor,
                   orientation: self.imageOrientation)
    //ToDo How To Exclude log just DiesLog and log did not work
//    Log.log("Scale Image with: \(scaleFactor):"
//            + "\n  UIImage     size: \(self.size) scale: \(self.scale)x"
//            + "\n  cgImage     size: \(cgi.width)x\(cgi.height)"
//                + "\n  new UIImage size: \(img.size) scale: \(img.scale)x",
//              object: self,
//              logLevel: .Debug,
//              file: #file,
//              line: #line,
//              function: #function)
    return img
  }
  
} // UIImage

extension UIImage {
  public var mbSize: CGFloat{
    var i = 0
    i += 2
    
    guard let cgimg = self.cgImage else { return 0}
    return CGFloat((10*cgimg.height * cgimg.bytesPerRow)/(1024*1024))/10;
  }
}

extension UIImage {
  public func imageWithInsets(_ insets: UIEdgeInsets,
                              scale: CGFloat = UIScreen.main.scale,
                              tintColor: UIColor? = nil) -> UIImage? {
    let size = CGSize(width: self.size.width + insets.left + insets.right,
                      height: self.size.height + insets.top + insets.bottom)
    UIGraphicsBeginImageContextWithOptions(size, false, scale)
    let origin = CGPoint(x: insets.left, y: insets.top)
    if let color = tintColor {
      color.set()
      self.withRenderingMode(.alwaysTemplate).draw(at: origin)
    }
    else {
      self.draw(at: origin)
    }
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return newImage
  }
}
