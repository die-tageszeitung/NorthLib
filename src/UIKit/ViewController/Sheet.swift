//
//  Sheet.swift
//  NorthLib
//
//  Created by Ringo Müller on 29.07.25.
//

import UIKit

/**
 * die sliderView ist in der Elternklasse angelegt
 * slider.view ist Sheet(slider: self, into: targetVc) self also z.B. die view aus ContinueReadingController
 * via public func slide(toOpen: Bool, animated: Bool = true) {
      ...  if !isOpen {
 *         active.presentSubVC(controller: slider, inView: contentView)
 *         ///wird contentView.addSubview(slider.view)
 *         ///     slider.view.frame = contentView.bounds ///da muss contentView bereits die richtige abmessung haben!
            view.layoutIfNeeded()
 *            Achtung: slider hat keine Abmessungen!
 *
 *View Hirarchy:
 * contentView.addSubview(slider.view)
 *  sliderView.addSubview(contentView)
 *    active.view.addSubview(sliderView)
 *
 *
 *Größen
 *  in decorateSlider
 *  ...       pin(contentView.left, to: sliderView.left)
 pin(contentView.right, to: sliderView.right)
 *        pin(contentView.bottom, to: sliderView.bottom, priority: .fittingSizeLevel)
 pin(contentView.top, to: sliderView.top, dist: decorationHeight)
 *
 * dann gibts noch die lazy vars....
 *   public lazy var leadingButtonConstraint: NSLayoutConstraint =
 button.leadingAnchor.constraint(equalTo: sliderView.trailingAnchor)
public lazy var trailingButtonConstraint: NSLayoutConstraint =
 button.trailingAnchor.constraint(equalTo: sliderView.leadingAnchor)
public lazy var topButtonConstraint: NSLayoutConstraint =
 button.topAnchor.constraint(equalTo: active.view.safeAreaLayoutGuide.topAnchor)
public lazy var widthButtonConstraint: NSLayoutConstraint =
 button.widthAnchor.constraint(equalToConstant: 0)
public lazy var heightButtonConstraint: NSLayoutConstraint =
 button.heightAnchor.constraint(equalToConstant: 0)
 *...die aktiviert und deaktiviert werden können
 *
 *
 */
open class Sheet: VerticalSheet {
  
//  let ptView =  PassthroughView()
//  
//  public override var shadeView: UIView {
//    return ptView
//  }
  
  public var xButton = Button<ImageView>()
  
  open var sidePadding: CGFloat = 10.0
  
  open var bgContentView : UIView { contentView }
  
  override func decorateSlider(_ isDecorate: Bool) {
    decorationHeight = 10.0
    super.decorateSlider(isDecorate)
    sliderView.addSubview(xButton)
    pin(xButton.right, to: sliderView.rightGuide(), dist: -12)
    pin(xButton.top, to: sliderView.topGuide(), dist: 12)
    sliderView.layer.maskedCorners = [.allCorners]
  }
  
  public func onX(closure: @escaping ()->()) {
    xButton.isHidden = false
    xButton.onPress {_ in
      closure()
    }
  }
  
  override func setupInvariableConstraints() {
    let view = active.view!
    ///shade view is required for tapRecognizer
    pin(shadeView.top, to: view.top)
    pin(shadeView.bottom, to: view.bottom)
    pin(shadeView.left, to: view.left)
    pin(shadeView.right, to: view.right)
    topConstraint.isActive = false
//    horizontalnvariableConstraints = [
//      pin(sliderView.left, to: view.left, dist: sidePadding, priority: .fittingSizeLevel),
//      pin(sliderView.right, to: view.right, dist: -sidePadding)]
  }
  
  public var bottomOffset: CGFloat = 0
    
  override func resetVerticalConstraints() {
    print(">>> view size on resetConstra: \(slider.view.frame.size)")
    print(">>> sliderView size on resetConstra: \(sliderView.frame.size)")
    heightConstraint.constant = slider.view.frame.size.height
    heightConstraint.isActive = true
    if isOpen {
      bottomConstraint.constant = -bottomOffset
    }
    else {
      bottomConstraint.constant = coverage
    }
    bottomConstraint.isActive = true
    
    shadeView.alpha = 1 // important for touch events!
    shadeView.backgroundColor = .clear // invisible
    shadeView.isUserInteractionEnabled = true //but touchable
    
    active.view.layoutIfNeeded()
  }
  
  public init(slider: UIViewController, into active: UIViewController, maxWidth:CGFloat?=nil, sidePadding: CGFloat = 10.0) {
    super.init(slider: slider, into: active, fromBottom: true)
    self.sidePadding = sidePadding
    if let maxWidth = maxWidth, let view = active.view {
      for constraint in horizontalnvariableConstraints ?? [] {
        constraint.isActive = false
      }
      horizontalnvariableConstraints = [
        pin(sliderView.left, to: view.left, dist: sidePadding, priority: .defaultHigh),
        pin(sliderView.right, to: view.right, dist: -sidePadding, priority: .required)]
      
      leadingConstraint.constant = sidePadding
      trailingConstraint.constant = -sidePadding
      
      
      sliderView.pinWidth(maxWidth-2*sidePadding, relation: .lessThanOrEqual, priority: .required)
    }
  }
}

extension CACornerMask {
    static let allCorners: CACornerMask = [
        .layerMinXMinYCorner,
        .layerMaxXMinYCorner,
        .layerMinXMaxYCorner,
        .layerMaxXMaxYCorner
    ]
}
