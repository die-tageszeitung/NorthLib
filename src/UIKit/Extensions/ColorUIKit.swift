//
//  ColorExtensions.swift
//
//  Created by Norbert Thies on 15.04.16.
//  Copyright © 2016 Norbert Thies. All rights reserved.
//

import UIKit


public extension UIColor {
  
  /// Create a dynamic color that responds to `userInterfaceStyle` trait changes
  /// - Parameters:
  ///   - light: color value to use for lightMode
  ///   - dark: color to use for darkMode
  convenience init(light: UIColor, dark: UIColor) {
    guard #available(iOS 13.0, *) else { self.init(cgColor: light.cgColor); return }
    self.init(dynamicProvider: { $0.userInterfaceStyle == .dark ? dark : light })
  }
  
  /// Returns a UIColor from an Int with 0xRRGGBB
  static func rgb(_ color: Int, alpha: CGFloat = 1.0) -> UIColor {
    let blue:CGFloat = CGFloat(color & 0xff),
        green:CGFloat = CGFloat( (color >> 8) & 0xff ),
        red:CGFloat = CGFloat( (color >> 16) & 0xff )
    return UIColor(red: red/255, green: green/255, blue: blue/255, alpha: alpha)
  }
  
  /// Returns a tuple (red,green,blue,alpha) of CGFloat values (0<=value<=1)
  func rgba() -> (red:CGFloat, green:CGFloat, blue:CGFloat, alpha:CGFloat) {
    var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
    getRed( &r, green: &g, blue: &b, alpha: &a )
    return (r,g,b,a)
  }
  
  /**
   * Returns a lighter or darker color depending on `factor`.
   *
   * This operator takes a UIColor `color` and returns a newly created color
   * so that the red, green, blue components of `color` are multiplied by `factor`.
   * `factor` will be reduced if the product of one component would become > 1.
   *
   * - Parameters:
   *   - factor: make color lighter if > 1, darker if < 1
   * - Returns: a new UIColor object with a lighter or darker color.
   */
  static func *(color: UIColor, factor: CGFloat) -> UIColor {
    var (r,g,b,a) = color.rgba()
    var m = factor
    for v in [r,g,b] {
      if v > 0.01 {
        let f = 1/v
        if f < m { m = f }
    } }
    r *= m; g *= m; b *= m;
    return UIColor(red: r, green: g, blue: b, alpha: a)
  }
  
  /// Interprete the color as a 3-dimensional vector and return its length
  /// 0<=l<=sqrt(3)
  var abs: CGFloat {
    let (r,g,b,_) = rgba()
    return sqrt(r*r+g*g+b*b)
  }

  
  /**
   * Returns a lighter or darker color depending on `add`.
   *
   * This operator takes a UIColor `color` and returns a newly created color
   * so that the red, green, blue components of `color` are increased by `add`.
   *
   * - Parameters:
   *   - add: make color lighter if > 0, darker if < 0 (-1<=add<=1)
   * - Returns: a new UIColor object with a lighter or darker color.
   */
  static func +(color: UIColor, add: CGFloat) -> UIColor {
    let (r,g,b,a) = color.rgba()
    let rgb = [r,g,b].map { max(0,min(1,$0+add)) }
    return UIColor(red: rgb[0], green: rgb[1], blue: rgb[2], alpha: a)
  }
  static func -(color: UIColor, add: CGFloat) -> UIColor { return color + -add }
    
  /// Produces a slightly darker or lighter color, depending on whether
  /// abs >= sqrt(3)/2 (darker)
  func dimmed() -> UIColor {
    let med: CGFloat = sqrt(3)/2
    let abs = self.abs
    if abs >= med { return self - 0.2 }
    else { return self + 0.2 }
  }
  
  /// Returns a Hex-String describing the RGB values plus alpha
  func toString() -> String {
    func toHex(_ val: CGFloat) -> String {
      let v = Int(round(val*255))
      return String(format: "%02X", v)
    }
    let (r,g,b,a) = self.rgba()
    var ret = toHex(r)
    ret += toHex(g)
    ret += toHex(b)
    ret += " a:" + String(format: "%.2f", a)
    return ret
  }
  
}
