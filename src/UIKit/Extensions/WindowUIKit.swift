//
//  WindowExtensions.swift
//
//  Created by Norbert Thies on 28.02.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

/// A simple UIWindow extension
public extension UIWindow {

  /// Returns the key window
  static var activeKeyWindow: UIWindow? {
    return UIApplication.shared.activeKeyWindow
  }
  
  /// Returns the root view controller
  static var rootVC: UIViewController? { return activeKeyWindow?.rootViewController }
  
  /// Returns a snapshot of the key window
  static var snapshot: UIImage? { return activeKeyWindow?.snapshot }
  
  /// Returns a screenshot (ie. snapshot) of the key window
  static var screenshot: UIImage? { return snapshot }
  
  /// Returns the top inset of the window (ie. nodge area)
  static var topInset: CGFloat {
    return activeKeyWindow?.safeAreaInsets.top ?? 0
  }
  
  /// Returns the bottom inset of the window
  static var bottomInset: CGFloat {
    return activeKeyWindow?.safeAreaInsets.bottom ?? 0
  }
  
  /// Returns the max inset for all edges
  static var maxInset: CGFloat {
    let inset = safeInsets
    return max(inset.top, inset.left, inset.bottom, inset.right)
  }
  
  /// Returns the max inset for all edges
  static var maxAxisInset: CGFloat {
    let inset = safeInsets
    return max(inset.top + inset.bottom, inset.left + inset.right)
  }
  
  /// Returns the bottom inset of the window
  static var verticalInsets: CGFloat {
    return safeInsets.top + safeInsets.bottom
  }
  
  /// Returns the bottom inset of the window
  static var horizontalInsets: CGFloat {
    return safeInsets.left + safeInsets.right
  }
  
  /// Returns safe area Insets inset of the window
  static var safeInsets: UIEdgeInsets {
    return activeKeyWindow?.safeAreaInsets ?? .zero
  }
  
  /// Returns size the key window otherwise screen size
  static var size: CGSize {
    if let window = activeKeyWindow {
      return window.frame.size
    }
    return UIScreen.main.bounds.size
  }
  
  /// Returns width of the window
  static var width: CGFloat {
    return size.width
  }
  
  /// Returns short side's size of the window
  static var shortSide: CGFloat {
    let s = size
    return min(s.width, s.height)
  }
  
  /// Returns short side's size of the window
  static var longSide: CGFloat {
    let s = size
    return max(s.width, s.height)
  }
  
  /// Checks if the current active window is portrait by geometry
  static var isPortrait: Bool {
    guard let window = activeKeyWindow else { return true }
    return window.bounds.height >= window.bounds.width
  }
  
  /// Checks if the current active window is landscape by geometry
  static var isLandscape: Bool {
    !isPortrait
  }
  
  /// Checks landscape based on the Scene's interface orientation
  static var isLandscapeInterface: Bool {
    guard
      let scene = activeKeyWindow?.windowScene
    else {
      return isLandscape   // geometry fallback
    }
    
    switch scene.interfaceOrientation {
      case .landscapeLeft, .landscapeRight:
        return true
      default:
        return false
    }
  }
} // UIWindow

/// A simple UIScreen extension
public extension UIScreen {
  /// Returns short side's size of the window
  static var shortSide: CGFloat {
    let s = main.bounds.size
    return min(s.width, s.height)
  }
  
  /// Returns short side's size of the window
  static var longSide: CGFloat {
    let s = main.bounds.size
    return max(s.width, s.height)
  }
  
  static var isIpadRegularHorizontalSize: Bool {
    guard Device.isIpad else {  return false }
    guard let window = UIWindow.activeKeyWindow else {  return false }
    return window.traitCollection.horizontalSizeClass == .regular
  }
}

extension UIEdgeInsets {
  var verticalInsets: CGFloat {
    return self.top + self.bottom
  }
}
public extension UIDevice {
  static var isLandscape: Bool { return !isPortrait }
  static var isPortrait: Bool {
    let orientation = UIDevice.current.orientation
    if !orientation.isValidInterfaceOrientation {
      // fix device orientation return UIDeviceOrientationUnknown unless device orientation notifications is being generated.
      return UIWindow.isPortrait
    }
    return orientation.isPortrait
  }
}
