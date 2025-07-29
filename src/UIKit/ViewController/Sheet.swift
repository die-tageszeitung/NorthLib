//
//  Sheet.swift
//  NorthLib
//
//  Created by Ringo Müller on 29.07.25.
//

import UIKit

open class Sheet: VerticalSheet {
  
//  let ptView =  PassthroughView()
//  
//  public override var shadeView: UIView {
//    return ptView
//  }
  
  public var xButton = Button<ImageView>()
  
  open var maxOverlayWidth: CGFloat = UIScreen.main.bounds.width * 0.8
  open var sidePadding: CGFloat = 10.0
  
  open var bgContentView : UIView { contentView }
  
  override func decorateSlider(_ isDecorate: Bool) {
    sliderView.pinWidth(375, relation: .lessThanOrEqual, priority: .required)
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
    horizontalnvariableConstraints = [
      pin(sliderView.left, to: view.left, dist: sidePadding, priority: .fittingSizeLevel),
      pin(sliderView.right, to: view.right, dist: -sidePadding)]
    
  }
  
  public var bottomOffset: CGFloat = 0
  
  override func resetVerticalConstraints() {
    heightConstraint.constant = slider.view.bounds.size.height
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
}

extension CACornerMask {
    static let allCorners: CACornerMask = [
        .layerMinXMinYCorner,
        .layerMaxXMinYCorner,
        .layerMinXMaxYCorner,
        .layerMaxXMaxYCorner
    ]
}
