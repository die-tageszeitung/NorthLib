//
//  ViewExtensions.swift
//
//  Created by Norbert Thies on 2019-02-28
//  Copyright © 2019 Norbert Thies. All rights reserved.
//
//  This file implements some UIView extensions
//

import UIKit

/// Find view controller of given UIView: UIResponder
public extension UIResponder {
  var parentViewController: UIViewController? {
    return next as? UIViewController ?? next?.parentViewController
  }
}

/// A CALayer extension to produce a snapshot
public extension CALayer {
  /// Returns snapshot of current layer as UIImage
  var snapshot: UIImage? {
    let scale = UIScreen.main.scale
    UIGraphicsBeginImageContextWithOptions(frame.size, false, scale)
    defer { UIGraphicsEndImageContext() }
    guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
    render(in: ctx)
    return UIGraphicsGetImageFromCurrentImageContext()
  }
}

/// A UIView extension to produce a snapshot
public extension UIView {
  /// Returns snapshot of current view as UIImage
  var snapshot: UIImage? {
    let renderer = UIGraphicsImageRenderer(size: frame.size)
    return renderer.image { _ in
      drawHierarchy(in: bounds, afterScreenUpdates: true)
    }
  }
}

/// A UIView extension to change subview order
public extension UIView {
  /// Returns Self for chaining
  @discardableResult
  func bringToFront() -> Self {
    if let sv = self.superview {
      sv.bringSubviewToFront(self)
    }
    return self
  }
}

/// A UIView extension to check visibility of a view
public extension UIView {
  /// Return whether view is visible somewhere on the screen
  var isVisible: Bool { self.window != nil && !self.isHidden }
}

/// A UIView extension to check if view is on top in parents view hirarchy
public extension UIView {
  var isTopmost : Bool {
    get {
      guard let sv = self.superview else { return false }
      return sv.subviews.last == self
    }
  }
}

/// A UIView extension to process Layout Cycle
public extension UIView {
  func doLayout(){
    self.setNeedsUpdateConstraints()
    self.setNeedsLayout()
    self.updateConstraintsIfNeeded()
    self.layoutIfNeeded()
  }
}

/// A UIView extension to show/hide views animated
public extension UIView {
  func showAnimated(duration:CGFloat=0.3, completion: (()->())? = nil){
    if isHidden == false { completion?(); return }
    onMain { [weak self] in
      self?.alpha = 0.0
      self?.isHidden = false
      UIView.animate(withDuration: TimeInterval(duration)) {[weak self] in
        self?.alpha = 1.0
      } completion: {_ in
        completion?()
      }
    }
  }
  
  func hideAnimated(duration:CGFloat=0.3, completion: (()->())? = nil){
    if isHidden == true { completion?(); return }
    onMain { [weak self] in
      UIView.animate(withDuration: TimeInterval(duration)) {[weak self] in
        self?.alpha = 0.0
      } completion: { [weak self] _ in
        self?.isHidden = true
        self?.alpha = 1.0
        completion?()
      }
    }
  }
}

/// a extension to wrap a view with another view and given paddings/insets
public extension UIView {
  
  /// add self to a wrapper View, pin with dist and return wrapper view
  /// - Parameter dist: dist to pin between wrapper and self
  /// - Returns: wrapper
  @discardableResult
  func wrapper(_ insets: UIEdgeInsets, priority: UILayoutPriority? = nil) -> UIView {
    let wrapper = UIView()
    wrapper.addSubview(self)
    pin(self.left, to: wrapper.left, dist: insets.left, priority: priority)
    pin(self.right, to: wrapper.right, dist: insets.right, priority: priority)
    pin(self.top, to: wrapper.top, dist: insets.top, priority: priority)
    pin(self.bottom, to: wrapper.bottom, dist: insets.bottom, priority: priority)
    return wrapper
  }
}

///chaining helper extension to set background color
public extension UIView {
  /// set backgroundColor and return self (for chaining)
  /// - Parameter backgroundColor: backgroundColor to set
  /// - Returns: self
  @discardableResult
  func set(backgroundColor: UIColor) -> UIView {
    self.backgroundColor = backgroundColor
    return self
  }
}

//blur background helper, not working
//extension UIView {
//  ///Blur Idea from: https://stackoverflow.com/questions/30953201/adding-blur-effect-to-background-in-swift
//  /// not working here for chaining, need also effect style depending dark/light
//  func addBlur() -> UIView {
//    let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.extraLight)
//    let blurEffectView = UIVisualEffectView(effect: blurEffect)
//    blurEffectView.frame = self.bounds
//    blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//    self.addSubview(blurEffectView)
//    return self
//  }
//}



/// A UIView extension to show/hide views animated
public extension Array where Element==UIView {
  func showAnimated(duration:CGFloat=0.3, completion: (()->())? = nil){
    let hiddenItems = self.filter{ $0.isHidden }
    if hiddenItems.count == 0 { completion?(); return }
    onMain {
      let itms: [UIView] = hiddenItems.map{ $0.alpha = 0.0; $0.isHidden = false; return $0 }
      UIView.animate(withDuration: TimeInterval(duration)) {
        _ = itms.map{ $0.alpha = 1.0 }
      } completion: {_ in
        completion?()
      }
    }
  }
  
  func hideAnimated(duration:CGFloat=0.3, completion: (()->())? = nil){
    let visibleItems = self.filter{ $0.isVisible }
    if visibleItems.count == 0 { completion?(); return }
    onMain {
      UIView.animate(withDuration: TimeInterval(duration)) {
        _ = visibleItems.map{ $0.alpha = 0.0}
      } completion: {_ in
        _ = visibleItems.map{ $0.isHidden = true; $0.alpha = 1.0 }
        completion?()
      }
    }
  }
}

// Layout anchors and corresponding views:
public struct LayoutAnchorX {
  public var anchor: NSLayoutXAxisAnchor
  public var view: UIView
  init(_ view: UIView, _ anchor: NSLayoutXAxisAnchor) 
    { self.view = view; self.anchor = anchor }
}

public struct LayoutAnchorY {
  public var anchor: NSLayoutYAxisAnchor
  public var view: UIView
  init(_ view: UIView, _ anchor: NSLayoutYAxisAnchor) 
    { self.view = view; self.anchor = anchor }
}

public struct LayoutDimension {
  public var anchor: NSLayoutDimension
  public var view: UIView
  init(_ view: UIView, _ anchor: NSLayoutDimension) 
    { self.view = view; self.anchor = anchor }
}

// Mostly Auto-Layout related extensions
public extension UIView {
  
  /// Bottom anchor
  var bottom: LayoutAnchorY { return LayoutAnchorY(self, bottomAnchor) }
  /// Top anchor
  var top: LayoutAnchorY { return LayoutAnchorY(self, topAnchor) }
  /// Vertical center anchor
  var centerY: LayoutAnchorY { return LayoutAnchorY(self, centerYAnchor) }
  /// Left Anchor
  var left: LayoutAnchorX { return LayoutAnchorX(self, leftAnchor) }
  /// Right Anchor
  var right: LayoutAnchorX { return LayoutAnchorX(self, rightAnchor) }
  /// Horizontal center anchor
  var centerX: LayoutAnchorX { return LayoutAnchorX(self, centerXAnchor) }
  /// Width anchor
  var width: LayoutDimension { return LayoutDimension(self, widthAnchor) }
  /// Height anchor
  var height: LayoutDimension { return LayoutDimension(self, heightAnchor) }

  /// Bottom margin anchor
  func bottomGuide(isMargin: Bool = false) -> LayoutAnchorY { 
    let guide = isMargin ? layoutMarginsGuide : safeAreaLayoutGuide
    return LayoutAnchorY(self, guide.bottomAnchor)
  }
  /// Top margin anchor
  func topGuide(isMargin: Bool = false) -> LayoutAnchorY { 
    let guide = isMargin ? layoutMarginsGuide : safeAreaLayoutGuide
    return LayoutAnchorY(self, guide.topAnchor)
  }
  /// Left margin Anchor
  func leftGuide(isMargin: Bool = false) -> LayoutAnchorX { 
    let guide = isMargin ? layoutMarginsGuide : safeAreaLayoutGuide
    return LayoutAnchorX(self, guide.leftAnchor)
  }
  /// Right margin Anchor
  func rightGuide(isMargin: Bool = false) -> LayoutAnchorX { 
    let guide = isMargin ? layoutMarginsGuide : safeAreaLayoutGuide
    return LayoutAnchorX(self, guide.rightAnchor)
  }
  
  /// Pin width of view
  @discardableResult
  func pinWidth(_ width: CGFloat,
                relation: NSLayoutConstraint.Relation? = .equal,
                priority: UILayoutPriority? = nil) -> NSLayoutConstraint {
    translatesAutoresizingMaskIntoConstraints = false
    
    var constraint:NSLayoutConstraint
    switch relation {
      case .lessThanOrEqual:
        constraint = widthAnchor.constraint(lessThanOrEqualToConstant: width)
      case .greaterThanOrEqual:
        constraint = widthAnchor.constraint(greaterThanOrEqualToConstant: width)
      default:
        constraint = widthAnchor.constraint(equalToConstant: width)
    }
    if let prio = priority { constraint.priority = prio }
    constraint.isActive = true
    return constraint
  }
  @discardableResult
  func pinWidth(_ width: Int, priority: UILayoutPriority? = nil) -> NSLayoutConstraint { return pinWidth(CGFloat(width)) }
  
  @discardableResult
  func pinWidth(to: LayoutDimension, dist: CGFloat = 0, factor: CGFloat = 1, priority: UILayoutPriority? = nil)
    -> NSLayoutConstraint { 
      translatesAutoresizingMaskIntoConstraints = false
      let constraint = widthAnchor.constraint(equalTo: to.anchor, 
        multiplier: factor, constant: dist)
      if let prio = priority { constraint.priority = prio }
      constraint.isActive = true
      return constraint
  }
  
  /// Pin height of view
  @discardableResult
  func pinHeight(_ height: CGFloat, priority: UILayoutPriority? = nil) -> NSLayoutConstraint {
    translatesAutoresizingMaskIntoConstraints = false
    let constraint = heightAnchor.constraint(equalToConstant: height)
    if let prio = priority { constraint.priority = prio }
    constraint.isActive = true
    return constraint
  }
  @discardableResult
  func pinHeight(_ height: Int, priority: UILayoutPriority? = nil) -> NSLayoutConstraint { return pinHeight(CGFloat(height), priority: priority) }
  
  @discardableResult
  func pinHeight(to: LayoutDimension, dist: CGFloat = 0, factor: CGFloat = 1, priority: UILayoutPriority? = nil)
    -> NSLayoutConstraint { 
      translatesAutoresizingMaskIntoConstraints = false
      let constraint = heightAnchor.constraint(equalTo: to.anchor,
        multiplier: factor, constant: dist)
      if let prio = priority { constraint.priority = prio}
      constraint.isActive = true
      return constraint
  }
  
  /// Pin size (width + height)
  @discardableResult
  func pinSize(_ size: CGSize, priority: UILayoutPriority? = nil) -> (width: NSLayoutConstraint, height: NSLayoutConstraint) {
    return (pinWidth(size.width, priority: priority), pinHeight(size.height, priority: priority))
  }
  
  @discardableResult
  /// Pin aspect ratio (width/height)
  /// - Parameters:
  ///   - ratio: ration to pin w/h
  ///   - pinWidth: pin width otherwise pin height
  /// - Returns: constraint of pin
  func pinAspect(ratio: CGFloat,
                 pinWidth: Bool = true,
                 priority: UILayoutPriority? = nil) -> NSLayoutConstraint {
    translatesAutoresizingMaskIntoConstraints = false
    //let ratio = (!pinWidth && ratio == 0.0) ? 1.0 : ratio ///prevent divisionby zero
    let ratio = ratio == 0.0 ? 1.0 : ratio ///ratio of 0.0 make no sense so set it to square
    let constraint
    = pinWidth
    ? widthAnchor.constraint(equalTo: heightAnchor, multiplier: ratio)
    : heightAnchor.constraint(equalTo: widthAnchor, multiplier: 1/ratio)
    if let prio = priority { constraint.priority = prio }
    constraint.isActive = true
    return constraint
  }
  
  static func animate(seconds: Double, delay: Double = 0, closure: @escaping ()->(), completion: ((Bool) -> Void)? = nil) {
    UIView.animate(withDuration: seconds, delay: delay, options: .curveEaseOut,
                   animations: closure, completion: completion)
  }
  
  /// Centers x axis to superviews x axis
  @discardableResult
  func centerX(_ priority: UILayoutPriority? = nil) -> NSLayoutConstraint? {
    translatesAutoresizingMaskIntoConstraints = false
    guard let sv = self.superview else { return nil }
    return pin(self.centerX, to: sv.centerX, priority: priority)
  }
  
  /// Centers y axis to superviews y axis
  @discardableResult
  func centerY(dist: CGFloat = 0, _ priority: UILayoutPriority? = nil) -> NSLayoutConstraint? {
    translatesAutoresizingMaskIntoConstraints = false
    guard let sv = self.superview else { return nil }
    return pin(self.centerY, to: sv.centerY, dist: dist, priority: priority)
  }
  
  /// Centers  axis to superviews  axis
  @discardableResult
  func centerAxis(_ priority: UILayoutPriority? = nil) -> (x: NSLayoutConstraint? ,y: NSLayoutConstraint?)  {
    return (centerX(priority), centerY(priority))
  }
    
} // extension UIView

/// Pin vertical anchor of one view to vertical anchor of another view
@discardableResult
public func pin(_ la: LayoutAnchorY, to: LayoutAnchorY, 
                dist: CGFloat = 0, priority: UILayoutPriority? = nil) -> NSLayoutConstraint {
  la.view.translatesAutoresizingMaskIntoConstraints = false
  let constraint = la.anchor.constraint(equalTo: to.anchor, constant: dist)
  if let prio = priority { constraint.priority = prio }
  constraint.isActive = true
  return constraint
}

/// Pin horizontal anchor of one view to horizontal anchor of another view
@discardableResult
public func pin(_ la: LayoutAnchorX,
                to: LayoutAnchorX,
                dist: CGFloat = 0,
                priority: UILayoutPriority? = nil) -> NSLayoutConstraint {
  la.view.translatesAutoresizingMaskIntoConstraints = false
  let constraint = la.anchor.constraint(equalTo: to.anchor, constant: dist)
  if let prio = priority { constraint.priority = prio }
  constraint.isActive = true
  return constraint
}

/// Pin width/height to width/height of another view
@discardableResult
public func pin(_ la: LayoutDimension, to: LayoutDimension, 
  dist: CGFloat = 0, priority: UILayoutPriority? = nil) -> NSLayoutConstraint {
  la.view.translatesAutoresizingMaskIntoConstraints = false
  let constraint = la.anchor.constraint(equalTo: to.anchor, constant: dist)
  if let prio = priority { constraint.priority = prio }
  constraint.isActive = true
  return constraint
}

/// Pin all edges of one view to the edges of another view
@discardableResult
public func pin(_ view: UIView, to: UIView, dist: CGFloat = 0, priority: UILayoutPriority? = nil) -> (top: NSLayoutConstraint,
  bottom: NSLayoutConstraint, left: NSLayoutConstraint, right: NSLayoutConstraint) {
  let top = pin(view.top, to: to.top, dist: dist, priority: priority)
  let bottom = pin(view.bottom, to: to.bottom, dist: -dist, priority: priority)
  let left = pin(view.left, to: to.left, dist: dist, priority: priority)
  let right = pin(view.right, to: to.right, dist: -dist, priority: priority)
  return (top, bottom, left, right)
}

/// Pin all edges of one view to the edges of another view's safe layout guide
@discardableResult
public func pin(_ view: UIView, toSafe: UIView, dist: CGFloat = 0) -> (top: NSLayoutConstraint, 
  bottom: NSLayoutConstraint, left: NSLayoutConstraint, right: NSLayoutConstraint) {
  let top = pin(view.top, to: toSafe.topGuide(), dist: dist)
  let bottom = pin(view.bottom, to: toSafe.bottomGuide(), dist: -dist)
  let left = pin(view.left, to: toSafe.leftGuide(), dist: dist)
  let right = pin(view.right, to: toSafe.rightGuide(), dist: -dist)
  return (top, bottom, left, right)
}

public typealias tblrConstrains = (
  top: NSLayoutConstraint?,
  bottom: NSLayoutConstraint?,
  left: NSLayoutConstraint?,
  right: NSLayoutConstraint?)

// MARK: - pinnAll Helper

@discardableResult
public func pin(_ view: UIView, to: UIView, insets: UIEdgeInsets, exclude: UIRectEdge? = nil) -> tblrConstrains {
  var top:NSLayoutConstraint?, left:NSLayoutConstraint?, bottom:NSLayoutConstraint?, right:NSLayoutConstraint?
  exclude != UIRectEdge.top ? top = pin(view.top, to: to.top, dist: insets.top) : nil
  exclude != UIRectEdge.left ? left = pin(view.left, to: to.left, dist: insets.left) : nil
  exclude != UIRectEdge.right ? right = pin(view.right, to: to.right, dist: insets.right) : nil
  exclude != UIRectEdge.bottom ? bottom = pin(view.bottom, to: to.bottom, dist: insets.bottom) : nil
  return (top, bottom, left, right)
}

/// Pin all edges, except one of one view to the edges of another view's safe layout guide
@discardableResult
public func pin(_ view: UIView, to: UIView, dist: CGFloat = 0, exclude: UIRectEdge) -> tblrConstrains {
  var top:NSLayoutConstraint?, left:NSLayoutConstraint?, bottom:NSLayoutConstraint?, right:NSLayoutConstraint?
  exclude != UIRectEdge.top ? top = pin(view.top, to: to.top, dist: dist) : nil
  exclude != UIRectEdge.left ? left = pin(view.left, to: to.left, dist: dist) : nil
  exclude != UIRectEdge.right ? right = pin(view.right, to: to.right, dist: -dist) : nil
  exclude != UIRectEdge.bottom ? bottom = pin(view.bottom, to: to.bottom, dist: -dist) : nil
  return (top, bottom, left, right)
}

@discardableResult
public func pin(_ view: UIView, toSafe: UIView, insets: UIEdgeInsets, exclude: UIRectEdge? = nil) -> tblrConstrains {
  var top:NSLayoutConstraint?, left:NSLayoutConstraint?, bottom:NSLayoutConstraint?, right:NSLayoutConstraint?
  exclude != UIRectEdge.top ? top = pin(view.top, to: toSafe.topGuide(), dist: insets.top) : nil
  exclude != UIRectEdge.left ? left = pin(view.left, to: toSafe.leftGuide(), dist: insets.left) : nil
  exclude != UIRectEdge.right ? right = pin(view.right, to: toSafe.rightGuide(), dist: insets.right) : nil
  exclude != UIRectEdge.bottom ? bottom = pin(view.bottom, to: toSafe.bottomGuide(), dist: insets.bottom) : nil
  return (top, bottom, left, right)
}

@discardableResult
public func pin(_ view: UIView, toSafe: UIView, dist: CGFloat = 0, exclude: UIRectEdge? = nil) -> tblrConstrains {
  var top:NSLayoutConstraint?, left:NSLayoutConstraint?, bottom:NSLayoutConstraint?, right:NSLayoutConstraint?
  exclude != UIRectEdge.top ? top = pin(view.top, to: toSafe.topGuide(), dist: dist) : nil
  exclude != UIRectEdge.left ? left = pin(view.left, to: toSafe.leftGuide(), dist: dist) : nil
  exclude != UIRectEdge.right ? right = pin(view.right, to: toSafe.rightGuide(), dist: -dist) : nil
  exclude != UIRectEdge.bottom ? bottom = pin(view.bottom, to: toSafe.bottomGuide(), dist: -dist) : nil
  return (top, bottom, left, right)
}

/// A simple UITapGestureRecognizer wrapper
open class TapRecognizer: UITapGestureRecognizer {  
  public var onTapClosure: ((UITapGestureRecognizer)->())?  
  @objc private func handleTap(sender: UITapGestureRecognizer) { onTapClosure?(sender) }
  /// Define closure to call upon Tap
  open func onTap(view: UIView, nTaps: Int = 1,
                  closure: @escaping (UITapGestureRecognizer)->()) {
    self.numberOfTapsRequired = nTaps
    view.isUserInteractionEnabled = true
    view.addGestureRecognizer(self)
    onTapClosure = closure 
  }  
  public init() { 
    super.init(target: nil, action: nil) 
    addTarget(self, action: #selector(handleTap))
  }
}

/// An view with a tap gesture recognizer attached
public protocol Touchable where Self: UIView {
  var tapRecognizer: TapRecognizer { get }
}

extension Touchable {
  /// Define closure to call upon tap
  public func onTap(closure: @escaping (UITapGestureRecognizer)->()) {
    self.tapRecognizer.onTap(view: self, closure: closure)
  }
  public func onTaps(nTaps: Int, closure: @escaping (UITapGestureRecognizer)->()) {
    self.tapRecognizer.onTap(view: self, nTaps: nTaps, closure: closure)
  }
}

/// A touchable UILabel
public class Label: UILabel, Touchable {
  public var tapRecognizer = TapRecognizer()
}

public class HidingLabel: Label {
  public override func layoutSubviews() {
    super.layoutSubviews()
    self.isHidden = bounds.size.width < intrinsicContentSize.width
  }
}
