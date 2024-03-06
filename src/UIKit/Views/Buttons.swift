//
//  Buttons.swift
//
//  Created by Norbert Thies on 20.07.16.
//  Copyright © 2016 Norbert Thies. All rights reserved.
//
//  This file implements some views and classes used to provide UI buttons.
//

import UIKit

// MARK: Abstract and generic classes

/**
  Base class of views used in buttons
 
  A ButtonView is an abstract UIView subclass that is used by derived classes to
  define some common properties. Button views are expected to have two states,
  an activated state (when the button has been pressed) and an inactive state
  (which is the default state, button not pressed). 
  The following common properties are supported:
 
  * color (tintColor)  
    the color used to draw the button in inactive state
  * activeColor (green)  
    the color used to draw the button in active state
  * lineWidth (0.04)  
    the width of stroked lines if the button is drawn out of lines, the
    lineWidth is a factor to the width of the view.
  * isActivated (false)  
    specifies whether to show the button in activated or inactive mode.
  * hinset (0)  
    horizontal distance from the edge of the view to the drawing (as a factor
    to the views width).
  * vinset (0)  
    vertical distance from the edge of the view to the drawing (as a factor
    to the views height).
  * inset  
    if set, it will set hinset and vinset alike. If requested it will
    return max(hinset, vinset).
 
  All ButtonViews use a clear background color.
*/
// MARK: - ButtonView
open class ButtonView: UIView {

  /// Main color used in drawing the button in inactive state (tintColor by default)
  @IBInspectable
  open var color: UIColor = UIColor.black { didSet { setNeedsDisplay() } }
  
  /// Color used in drawing the button in active state (button pressed, isActivated==true)
  @IBInspectable
  open var activeColor: UIColor = UIColor.green { didSet { setNeedsDisplay() } }
  
  /// Background Color used in drawing the button in active state (button pressed, isActivated==true)
  //Active Background Color deactivated for the Moment due missing unclear Color Values
  open var activeBackgroundColor: UIColor? = nil { didSet { setNeedsDisplay() } }

  // The color used for stroking lines
  open var strokeColor: UIColor { return isActivated ? activeColor : color }
  
  /// The line width used for drawings as factor to the width of the view
  @IBInspectable
  open var lineWidth: CGFloat = 0.04 { didSet { setNeedsDisplay() } }

  /// Will be set to true if the button is pressed
  open var isActivated: Bool = false { didSet { setNeedsDisplay() } }
  
  /// Horizontal inset
  @IBInspectable
  open var hinset: CGFloat = 0 { didSet { setNeedsDisplay() } }
  
  /// Vertical inset
  @IBInspectable
  open var vinset: CGFloat = 0 { didSet { setNeedsDisplay() } }
  
  /// max(hinset, vinset)
  @IBInspectable
  open var inset: CGFloat {
    get { return max(hinset, vinset) }
    set { hinset = newValue; vinset = newValue }
  }
  
  public var isHiddenInToolbar: Bool {
    get {
      var sv: UIView? = self.superview
      guard let btnImgView = self.superview else { return true }
      while true {
        if sv == nil { return true }
        if let tb = sv as? Toolbar {
          return !tb.isActiveButton(btn: btnImgView)
        }
        sv = sv?.superview
      }
    }
  }
  
  fileprivate func setup() {
    contentMode = .redraw
    color = tintColor
    super.backgroundColor = UIColor.clear
    translatesAutoresizingMaskIntoConstraints = false
  }
  
  override public init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }
  
  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    setup()
  }
  
  private var bgColor:UIColor? = UIColor.clear
  open override var backgroundColor: UIColor? {
    get{return bgColor}
    set{bgColor=newValue}
  }
  
  override open func draw(_ rect: CGRect) {
    super.draw(rect)
    self.layer.backgroundColor
      = isActivated
      ? (self.activeBackgroundColor ?? self.backgroundColor ?? UIColor.clear).cgColor
      : (self.backgroundColor ?? UIColor.clear).cgColor
  }

} // class ButtonView

/**
  A FilpFlopView is an abstract ButtonView that offers two different icon drawings.
 
  One drawing is the primary and the other the secondary icon. Depending on the
  property isBistable the icons are switched when the button is activated.
  
  * isBistable (true)  
    if true the icons are switched when the button is pressed (ie. activated)
  * isPrimary (true)  
    if true the primary icon is drawn in inactive state and the secondary is drawn
    when the button is pressed (active state). If false it's vice versa.
  */
// MARK: - FlipFlopView
open class FlipFlopView: ButtonView {

  /// Whether to use bistable mode
  @IBInspectable
  open var isBistable: Bool = true { didSet { setNeedsDisplay() } }
  
  /// Whether the primary icon is drawn in inactive state
  @IBInspectable
  open var isPrimary: Bool = true { didSet { setNeedsDisplay() } }
  
  // draw primary icon?
  open var isDrawPrimary: Bool {
    if isBistable { return isPrimary != isActivated }
    else { return isPrimary }
  }
  
  // the color used for drawing
  override open var strokeColor: UIColor
    { return isBistable ? color : super.strokeColor }

} // class FliFlopView

/** 
  A FlipFlop is a generic FlipFlopView consisting of two ButtonView's.
 
  By default (in non activated state) only the primary ButtonView is displayed. In activated
  state the primary view is hidden and the secondary view is displayed (i.e. unhidden).
*/
// MARK: - FlipFlop<Primary, Secondary>:
@IBDesignable
open class FlipFlop<Primary:ButtonView, Secondary:ButtonView>: FlipFlopView {

  /// Primary view
  open var primary: Primary
  
  /// Secondary view
  open var secondary: Secondary
  
  override open var color: UIColor
    { didSet { primary.color = color; secondary.color = color } }
  override open var lineWidth: CGFloat
    { didSet { primary.lineWidth = lineWidth; secondary.lineWidth = lineWidth } }
  override open var hinset: CGFloat
    { didSet { primary.hinset = hinset; secondary.hinset = hinset } }
  override open var vinset: CGFloat
    { didSet { primary.vinset = vinset; secondary.vinset = vinset } }

  override open func setup() {
    super.setup()
    primary.frame = bounds
    secondary.frame = bounds
    addSubview(primary)
    addSubview(secondary)
    secondary.isHidden = true
  }
  
  override public init(frame: CGRect) {
    primary = Primary()
    secondary = Secondary()
    super.init(frame: frame)
  }
  
  required public init?(coder aDecoder: NSCoder) {
    primary = Primary()
    secondary = Secondary()
    super.init(coder: aDecoder)
  }
  
  override open func draw(_ rect: CGRect) {
    primary.frame = bounds
    primary.isHidden = !isDrawPrimary
    secondary.frame = bounds
    secondary.isHidden = isDrawPrimary
  }
  
  override open func layoutSubviews() {
    primary.frame = bounds
    secondary.frame = bounds
    super.layoutSubviews()
  }

} // class FlipFlop


/**
  UIControl subclass as base class for various buttons
 
  A ButtonControl is an abstract UIControl subclass intended as common base 
  class for various button UI controls. When the control is touched and released 
  inside its view, all target actions for *.TouchUpInside* are activated.
 
  A closure may be defined that is called when the button is pressed:
  ````
  buttonControl.onPress { (bctl: ButtonControl) in
    print("button pressed")
  }
  ````
 
  ButtonControls are based on a ButtonView to draw the button. Like FlipFlopView,
  it offers the methods 'isPrimary' and 'isBistable'. If the underlying ButtonView
  is a FlipFlopView these methods are relayed to the view. If not, 'isPrimary' returns
  true and 'isBistable' false.
 */
// MARK: - ButtonControl
@IBDesignable
open class ButtonControl: UIControl {

  /// the ButtonView used to draw the button
  var view: ButtonView?
  
  // propagate size changes to underlying view
  override open var frame: CGRect {
    didSet { view?.frame = CGRect(origin:CGPoint(x:0,y:0), size:self.bounds.size) }
  }

  // propagate size changes to underlying view  
  override open var bounds: CGRect {
    didSet { view?.bounds = CGRect(origin:CGPoint(x:0,y:0), size:self.bounds.size) }
  }
  
  /// Whether to show the primary or the secondary icon
  @IBInspectable
  open var isPrimary: Bool {
    get {
      if let v = view as? FlipFlopView { return v.isPrimary }
      else { return true }
    }
    set {
      if let v = view as? FlipFlopView { v.isPrimary = newValue }
    }
  }
  
  /// Will in active mode the icon switch from primary to secondary icon?
  @IBInspectable
  open var isBistable: Bool {
    get {
      if let v = view as? FlipFlopView { return v.isBistable }
      else { return false }
    }
    set {
      if let v = view as? FlipFlopView { v.isBistable = newValue }
    }
  }
  
  /// Main color used in drawing the button
  @IBInspectable
  open var color: UIColor {
    get { return view!.color }
    set { view?.color = newValue }
  }
  
  /// Color used in drawing the button if isActivated
  @IBInspectable
  open var activeColor: UIColor {
    get { return view!.activeColor }
    set { view?.activeColor = newValue }
  }

  /// The line width used for drawings as factor to the width of the view
  @IBInspectable
  open var lineWidth: CGFloat {
    get { return view!.lineWidth }
    set { view?.lineWidth = newValue }
  }

  /// Horizontal inset
  @IBInspectable
  open var hinset: CGFloat {
    get { return view!.hinset }
    set { view?.hinset = newValue }
  }
  
  /// Vertical inset
  @IBInspectable
  open var vinset: CGFloat {
    get { return view!.vinset }
    set { view?.vinset = newValue }
  }
  
  /// max(hinset, vinset)
  @IBInspectable
  open var inset: CGFloat {
    get { return view!.inset }
    set { view?.inset = newValue }
  }
  
//  fileprivate var longPressRecognizer: UILongPressGestureRecognizer?
//  /// Closure will be called if the button has been pressed and is released
//  fileprivate var longPressClosure: ((ButtonControl)->())? = nil {
//    didSet {
//
//      longPressRecognizer?.isEnabled = longPressClosure != nil
//      guard longPressRecognizer == nil,
//            longPressClosure != nil else { return }
//      let lgr
//      = UILongPressGestureRecognizer(target: self,
//                                     action: #selector(handleLongTap(sender:)))
//      self.addGestureRecognizer(lgr)
//      longPressRecognizer = lgr
//    }
//  }
//  
//  @objc fileprivate func handleLongTap(sender: UILongPressGestureRecognizer) {
//    guard sender.state == .began else { return }
//    longPressClosure?(self)
//  }
//  
//  /// define the closure to call when the button has been pressed
//  open func onLongPress(closure: @escaping (ButtonControl)->()) { longPressClosure = closure }
  
  /// Closure will be called if the button has been pressed and is released
  fileprivate var onPressClosure: ((ButtonControl)->())? = nil
  
  /// define the closure to call when the button has been pressed
  open func onPress(closure: @escaping (ButtonControl)->()) { onPressClosure = closure }
  
  override open func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
    view?.isActivated = true
    return super.beginTracking(touch, with:event)
  }
  
  override open func endTracking(_ touch: UITouch?, with event: UIEvent?) {
    view?.isActivated = false
    super.endTracking( touch, with: event )
  }
  
  override open func cancelTracking(with event: UIEvent?) {
    view?.isActivated = false
    super.cancelTracking( with: event )
  }
  
  @objc fileprivate func buttonPressed() {
    if let closure = onPressClosure {
      closure(self)
    }
  }
  
  @objc fileprivate func touchDown() {
    log("touchDown \(Date().ddMMyy_HHmmss)")
  }
  @objc fileprivate func touchCancel() {
    log("touchCancel \(Date().ddMMyy_HHmmss)")
  }
  @objc fileprivate func touchDownRepeat() {
    log("touchDownRepeat \(Date().ddMMyy_HHmmss)")
  }
  @objc fileprivate func touchUpOutside() {
    log("touchUpOutside \(Date().ddMMyy_HHmmss)")
  }
  @objc fileprivate func touchDragOutside() {
    log("touchDragOutside \(Date().ddMMyy_HHmmss)")
  }
  
  @objc fileprivate func allEvents(sender:Any) {
    log("touchallEvents \(Date().ddMMyy_HHmmss) sender: \(sender)")
  }
  
  
  open func setup() {
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = UIColor.clear
    view?.frame = bounds
    view?.isUserInteractionEnabled = false
    addSubview(view!)
    pin(view!, to: self)
    addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    addTarget(self, action: #selector(self.touchDown), for: .touchDown)
    addTarget(self, action: #selector(self.touchCancel), for: .touchCancel)
    addTarget(self, action: #selector(self.touchDownRepeat), for: .touchDownRepeat)
    addTarget(self, action: #selector(self.touchUpOutside), for: .touchUpOutside)
    addTarget(self, action: #selector(self.touchDragOutside), for: .touchDragOutside)
//    addTarget(self, action: #selector(self.allEvents), for: .allEvents)
  }
  
  /// Initialize with ButtonView and frame
  public init(view: ButtonView, frame: CGRect) {
    self.view = view
    super.init(frame: frame)
    setup()
  }
  
  /// Initialize with ButtonView and width and optional height (same as width by default)
  public convenience init(view: ButtonView, width: CGFloat, height: CGFloat? = nil) {
    var h = width
    if height != nil { h = height! }
    self.init( view: view, frame: CGRect(x: 0, y: 0, width: width, height: h) )
  }
  
  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
 
  /// Returns a UIBarButtonItem which custom view is set to self
  open func barButton() -> UIBarButtonItem {
    let bb = UIBarButtonItem()
    bb.customView = self
    return bb
  }
  
  override open func layoutSubviews() {
    let orig = frame.origin
    bounds.size = view!.bounds.size
    frame.origin = orig
  }
  
}  // class ButtonControl


/**
  A Button is the generic version of a ButtonControl
 
  Let BView be an arbitrary ButtonView subclass, then
  ````
  let b = Button<BView>()
  ````
  creates a Button aka ButtonControl `b`
  based on the BView ButtonView subclass.
 */
// MARK: - Button<View: ButtonView>
open class Button<View: ButtonView>: ButtonControl {  
  open var buttonView: View { return super.view as! View }
  public init( frame: CGRect ) { super.init( view: View(), frame: frame ) }
  public convenience init( width: CGFloat = 30, height: CGFloat = 30 ) {
    self.init( frame: CGRect(x: 0, y: 0, width: width, height: height) )
  }
  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    fatal("init(coder:) has not been implemented")
  }  
} // Button<View>


/**
  ButtonControl subclass as base class for various switches
 
  A SwitchControl is a ButtonControl subclass intended as common base class
  for various switch UI controls. When the control is touched, the property *on*
  (which is initially set to false) is set to its inverse value and all target
  actions for *.ValueChanged* are activated. Unlike a ButtonControl a SwitchControl
  emulates the behaviour of a switch, ie. pressing a SwitchControl toggles the state
  until the switch is pressed a second time.

  A closure may be defined that is called when the switch is pressed:
  ````
  switchControl.onChange { (sctl: SwitchControl) in
    if sctl.on { print("on") }
    else { print("off") }
  }
  ````
*/
// MARK: - SwitchControl
@IBDesignable
open class SwitchControl: ButtonControl {

  /// Defines the state of the switch (initially false)
  @IBInspectable
  open var on: Bool = false {
    didSet {
      if on { view?.isActivated = true }
      else { view?.isActivated = false }
  } }
  
  /// Closure will be called if the state changes
  open var onChangeClosure: ((SwitchControl)->())? = nil
  
  /// defines closure to call when the switch changes state
  open func onChange(closure: @escaping (SwitchControl)->()) { onChangeClosure = closure }
  
  override open func endTracking(_ touch: UITouch?, with event: UIEvent?) {
    super.endTracking( touch, with: event )
    if isTouchInside {
      on = !on
      sendActions( for: .valueChanged )
      if let closure = onChangeClosure {
        closure(self)
      }
    }
    else { cancelTracking(with: event) }
  }
  
} // class SwitchControl


/**
 A Switch is the generic version of a SwitchControl
 
 Let BView be an arbitrary ButtonView subclass, then
 ````
 let s = Switch<BView>()
 ````
 creates a Switch aka SwitchControl `s`
 based on the BView ButtonView subclass.

*/
// MARK: - Switch<View: ButtonView>: SwitchControl
open class Switch<View: ButtonView>: SwitchControl {
  open var buttonView: View { return super.view as! View }
  public init( frame: CGRect ) { super.init( view: View(), frame: frame ) }
  public convenience init( width: CGFloat = 30, height: CGFloat = 30 ) {
    self.init( frame: CGRect(x: 0, y: 0, width: width, height: height) )
  }
  required public init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    fatal("init(coder:) has not been implemented")
  }
} // Switch<View>

// MARK: - Concrete ButtonViews and FlipFlopViews

/**
  FlipFlopView displaying a plus or minus sign
 
  A PlusView is a FlipFlopView subclass showing a plus sign as its primary
  icon and a minus sign as secondary icon.
*/
// MARK: - PlusView
@IBDesignable
open class PlusView: FlipFlopView {
  
  override open func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height, m = min(w,h),
        l = m * (1 - inset)
    let path = UIBezierPath()
    let a = CGPoint(x:(w-l)/2, y:h/2),
        b = CGPoint(x:a.x+l, y:a.y),
        c = CGPoint(x:w/2, y:(h-l)/2),
        d = CGPoint(x:c.x, y:c.y+l)
    path.move(to: a)
    path.addLine(to: b)
    if ( isDrawPrimary ) {
      path.move(to: c)
      path.addLine(to: d)
    }
    path.lineWidth = lineWidth * bounds.size.width
    strokeColor.setStroke()
    path.stroke()
  }
  
} // class PlusView


/**
  The MinusView is a convenience class derived from
  PlusView to draw a minus as its primary icon.
*/

open class MinusView: PlusView {
  override open func setup() {
    super.setup()
    isPrimary = false
  }
}

/**
  FlipFlopView displaying a left or right arrow
 
  A ArrowView is a FlipFlopView subclass showing a left arrow as its primary
  icon and a right arrow as secondary icon.
*/
// MARK: - ArrowView
@IBDesignable
open class ArrowView: FlipFlopView {
  
  open func drawArrow() {
    let isLeft = isDrawPrimary
    let h = bounds.size.height, w = bounds.size.width,
    hi = w*(hinset/2), vi = h*(vinset/2),
    d = h/2 - vi,
    lw = lineWidth * h
    let arrow = UIBezierPath()
    var pu: CGPoint, pm: CGPoint, pl: CGPoint
    if isLeft {
      pu = CGPoint(x:hi+d+lw, y:vi)
      pm = CGPoint(x:hi+lw, y:h/2)
      pl = CGPoint(x:pu.x, y:h-vi)
    }
    else {
      pu = CGPoint(x:w-hi-d-lw, y:vi)
      pm = CGPoint(x:w-hi-lw, y:h/2)
      pl = CGPoint(x:pu.x, y:h-vi)       
    }
    arrow.move(to: pu)
    arrow.addLine(to: pm)
    arrow.addLine(to: pl)
    arrow.lineJoinStyle = .miter
    arrow.lineWidth = lw
    strokeColor.setStroke()
    arrow.stroke()
  }
  
  override open func draw(_ rect: CGRect) { drawArrow() }
  
} // class ArrowView

public typealias LeftArrowView = ArrowView

/**
  The RightArrowView is a convenience class derived from
  ArrowView to draw a right arrow as its primary icon.
*/
open class RightArrowView: ArrowView {
  override open func setup() {
    super.setup()
    isPrimary = false
  }
}


/**
  A FlipFlopView subclass offering a rotating triangle.
 
  A RotatingTriangleView is a FlipFlopView subclass containing a triangle filled
  with a certain color that can be rotated using an animation.
  Important:  In fact not the triangle but the complete view is rotated
  according to the property *angle*.
  As primary icon the triangle's tip is pointing east. The secondary icon
  is the same icon rotated animated by 90 degrees pointing south.
  This view is controlled by the following properties:
  * angle (0)<br/>
    Defines the rotation's angle in degrees (no animation)
  * animatedAngle (0)<br/>
    Defines the rotation's angle (in degrees) and triggers the rotation animation
  * color (tintColor)<br/>
    The color used to fill the triangle
  * duration (0.2)<br/>
    The number of seconds the animation will last
    
  In active mode the angle is set to 90 degrees. An "active" color is not used.
*/
// MARK: - RotatingTriangleView
@IBDesignable
open class RotatingTriangleView: FlipFlopView {

  fileprivate var _angle: Double = 0  // the real angle

  /// The angle (in degrees) by which the view is rotated
  @IBInspectable
  open var angle:Double { // in degrees
    get { return _angle }
    set { rotate(newValue) }
  }
  
  /// The angle (in degrees) by which the view is rotated with animation
  open var animatedAngle: Double {
    get { return _angle }
    set { rotate(newValue, isAnimated: true) }
  }
  
  override open var isActivated: Bool
    { didSet { animatedAngle = isDrawPrimary ? 0 : 90 } }
  override open var isPrimary: Bool
    { didSet { angle = isPrimary ? 0 : 90 } }
  
  /// The duration of the animated rotation in seconds (0.2)
  @IBInspectable
  open var duration:Double = 0.2

  fileprivate func radians() -> CGFloat {
    return CGFloat( (angle/180) * Double.pi )
  }
  
  fileprivate func rotate(_ to:Double, isAnimated:Bool = false) -> Void {
    if ( to != _angle ) {
      _angle = to
      if ( isAnimated ) {
        UIView.animate(withDuration: duration, animations: {
          self.transform = CGAffineTransform(rotationAngle: self.radians())
      })  }
      else { self.transform = CGAffineTransform(rotationAngle: self.radians()) }
  } }

  override open func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height, m = min(w,h),
        l = m * (1 - inset)
    let triangle = UIBezierPath()
    let a = CGPoint(x:(w-l)/2, y:(h-l)/2),
        b = CGPoint(x:a.x+l, y:h/2),
        c = CGPoint(x:a.x, y:h-(h-l)/2)
    triangle.move(to: a)
    triangle.addLine(to: b)
    triangle.addLine(to: c)
    triangle.close()
    strokeColor.setFill()
    triangle.fill()
    transform = CGAffineTransform(rotationAngle: radians())
  }
  
} // class RotatingTriangleView


/**
  FlipFlopView displaying a selection icon
 
  A SelectionView is a FlipFlopView subclass showing a *V* inside a circle (indicating
  some kind of selection). This is the primary icon, if isPrimary==false, then the 
  primary icon is shown "crossed out" (indicating deselection).
*/
// MARK: - SelectionView
@IBDesignable
open class SelectionView: FlipFlopView {
  
  override open func setup() {
    super.setup()
    color = Param.innerColor
  }
  
  // ro = outer radius, ri = inner radius
  fileprivate struct Param {
    static let xRadius:CGFloat = 0.48       // of min(width,height)
    static let xInnerCircle:CGFloat = 0.8   // of ro
    static let x1:CGFloat = 2.0             // of ro-ri
    static let y1:CGFloat = 1.2             // of ro
    static let x2:CGFloat = 1.0             // of ro
    static let y2:CGFloat = 1.35            // of ro
    static let x3:CGFloat = 1.44            // of ro
    static let y3:CGFloat = 0.55            // of ro
    static let outerColor     = UIColor.rgb(0xffffff)
    static let innerColor     = UIColor.rgb(0xff0000)
    static let activeColor    = UIColor.rgb(0x00ff00)
    static let lineColor      = UIColor.rgb(0xffffff)
    static let crossLineColor = UIColor.rgb(0x000000)
    static let crossLineWidth:CGFloat = 0.4      // of ro-ri
    static let shadowBlur:CGFloat = 3.0
    static let bendLeft:CGFloat = -0.1
    static let bendRight:CGFloat = -0.1
  }
  
  override open func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height, s = min(h, w)*(1-inset)
    let ro = s * Param.xRadius, ri = ro * Param.xInnerCircle
    let center = convert(self.center, from: self.superview)
    let offset = CGPoint( x: (w-s)/2, y: (h-s)/2 ) + (s/2-ro)
    let p1 = CGPoint( x:(ro-ri)*Param.x1, y:ro*Param.y1 ) + offset,
        p2 = CGPoint( x:Param.x2, y:Param.y2 ) * ro + offset,
        p3 = CGPoint( x:Param.x3, y:Param.y3 ) * ro + offset
    let path = UIBezierPath()
    path.circle(center, radius: ro)
    Param.outerColor.setFill()
    path.fillWithShade( Param.shadowBlur )
    path.removeAllPoints()
    path.circle(center, radius: ri)
    //if isActivated { Param.activeColor.setFill() } else { color.setFill() }
    strokeColor.setFill()
    path.fill()
    path.removeAllPoints()
    path.lineWidth = (lineWidth + 0.04) * w
    path.lineJoinStyle = .miter
    path.curve(p1, to: p2, bending: Param.bendLeft)
    path.addCurve(p3, bending: Param.bendRight)
    Param.lineColor.setStroke()
    //path.strokeWithShade( Param.shadowBlur )
    path.stroke()
    if !isDrawPrimary {
      var p = offset
      path.removeAllPoints()
      path.move(to: p)
      p = p + (2*ro, 2*ro)
      path.addLine(to: p)
      p = offset + (0, 2*ro)
      path.move(to: p)
      p = offset + (2*ro, 0)
      path.addLine(to: p)
      path.lineWidth = Param.crossLineWidth * (ro-ri)
      Param.crossLineColor.setStroke()
      //path.strokeWithShade(Param.shadowBlur)
      path.stroke()
    }
  }

} // class SelectionView


/**
  ButtonView displaying a gear wheel (eg. pointing to settings dialogue)
 
  A GearWheelView is a ButtonView subclass showing a gear wheel
  using following properties:
  * diameter (0.9)<br/>
    the outer diameter of the wheel (as factor to min(width,height) of the view)
  * cogLength (0.3)<br/>
    the length of the gear wheel's cogs (as a factor to the radius)
  * cogWidth (1.0)<br/>
    the width of the cogs as a factor to the cog width at the inner
    wheel
  * thickness (0.35)<br/>
    the thickness of the inner wheel (as factor to the diameter)
  * nCogs (7)<br/>
    the number of cogs to draw
*/
// MARK: - GearWheelView
@IBDesignable
open class GearWheelView: ButtonView {

  /// outer diameter of the wheel
  @IBInspectable
  open var diameter: CGFloat = 0.9 { didSet { setNeedsDisplay() } }
  
  /// number of cogs
  @IBInspectable
  open var nCogs: Int = 7 { didSet { setNeedsDisplay() } }
  
  /// length of the gear wheel's cogs
  @IBInspectable
  open var cogLength: CGFloat = 0.3 { didSet { setNeedsDisplay() } }
  
  /// the width of the cogs
  @IBInspectable
  open var cogWidth: CGFloat = 1.0 { didSet { setNeedsDisplay() } }
  
  /// thickness of the inner wheel
  @IBInspectable
  open var thickness: CGFloat = 0.35 { didSet { setNeedsDisplay() } }
  
  /// whether to draw a round outer wheel
  @IBInspectable
  open var isRound: Bool = true { didSet { setNeedsDisplay() } }

  
  fileprivate var viewCenter: CGPoint { return convert(center, from: superview) }
  fileprivate var realDiameter: CGFloat {
    return min(bounds.size.width, bounds.size.height) * (1 - inset) * diameter
  }
  
  open func drawCog( _ path: UIBezierPath, _ n: Int ) {
    let c = viewCenter, d = realDiameter,
        ro = d / 2, ri = (d - d * cogLength) / 2,
        alpha = 2 * CGFloat.pi / CGFloat(nCogs),
        beta = alpha * ri * cogWidth / (2 * ro),
        gamma = (alpha/2 - beta) / 2,
        aStart = alpha * CGFloat(n), aHalf = aStart + alpha/2, aEnd = aStart + alpha,
        p1 = CGPoint(x:ri*sin(aStart), y:-ri*cos(aStart)) + c,
        p2 = CGPoint(x:ri*sin(aHalf), y:-ri*cos(aHalf)) + c,
        p3 = CGPoint(x:ro*sin(aHalf+gamma), y:-ro*cos(aHalf+gamma)) + c,
        p4 = CGPoint(x:ro*sin(aEnd-gamma), y:-ro*cos(aEnd-gamma)) + c,
        p5 = CGPoint(x:ri*sin(aEnd), y:-ri*cos(aEnd)) + c
    if n == 0 { path.move(to: p1) }
    if isRound {
      let a = aStart - CGFloat.pi/2,
          e = a + alpha/2
      path.addArc(withCenter: c, radius: ri, startAngle: a,
                            endAngle: e, clockwise: true)
    }
    else { path.addLine(to: p2) }
    path.addLine(to: p3)
    path.addLine(to: p4)
    path.addLine(to: p5)
  }
  
  override open func draw(_ rect: CGRect) {
    let path = UIBezierPath()
    path.lineJoinStyle = .miter
    for n in 0 ..< nCogs {
      drawCog( path, n )
    }
    path.close()
    let d = realDiameter, r = (d - d*(cogLength + thickness))/2
    var p = viewCenter
    p.x += r
    path.move(to: p)
    path.circle( viewCenter, radius: r, clockwise: true )
    path.usesEvenOddFillRule = true
    strokeColor.setFill()
    path.fill()
  }

} // class GearWheelView


/**
  FlipFlopView displaying a bookmark icon
 
  A BookmarkView is a FlipFlopView subclass modelling a bookmark that is either
  set (fills entire view) or unset (reduced height, fills partial view). The primary
  icon is the unset bookmark.
  This view is controlled by the following properties:
    * fillColor (0xf02020): color used to fill the icon with
    * isDrawLine (false): draw line around the icon
*/

// MARK: - BookmarkView
@IBDesignable
open class BookmarkView: FlipFlopView {

  /// Whether the bookmark is transparent
  @IBInspectable
  var isTransparent:Bool = true {
    didSet { setNeedsDisplay() }
  }
  
  /// The fill color
  @IBInspectable
  open var fillColor: UIColor = Param.color
  
  /// Whether to draw a line around the bookmark
  open var isDrawLine: Bool = false
    { didSet { if isDrawLine { isTransparent = false } else { isTransparent = true } } }
  
  override open func setup() {
    super.setup()
    hinset = 0.3
  }
  
  fileprivate struct Param {
    static let offHeight:CGFloat = 0.4 /// height factor if !isBookmark
    static let indent:CGFloat = 0.2   /// bookmark indentation relative to total height
    static let color:UIColor = UIColor.rgb(0xf02020) // bookmark color
    static let onAlpha:CGFloat = 0.7   /// view alpha value if isBookmark
    static let offAlpha:CGFloat = 0.3  /// view alpha value if !isBookmark
  }
  
  override open func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height, ainset = w * hinset/2,
        lw = lineWidth * w
    let bmark = UIBezierPath()
    let bh = isDrawPrimary ? h * Param.offHeight : h-lw/2,
        bhi = bh - h * Param.indent,
        indent = CGPoint(x:w/2, y:bhi)
    bmark.move( to: CGPoint(x:ainset, y:lw/2) )
    bmark.addLine( to: CGPoint(x:w-ainset, y:lw/2) )
    bmark.addLine( to: CGPoint(x:w-ainset, y:bh) )
    bmark.addLine( to: indent )
    bmark.addLine( to: CGPoint(x:ainset, y:bh) )
    bmark.close()
    bmark.lineWidth = lw
    fillColor.setFill()
    strokeColor.setStroke()
    if isDrawLine {
      bmark.stroke()
      bmark.fill()
    }
    else { bmark.fillWithShade(5.0) }
    if isTransparent {
      self.alpha = isDrawPrimary ? Param.offAlpha : Param.onAlpha
    }
    else {
      self.alpha = 1.0
    }
  }
  
  override open func layoutSubviews() {
    setNeedsDisplay()
  }
  
} // class BookmarkView


/**
  ButtonView displaying a page with dogear
 
  A PageView is a ButtonView subclass containing a stylized
  page.
  This view is controlled by the following properties:
  * dogearWidth (0.2)<br/>
    Width of page dogear as a factor to the view's width.
*/
// MARK: - PageView
@IBDesignable
open class PageView: ButtonView {

  /// The relative width of the dogear.
  @IBInspectable
  open var dogearWidth:Double = 0.3 { didSet { setNeedsDisplay() } }

  override open func setup() {
    super.setup()
    hinset = 0.15
  }
  
  override open func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height,
        lw = lineWidth * w,
        l = w * (1 - hinset) - 2*lw,
        dw = l * CGFloat(dogearWidth),
        hi = w * (hinset/2) + lw,
        vi = h * (vinset/2) + lw
    let a = CGPoint(x:hi, y:vi),
        b = CGPoint(x:a.x+l-dw, y:a.y),
        c = CGPoint(x:a.x+l, y:a.y+dw),
        d = CGPoint(x:a.x+l, y:h-vi),
        e = CGPoint(x:a.x, y:d.y),
        f = CGPoint(x:b.x, y:c.y)
    let page = UIBezierPath()
    page.move(to: a)
    page.addLine(to: b)
    page.addLine(to: c)
    page.addLine(to: d)
    page.addLine(to: e)
    page.addLine(to: a)
    page.move(to: b)
    page.addLine(to: f)
    page.addLine(to: c)
    page.lineWidth = lw
    strokeColor.setStroke()
    page.stroke()
  }
  
} // class PageView


/**
  ButtonView displaying three horizontal lines (a Hamburger Menu)
*/
// MARK: - MenuView
@IBDesignable
open class MenuView: ButtonView {

  override open func setup() {
    super.setup()
    hinset = 0.10
  }

  override open func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height,
        lw = (lineWidth+0.01) * w,
        l = w * (1 - 2*hinset),
        hi = w * (hinset/2) + lw,
        vi = h * (vinset/2+0.1) + lw
    let a = CGPoint(x:hi, y:vi),
        b = CGPoint(x:a.x, y:h/2),
        c = CGPoint(x:a.x, y:h - vi)
    let lines = UIBezierPath()
    lines.move(to: a)
    lines.addLine(to: CGPoint(x:a.x + l, y:a.y))
    lines.move(to: b)
    lines.addLine(to: CGPoint(x:b.x + l, y:b.y))
    lines.move(to: c)
    lines.addLine(to: CGPoint(x:c.x + l, y:c.y))
    lines.lineWidth = lw
    strokeColor.setStroke()
    lines.stroke()
  }
  
} // class MenuView

/// A MenuView may also be called HamburgerView
typealias HamburgerView = MenuView


/**
 ButtonView displaying five horizontal lines
 depicting a table of contents
 */

@IBDesignable
open class ContentsTableView: ButtonView {
  
  override open func setup() {
    super.setup()
    hinset = 0.10
  }
  
  override open func draw(_ rect: CGRect) {
    let w = bounds.size.width, h = bounds.size.height,
    lw = (lineWidth+0.01) * w,
    l = w * (1 - 2*hinset),
    hi = w * (hinset/2) + lw,
    vi = h * (vinset/2+0.1) + lw,
    dist = (h - 2*vi)/4,
    sub = 0.2 * l
    let a = CGPoint(x:hi, y:vi),
    b = CGPoint(x:a.x+sub, y:a.y+dist),
    c = CGPoint(x:a.x, y:b.y+dist),
    d = CGPoint(x:a.x+sub, y:c.y+dist),
    e = CGPoint(x:a.x, y:d.y+dist)
    let lines = UIBezierPath()
    lines.move(to: a)
    lines.addLine(to: CGPoint(x:a.x + l, y:a.y))
    lines.move(to: b)
    lines.addLine(to: CGPoint(x:b.x + l - sub, y:b.y))
    lines.move(to: c)
    lines.addLine(to: CGPoint(x:c.x + l, y:c.y))
    lines.move(to: d)
    lines.addLine(to: CGPoint(x:d.x + l - sub, y:d.y))
    lines.move(to: e)
    lines.addLine(to: CGPoint(x:e.x + l, y:e.y))
    lines.lineWidth = lw
    strokeColor.setStroke()
    lines.stroke()
  }
  
} // class ContentsTableView

/**
  XCircleView displays an X optionally in a circle
*/
// MARK: - CircledXView
@IBDesignable
open class CircledXView: ButtonView {

  /// Draw circle around the X?
  open var isCircle = true
  /// Fill color of circle
  open var circleColor = UIColor.clear
  /// Draw cross in inner circle which radius is radius of 
  /// outer circle * innerCircleFactor
  open var innerCircleFactor: CGFloat = 0.8
  
  override open func setup() {
    super.setup()
  }
  
  override open func draw(_ rect: CGRect) {
    let w = bounds.size.width, 
        lw = (lineWidth+0.02) * w,
        center = convert(self.center, from: self.superview),
        radius = (w - 2*hinset - 2*lw)/2
    let path = UIBezierPath()
    path.lineWidth = lw
    path.lineJoinStyle = .miter
    strokeColor.setStroke()
    if isCircle {
      path.circle(center, radius: radius)
      circleColor.setFill()
      path.fill()
      if circleColor == UIColor.clear {
        strokeColor.setStroke()
        path.stroke()        
      }
      path.removeAllPoints()
    }
    path.cross(center, radius: radius*innerCircleFactor)
    strokeColor.setStroke()
    path.stroke()
  }
  
} // class CircledXView


/**
  FlipFlopView drawing either a stylized
  export or import icon.
  
  The primary view is the export icon.
  This view is controlled by following properties:
  * arrowLength (0.6)<br/>
    length of the arrow as a factor to the view's height.
*/
// MARK: - ExportView
@IBDesignable
open class ExportView: FlipFlopView {

  /// Draw import icon?
  @IBInspectable
  open var isImport: Bool { return !isPrimary }

  /// The relative length of the arrow.
  @IBInspectable
  open var arrowLength:Double = 0.6 { didSet { setNeedsDisplay() } }
 
  override open func setup() {
    super.setup()
    hinset = 0.15
  }
  
  open func drawArrow( _ icon: UIBezierPath ) {
    let w = bounds.size.width, h = bounds.size.height,
        vi = h * (vinset/2),
        al = h * CGFloat(arrowLength), // real arrow length
        ap = al * 0.4, // length of point
        xi = ap / CGFloat(sqrt(2.0))
    let a = CGPoint(x:w/2, y:vi),
        b = CGPoint(x:a.x, y:a.y+al)
    icon.move(to: a)
    icon.addLine(to: b)
    if ( !isImport ) {
      let c = CGPoint(x:a.x-xi, y:a.y+xi),
          d = CGPoint(x:a.x+xi, y:c.y)
      icon.move(to: a)
      icon.addLine(to: c)
      icon.move(to: a)
      icon.addLine(to: d)
    }
    else {
      let c = CGPoint(x:a.x-xi, y:b.y-xi),
          d = CGPoint(x:a.x+xi, y:c.y)
      icon.move(to: b)
      icon.addLine(to: c)
      icon.move(to: b)
      icon.addLine(to: d)
    }
  }
  
  open func drawIcon() {
    let w = bounds.size.width, h = bounds.size.height,
        lw = lineWidth * w, // linewidth
        al = h * CGFloat(arrowLength), // real arrow length
        hi = w * (hinset/2) + lw,
        vi = h * (vinset/2) + lw
    let icon = UIBezierPath()
    // draw box
    let a = CGPoint(x:hi, y:vi+al/2),
        b = CGPoint(x:w/2-lw*2, y:a.y),
        c = CGPoint(x:w/2+lw*2, y:a.y),
        d = CGPoint(x:w-hi, y:a.y),
        e = CGPoint(x:d.x, y:h-vi),
        f = CGPoint(x:a.x, y:e.y)
    icon.move(to: a)
    icon.addLine(to: b)
    icon.move(to: c)
    icon.addLine(to: d)
    icon.addLine(to: e)
    icon.addLine(to: f)
    icon.addLine(to: a)
    drawArrow(icon)
    icon.lineWidth = lw
    icon.lineJoinStyle = .miter
    strokeColor.setStroke()
    icon.stroke()
  }
  
  override open func draw(_ rect: CGRect) {
    drawIcon()
  }
  
} // class ExportView


/**
  The ImportView is a convenience class derived from 
  ExportView to draw the import icon.
*/

open class ImportView: ExportView {
  override open func setup() {
    super.setup()
    isPrimary = false
  }
}

/**
  ButtonView displaying an Image.
*/
// MARK: - ImageView
@IBDesignable
open class ImageView: ButtonView {

  open var imageView = UIImageView()
  public var pinAspect = true
  private var aspectConstraint: NSLayoutConstraint?
  private var widthConstraint: NSLayoutConstraint?
  
  open var image: UIImage? {
    get { imageView.image }
    set (img) {
      imageView.image = img
      aspectConstraint?.isActive = false
      if let img = img, pinAspect {
        aspectConstraint = imageView.pinAspect(ratio: img.size.width/img.size.height)
      }
      imageView.tintColor = strokeColor //is ignored if no image
    }
  }
  
  open var symbol: String? {
    didSet {
      if let sym = symbol {
        self.image = UIImage(name: sym)
        self.imageView.contentMode = .scaleAspectFit
      }
    }
  }
  
  open var name: String? {
    didSet {
      if let name = name {
        self.image = UIImage(named: name)
      }
    }
  }
  open override var isActivated: Bool {
    get{ return super.isActivated }
    set{ super.isActivated = newValue; imageView.tintColor = strokeColor }
  }

  open override var color: UIColor {
    didSet { imageView.tintColor = strokeColor }
  }
    
  override open func setup() {
    super.setup()
    addSubview(imageView)
//    self.addBorder(.blue, 0.2)
//    self.imageView.addBorder(.green, 0.2)
    pin(imageView.centerX, to: self.centerX)
    pin(imageView.centerY, to: self.centerY)
  }
    
  override open func layoutSubviews() {
    super.layoutSubviews()
    let w = bounds.size.width * (1-2*hinset)
    widthConstraint?.isActive = false
    widthConstraint = imageView.pinWidth(w)
  }
} // class ImageView

/**
  ButtonView drawing text into a UILabel that just fits the bounds minus insets.
 
  A TextView puts the given text into a UILabel that just fits the bounds of
  the text view. The font size is adjusted to fit the size of the view.
  To define the text to display, use the property `text`:
  ````
  let tv = TextView()
  tv.text = "Hello world"
  ````
*/
// MARK: - TextView
@IBDesignable
open class TextView: ButtonView {

  /// Draw circle around the Label
  open var isCircle = false
  
  /// Fill color of circle
  open var circleColor = UIColor.clear
  
  open var label = LabelWithInsets()
  
  @IBInspectable
  open var text: String? {
    get { return label.text }
    set { label.text = newValue; layoutIfNeeded() }
  }
  
  @IBInspectable
  open var font: UIFont {
    get { return label.font }
    set { 
      label.adjustsFontSizeToFitWidth = false
      label.font = newValue; layoutIfNeeded() 
    }
  }  
  
  override open func setup() {
    super.setup()
    label.font = UIFont.boldSystemFont(ofSize: 4000.0)//???
    label.adjustsFontSizeToFitWidth = true
    label.textAlignment = .center
    label.numberOfLines = 0
    addSubview(label)
  }
  
  override open func draw(_ rect: CGRect) {
    super.draw(rect)
    if isCircle && circleColor != .clear {
      drawCircle(rect)
    }
    
    let w = bounds.size.width, h = bounds.size.height,
        vi = h * (vinset/2),
        hi = w * (hinset/2)
    var frame = bounds
    frame.size.width -= 2*hi
    frame.size.height -= 2*vi
    frame.origin.x = hi
    frame.origin.y = vi
    label.frame = frame
    label.textColor = strokeColor
  }
  
  func drawCircle(_ rect: CGRect) {
    let w = bounds.size.width,
        lw = (lineWidth+0.02) * w,
        center = convert(self.center, from: self.superview),
        radius = (w - 2*hinset - 2*lw)/2
    let path = UIBezierPath()
    path.lineWidth = lw
    path.lineJoinStyle = .miter
    strokeColor.setStroke()
    if isCircle {
      path.circle(center, radius: radius)
      circleColor.setFill()
      path.fill()
      if circleColor == UIColor.clear {
        strokeColor.setStroke()
        path.stroke()
      }
      path.removeAllPoints()
    }
    strokeColor.setStroke()
    path.stroke()
  }
  
  override open func layoutSubviews() {
    setNeedsDisplay()
  }
  
} // class TextView

public class LabelWithInsets : UILabel {
  public var textInsets : UIEdgeInsets = .zero
  public override func drawText(in rect: CGRect) {
      super.drawText(in: rect.inset(by: textInsets))
  }
}


/**
 ButtonView drawing text into a UILabel that is resized to fit the text/font
 
 The ArrowedTextView displays a String in a just fitting label preceeded or succeeded 
 by an optional arrow (like the leftmost back button drawn by navigation controllers).
 Unlike FixedTextView this ButtonView uses the text size (and the font) to calculate
 the frame of the label. If the font size is changed, the size of the frame is adapted 
 but the origin remains the same.
 The following properties may be used to define its appearance:

  * text: defines the text to display
  * font: defines the text font
  * isLeftArrow: defines whether an arrow is to be drawn, the following
    values may be used:
    - nil: don't draw arrow
    - true: draw left arrow:  <|text|
    - false: draw right arrow: |text|>
 
  To display a button consisting of a right arrow only, simply set the text to "":
  ````
  let b = ArrowedTextView()
  b.text = ""
  b.isLeftArrow = false
  ````
 */
// MARK: - ArrowedTextView
@IBDesignable
open class ArrowedTextView: ButtonView {
  
  open var label = " ".label()
  
  /// draw left arrow? (nil for no arrow at all)
  open var isLeftArrow: Bool? = true
  
  // no text?
  private var isEmptyText = true
  
  /// text to display 
  @IBInspectable
  open var text: String? {
    get { return label.text }
    set { 
      if newValue == "" { label.text = " "; isEmptyText = true }
      else { label.text = newValue; isEmptyText = false }      
      setNeedsLayout()
    }
  }
  
  /// font to use for the displayed text
  @IBInspectable
  open var font: UIFont? {
    get { return label.font }
    set { label.font = newValue; setNeedsLayout() }
  }
  
  override open func setup() {
    super.setup()
    lineWidth = 0.1
    label.font = UIFont.systemFont(ofSize: 17)
    addSubview(label)
  }
  
  open func drawArrow() {
    if let isLeft = isLeftArrow {
      let h = bounds.size.height, w = bounds.size.width,
          hi = w*(hinset/2), vi = h*(vinset/2),
          d = h/2 - vi,
          lw = lineWidth * h
      let arrow = UIBezierPath()
      var pu: CGPoint, pm: CGPoint, pl: CGPoint
      if isLeft {
        pu = CGPoint(x:hi+d+lw, y:vi)
        pm = CGPoint(x:hi+lw, y:h/2)
        pl = CGPoint(x:pu.x, y:h-vi)
      }
      else {
        pu = CGPoint(x:w-hi-d-lw, y:vi)
        pm = CGPoint(x:w-hi-lw, y:h/2)
        pl = CGPoint(x:pu.x, y:h-vi)       
      }
      arrow.move(to: pu)
      arrow.addLine(to: pm)
      arrow.addLine(to: pl)
      arrow.lineJoinStyle = .miter
      arrow.lineWidth = lw
      strokeColor.setStroke()
      arrow.stroke()
    }
  }
  
  override open func layoutSubviews() {
    label.frame = CGRect(x: 0, y: 0, width: CGFloat.greatestFiniteMagnitude,
                         height: CGFloat.greatestFiniteMagnitude)
    label.sizeToFit()
    let lh = label.frame.size.height,
        lw = label.frame.size.width,
        h = lh/(1-vinset)
    var w: CGFloat, lx: CGFloat
    if let isLeft = isLeftArrow { 
      let d = h/2 - h*(vinset/2),         // width of arrow
          s = "M".size(font:font).width/3 // space between arrow and text
      if isEmptyText { w = (d + lineWidth*h)/(1-hinset) }
      else { w = (d + s + lw + lineWidth*h)/(1-hinset) }
      if isLeft { lx = w*(hinset/2) + d + s + lineWidth*h }
      else { lx = w*(hinset/2) }
    }
    else { 
      w = lw*(1-hinset)
      lx = w*(hinset/2)
    }
    let ly = h*(vinset/2)
    let orig = frame.origin
    bounds.size = CGSize(width: w, height: h)
    frame.origin = orig
    label.frame.origin.x = lx
    label.frame.origin.y = ly
  }
  
  override open func draw(_ rect: CGRect) {
    if isLeftArrow != nil { drawArrow() }
    label.textColor = strokeColor
  }
  
} // class ArrowedTextView


/**
  ButtonView drawing  a stylized trash bin icon.
*/
// MARK: - TrashBinView
@IBDesignable
open class TrashBinView: ButtonView {

  override open func setup() {
    super.setup()
    color = UIColor.red
  }
  
  open func drawBin() {
    let bw = bounds.size.width, bh = bounds.size.height,
        lw = (lineWidth+0.02) * bw, // linewidth
        hi = bw * (hinset/2) + lw,
        vi = bh * (vinset/2) + lw,
        h = bw - 2*vi,
        w = bw - 2*hi,
        a = 0.15 * h,  // height of handle
        b = 0.35 * w,  // width of handle
        c = 0.8 * w,   // upper width of box
        d = 0.65 * w,  // lower width of box
        e = 0.1 * h,   // vertical spacing
        f = 0.05 * w   // horizontal spacing
    let bin = UIBezierPath()
    // draw box
    let p1 = CGPoint(x:(w-c)/2+hi, y:a+vi),
        p2 = CGPoint(x:(w-d)/2+hi, y:bh-e-vi),
        p3 = CGPoint(x:p2.x+f, y:p2.y+e),
        p4 = CGPoint(x:p2.x+d-f, y:p3.y),
        p5 = CGPoint(x:p4.x+f, y:p2.y),
        p6 = CGPoint(x:p1.x+c, y:p1.y),
        p7 = CGPoint(x:p1.x+c/3, y:p1.y+e),
        p8 = CGPoint(x:p2.x+d/3, y:p2.y),
        p9 = CGPoint(x:p6.x-c/3, y:p7.y),
        p10 = CGPoint(x:p5.x-d/3, y:p5.y),
        p11 = CGPoint(x:hi, y:p1.y),
        p12 = CGPoint(x:bw-hi, y:p1.y),
        p13 = CGPoint(x:(bw-b)/2, y:p1.y),
        p14 = CGPoint(x:p13.x, y:a/3+vi),
        p15 = CGPoint(x:p13.x+a/3, y:vi),
        p16 = CGPoint(x:p13.x+b-a/3, y:vi),
        p17 = CGPoint(x:p13.x+b, y:a/3+vi),
        p18 = CGPoint(x:p17.x, y:p1.y)
    bin.move(to: p1)
    bin.addLine(to: p2)
    bin.addCurve(p3, bending: 0.2)
    bin.addLine(to: p4)
    bin.addCurve(p5, bending: 0.2)
    bin.addLine(to: p6)
    bin.move(to: p7)
    bin.addLine(to: p8)
    bin.move(to: p9)
    bin.addLine(to: p10)
    bin.move(to: p11)
    bin.addLine(to: p12)
    bin.move(to: p13)
    bin.addLine(to: p14)
    bin.addCurve(p15, bending: -0.1)
    bin.addLine(to: p16)
    bin.addCurve(p17, bending: -0.1)
    bin.addLine(to: p18)
    bin.lineWidth = lw
    bin.lineJoinStyle = .miter
    strokeColor.setStroke()
    bin.stroke()
  }
  
  override open func draw(_ rect: CGRect) {
    drawBin()
  }
  
} // class TrashBinView

