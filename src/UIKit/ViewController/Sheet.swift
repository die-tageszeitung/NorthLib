//
//  Sheet.swift
//  NorthLib
//
//  Created by Ringo Müller on 29.07.25.
//

import UIKit

/**
A sliding sheet component (`Sheet`) presented within a view hierarchy.

The `sliderView` is initialized in the parent class and serves as the top-level container.

The sheet’s main view (`slider.view`) is inserted into a target view controller via:

    Sheet(slider: self, into: targetVc)

For example, `self` may be the `ContinueReadingController.view`.

The sheet is shown using:

    slide(toOpen: Bool, animated: Bool = true)

When `!isOpen`, the following logic applies:
- `active.presentSubVC(controller: slider, inView: contentView)` is called.
- This results in:
    - `contentView.addSubview(slider.view)`
    - `slider.view.frame = contentView.bounds`

Important:
- `contentView` must already have the correct size at this point!
- `slider.view` does not have layout or size of its own — it depends entirely on its container.

View Hierarchy:
    contentView.addSubview(slider.view)
    sliderView.addSubview(contentView)
    active.view.addSubview(sliderView)

Layout Constraints (set in `decorateSlider`):
- Horizontal:
    - contentView.left → sliderView.left
    - contentView.right → sliderView.right
- Vertical:
    - contentView.top → sliderView.top + decorationHeight
    - contentView.bottom → sliderView.bottom (priority: .fittingSizeLevel)

These constraints ensure the sheet fills the `sliderView`, minus the decorated top space.
*/
open class Sheet: VerticalSheet {
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
    topConstraint.isActive = false
  }
  
  public var bottomOffset: CGFloat = 0
    
  override func resetVerticalConstraints() {
    heightConstraint.constant = slider.view.frame.size.height
    heightConstraint.isActive = true
    if isOpen {
      bottomConstraint.constant = -bottomOffset
    }
    else {
      bottomConstraint.constant = coverage
    }
    bottomConstraint.isActive = true
    active.view.layoutIfNeeded()
  }
  
  public init(slider: UIViewController, into active: UIViewController, maxWidth:CGFloat?=nil, sidePadding: CGFloat = 10.0) {
    super.init(slider: slider, into: active, fromBottom: true)
    self.sidePadding = sidePadding
    if let maxWidth = maxWidth, let view = active.view {
      horizontalnvariableConstraints = [
        pin(sliderView.left, to: view.left, dist: sidePadding, priority: .defaultHigh),
        pin(sliderView.right, to: view.right, dist: -sidePadding, priority: .required)]
      sliderView.pinWidth(maxWidth, relation: .lessThanOrEqual, priority: .required)
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
