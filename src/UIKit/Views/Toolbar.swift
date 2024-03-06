//
//  Toolbar.swift
//
//  Created by Norbert Thies on 20.07.16.
//  Copyright © 2016 Norbert Thies. All rights reserved.
//
//  This file implements a UIToolbar subclass named Toolbar.
//

import UIKit


/**
  A Toolbar is a UIToolbar subclass managing an array of subtoolbars.
  Each subtoolbar consists of a left, center and right section:
    toolbar:
      left section  <->  center section  <->  right section
  Each section in turn is an array of ButtonControl's. 
  By default one subtoolbar is created upon init. To create additional
  subtoolbars either use the method 'createBars' or add a ButtonControl
  via 'addButton' to a non existing toolbar.
 
  The following properties are available:
    * bar: Int (0)<br/>
      controls which subtoolbar is to display.
    * translucentColor: UIColor (black)<br/>
      defines the color of the translucent background view
    * translucentAlpha: CGFloat (0.1)<br/>
      defines the alpha of the translucent background view
*/

@IBDesignable
open class Toolbar: UIToolbar {
  public static let ContentToolbarHeight: CGFloat = 52
  class TButtons {
  
    var left:   Array<ButtonControl> = []
    var center: Array<ButtonControl> = []
    var right:  Array<ButtonControl> = []
    
    func buttonItems() -> Array<UIBarButtonItem> {
      var ret: Array<UIBarButtonItem> = []
      for b in left {
        ret.append(b.barButton())
      }
      ret.append(Toolbar.space())
      if center.count > 0 {
        for b in center {
          ret.append(b.barButton())
      } }
      ret.append(Toolbar.space())
      if right.count > 0 {
        for b in right {
          ret.append(b.barButton())
      } }
      return ret
    }
    
  } // class Toolbar.TButtons
  
  public class Spacer: ButtonControl {
    public override func barButton() -> UIBarButtonItem {
      return Toolbar.space()
    }
    public init() {
      super.init(view: ButtonView(), frame: CGRect())
    }    
    required public init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
  }
  
  fileprivate var bars = [ TButtons() ]
  
  fileprivate var _bar = 0

  /// number of the bar to display
  open var bar: Int {
    get { return _bar }
    set {
      if (newValue < bars.count) && (newValue != _bar) {
        _bar = newValue;
        items = nil
        items = bars[_bar].buttonItems()
  } } }
  
  /// color of translucent background
  @IBInspectable
  open var translucentColor: UIColor = UIColor.black { didSet { setNeedsDisplay() } }
  
  /// alpha of translucent background
  @IBInspectable
  open var translucentAlpha: CGFloat = 0.1 { didSet { setNeedsDisplay() } }
  
  /// perform closure on all buttons
  open func doButtons( _ closure: (ButtonControl)->() ) {
    for b in bars {
      for bt in b.left {
        closure(bt)
      }
      for bt in b.center {
        closure(bt)
      }
      for bt in b.right {
        closure(bt)
      }
  } }
  
  func isActiveButton(btn: UIView) -> Bool {
    for itm in bars[_bar].buttonItems() {
      if itm.customView == btn { return btn.isVisible }
    }
    return false
  }
  
  /// set color of buttons
  open func setButtonColor( _ color: UIColor ) {
    doButtons { (b: ButtonControl) in b.color = color }
  }

  /// set active color of buttons
  open func setActiveButtonColor( _ color: UIColor ) {
    doButtons { (b: ButtonControl) in b.activeColor = color }
  }
  
  /// create the given number of bars
  open func createBars( _ n: Int ) {
    if n > bars.count {
      for _ in bars.count..<n { bars.append( TButtons() ) }
    }
  }
  
  /// section to use for adding a button
  public enum Direction { case left; case center; case right }
  
  /// adds a button to a subtoolbar
  open func addButton( _ button: ButtonControl, direction: Direction, at: Int ) {
    createBars( at+1 )
    switch direction {
      case .left:   bars[at].left.append(button)
      case .center: bars[at].center.append(button)
      case .right:  bars[at].right.append(button)
    }
  }
  
  /// adds a button to all subtoolbars
  open func addButton( _ button: ButtonControl, direction: Direction ) {
    let n = bars.count
    for i in 0..<n {
      addButton(button, direction: direction, at: i)
  } }
  
  fileprivate var translucentBackground = UIView()

  open func setup() {
    contentMode = .redraw
    backgroundColor = UIColor.clear
    setBackgroundImage(UIImage(), forToolbarPosition: UIBarPosition.any,
      barMetrics: UIBarMetrics.default)
    setShadowImage(UIImage(), forToolbarPosition: UIBarPosition.any)
    addSubview(translucentBackground)
    translucentBackground.translatesAutoresizingMaskIntoConstraints = false
    translucentBackground.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
    translucentBackground.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
    translucentBackground.topAnchor.constraint(equalTo: topAnchor).isActive = true
    translucentBackground.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
  }

  override open func draw(_ rect: CGRect) {
    translucentBackground.backgroundColor = translucentColor
    translucentBackground.alpha = translucentAlpha
    if items == nil { items = bars[_bar].buttonItems() }
    super.draw(rect)
  }

  override public init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }
  
  convenience public init() { self.init(frame:CGRect(x: 0, y: 0, width: 0, height: 0)) }
  
  /// Returns a flexible space to put into Toolbars
  public class func space() -> UIBarButtonItem {
    return UIBarButtonItem( barButtonSystemItem: .flexibleSpace,
      target: nil, action: nil)
  }
  
  /// places the Toolbar via autolayout either to the top or to the bottom
  /// of the given view.
  open func placeInView( _ view: UIView, isTop: Bool = true ) {
    view.addSubview(self)
    translatesAutoresizingMaskIntoConstraints = false
    leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
    trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    if isTop {
      topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    }
    else {
      bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
  }

  /// places the Toolbar via autolayout either to the top or to the bottom
  /// of the given view controllers layout guides.
  open func placeInViewController( _ vc: UIViewController, isTop: Bool = true ) {
    vc.view.addSubview(self)
    translatesAutoresizingMaskIntoConstraints = false
    leadingAnchor.constraint(equalTo: vc.view.leadingAnchor).isActive = true
    trailingAnchor.constraint(equalTo: vc.view.trailingAnchor).isActive = true
    if isTop {
      topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor).isActive = true
    }
    else {
      bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
    }
  }
  
} // class Toolbar
