//
//  Slider.swift
//
//  Created by Norbert Thies on 10.12.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import UIKit

/**
 *  A Slider models a view controller that is slid into another (currently
 *  active) view controller either from the left or from the right side.
 *  In order to slide the subview controller there are two new views created:
 *    - a shade view that is used to dim the view of the current view controller
 *    - a slider view that is used to contain the subview controller
 *  A tap on the shade view slides the subview controller back to the left (or
 *  right) and removes it from the slider view. Following the shade and slider views
 *  are removed.
 */
open class Slider: NSObject, DoesLog, HandleOrientation {
  /// Default decoration height
  var decorationHeight: CGFloat = 20
  /// Default handle width
  var handleWidth: CGFloat = 40
  /// Default handle height
  var handleHeight: CGFloat = 5
  /// currently active view controller to slide into
  var active: UIViewController
  /// view controller being slid in
  var slider: UIViewController
  /// Horizontal or vertical slide (from top or bottom)
  var isHorizontal: Bool
  /// Slide from default edge (left in horizontal and bottom in vertical slide mode)
  var fromDefault: Bool = true { didSet { resetConstraints() } }
  /// Slide in from left? (from right otherwise) (in horizontal mode)
  var fromLeft: Bool {
    get { return isHorizontal && fromDefault }
    set { if isHorizontal { fromDefault = newValue } }
  }
  /// Slide in from bottom? (from top otherwise) (in vertical mode)
  var fromBottom: Bool {
    get { return !isHorizontal && fromDefault }
    set { if !isHorizontal { fromDefault = newValue } }
  }
  
  // Closure called upon orientation changes
  public var orientationChangedClosure = OrientationClosure()
  /// how much of the active view controller is covered by the slider
  /// (80% by default)
  public var coverageRatio: CGFloat = 0.8 { didSet { resetConstraints() } }
  /// how long shall the sliding animation be (in seconds, 0.5 by default)
  public var duration: TimeInterval = 0.5
  /// how many points of the active view controller are covered by the slider
  /// (derived from coverageRatio by default)
  open var coverage: CGFloat { 
    get {
      if isHorizontal { return active.view.bounds.width * coverageRatio }
      else { return active.view.bounds.height * coverageRatio }
    }
    set {
      if isHorizontal {
        let cov = min(newValue, active.view.bounds.width)
        coverageRatio = cov/active.view.bounds.width
      }
      else {
        let cov =  min(newValue, active.view.bounds.height)
        coverageRatio = cov/active.view.bounds.height
      }
    }
  }
  
  // is slider opened
  public fileprivate(set) var isOpen = false
    
  fileprivate var openClosure: ((Slider)->())? = nil
  fileprivate var closeClosure: ((Slider)->())? = nil
  fileprivate var tmpOpenClosure: ((Slider)->())? = nil
  fileprivate var tmpCloseClosure: ((Slider)->())? = nil

  /// defines the closure to call when the slider has been slid in
  public func onOpen(closure: @escaping (Slider)->()) {
    openClosure = closure
  }
  
  /// defines the closure to call when the slider has been removed
  public func onClose(closure: @escaping (Slider)->()) {
    closeClosure = closure
  }
  
  var shadeView = UIView()
  public private(set) var sliderView = UIView()
  var contentView = UIView()
  var handleView: RoundedRect?
  
  /// color of the slider decoration (if any)
  public var color: UIColor? {
    get { return sliderView.backgroundColor }
    set { 
      guard let color = newValue else { return }
      sliderView.backgroundColor = color
      if let handle = handleView, handleColor == nil { handle.color = color.dimmed() }
    }
  }
  /// Color of the decoration's handle
  public var handleColor: UIColor? {
    didSet { if let col = handleColor { handleView?.color = col } }
  }
  
  lazy var leadingConstraint =
    sliderView.leadingAnchor.constraint(equalTo:active.view.leadingAnchor)
  lazy var trailingConstraint =
    sliderView.trailingAnchor.constraint(equalTo:active.view.trailingAnchor)
  lazy var widthConstraint =
    sliderView.widthAnchor.constraint(equalToConstant: 0)
  lazy var topConstraint =
    sliderView.topAnchor.constraint(equalTo:active.view.safeAreaLayoutGuide.topAnchor)
  lazy var bottomConstraint =
    sliderView.bottomAnchor.constraint(equalTo:active.view.bottomAnchor)
  lazy var heightConstraint =
    sliderView.heightAnchor.constraint(equalToConstant: 0)
  var horizontalnvariableConstraints:[NSLayoutConstraint]?
  
  var currentCoverage: CGFloat {
    let coverage = self.coverage
    if isHorizontal {
      if fromLeft { return coverage + leadingConstraint.constant }
      else { return coverage - trailingConstraint.constant }
    }
    else {
      if fromBottom { return coverage - bottomConstraint.constant }
      else { return coverage + topConstraint.constant }
    }
  }
  
  var isNearOpen: Bool { currentCoverage > coverage/2.0 }

  func setupInvariableConstraints() {
    let view = active.view!
    pin(shadeView.top, to: view.top)
    pin(shadeView.bottom, to: view.bottom)
    pin(shadeView.left, to: view.left)
    pin(shadeView.right, to: view.right)
    if isHorizontal {
      pin(sliderView.top, to: view.top)
      pin(sliderView.bottom, to: view.bottom)
    }
    else {
      horizontalnvariableConstraints = [
      pin(sliderView.left, to: view.left),
      pin(sliderView.right, to: view.right)]
    }
  }

  func resetHorizontalConstraints() {
    widthConstraint.isActive = true
    widthConstraint.constant = coverage
    if isOpen {
      leadingConstraint.constant = 0
      trailingConstraint.constant = 0
    }
    else {
      leadingConstraint.constant = -coverage
      trailingConstraint.constant = coverage
    }
    if fromLeft {
      leadingConstraint.isActive = true
      trailingConstraint.isActive = false
    }
    else {
      leadingConstraint.isActive = false
      trailingConstraint.isActive = true
    }
    active.view.layoutIfNeeded()
  }
  
  func resetVerticalConstraints() {
    heightConstraint.isActive = true
    heightConstraint.constant = coverage - UIWindow.topInset
    if isOpen {
      topConstraint.constant = 0
      bottomConstraint.constant = 0
    }
    else {
      topConstraint.constant = -coverage
      bottomConstraint.constant = coverage
    }
    if fromBottom {
      topConstraint.isActive = false
      bottomConstraint.isActive = true
    }
    else {
      topConstraint.isActive = true
      bottomConstraint.isActive = false
    }
    active.view.layoutIfNeeded()
  }
  
  func resetConstraints() {
    if isHorizontal { resetHorizontalConstraints() }
    else { resetVerticalConstraints() }
  }
  
  func toggleSlider() {
    slide(toOpen: !isOpen)
  }

  @objc private func handleTap() {
    toggleSlider()
  }
  
  @objc private func handlePan(recog: UIPanGestureRecognizer) {
    guard isOpen else { return }
    if recog.state == .ended {
      if isNearOpen { open() }
      else { close() }
      return
    }
    let view = recog.view
    let translation = recog.translation(in: view)
    recog.setTranslation(CGPoint(), in: view)
    if isHorizontal {
      leadingConstraint.constant += translation.x
      leadingConstraint.constant = min(0.0, leadingConstraint.constant)
      trailingConstraint.constant += translation.x
      trailingConstraint.constant = max(0.0, trailingConstraint.constant)
    }
    else {
      topConstraint.constant += translation.y
      topConstraint.constant = min(0.0, topConstraint.constant)
      bottomConstraint.constant += translation.y
      bottomConstraint.constant = max(0.0, bottomConstraint.constant)
    }
    active.view.layoutIfNeeded()
  }
  
  // In case of decoration make vertical slider larger with rounded corners
  func decorateSlider(_ isDecorate: Bool) {
    if isDecorate && !isHorizontal {
      let handle = RoundedRect()
      handleView = handle
      sliderView.addSubview(handle)
      handle.pinWidth(handleWidth)
      handle.pinHeight(handleHeight)
      pin(handle.centerX, to: sliderView.centerX)
      pin(contentView.left, to: sliderView.left)
      pin(contentView.right, to: sliderView.right)
      sliderView.layer.cornerRadius = decorationHeight/2
      if fromBottom {
        pin(contentView.bottom, to: sliderView.bottom, priority: .fittingSizeLevel)
        pin(contentView.top, to: sliderView.top, dist: decorationHeight)
        // Mask top right and left corners
        sliderView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        pin(handle.top, to: sliderView.top, dist: (decorationHeight - handleHeight)/2)
      }
      else {
        pin(contentView.top, to: sliderView.top)
        pin(contentView.bottom, to: sliderView.bottom, dist: -decorationHeight)        
        // Mask bottom right and left corners
        sliderView.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        pin(handle.bottom, to: sliderView.bottom, dist: -(decorationHeight - handleHeight)/2)
      }
    }
    else {
      pin(contentView, to: sliderView)
    }
  }
  
  /// A Slider is initialized with the view controller to slide in and a
  /// second view controller to slide into
  public init(slider: UIViewController, into active: UIViewController, 
              isHorizontal: Bool = true, isFromDefault: Bool = true,
              isDecorate: Bool = false) {
    self.slider = slider
    self.active = active
    self.isHorizontal = isHorizontal
    self.fromDefault = isFromDefault
    super.init()
    shadeView.backgroundColor = UIColor.black
    shadeView.translatesAutoresizingMaskIntoConstraints = false
    shadeView.isHidden = true
    sliderView.translatesAutoresizingMaskIntoConstraints = false
    sliderView.isHidden = true
    sliderView.clipsToBounds = true
    contentView.backgroundColor = UIColor.clear
    let tapRecognizer = UITapGestureRecognizer(target: self,
                                               action: #selector(handleTap))
    tapRecognizer.numberOfTapsRequired = 1
    shadeView.addGestureRecognizer(tapRecognizer)
    let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
    sliderView.addGestureRecognizer(panRecognizer)
    sliderView.addSubview(contentView)
    decorateSlider(isDecorate)
    active.view.addSubview(shadeView)
    active.view.addSubview(sliderView)
    
    setupInvariableConstraints()
    let ics = slider.view.intrinsicContentSize
    if isHorizontal { if ics.width > 0 { coverage = ics.width } }
    else { if ics.height > 0 { coverage = ics.height } }
    resetConstraints()
    
    onOrientationChange{ [weak self] in
      onMainAfter {
        self?.resetConstraints()
      }
    }
  }
  
  public func slide(toOpen: Bool, animated: Bool = true) {
    let view = active.view!
    shadeView.isHidden = false
    sliderView.isHidden = false
    if !isOpen {
      shadeView.alpha = 0
      active.presentSubVC(controller: slider, inView: contentView)
      view.layoutIfNeeded()
    }
    isOpen = toOpen
    let duration = animated ? self.duration : 0
    UIView.animate(withDuration: duration,
                   delay: 0,
                   usingSpringWithDamping: 0.8,
                   initialSpringVelocity: 0.2,
                   options: .curveEaseOut,
                   animations: {   [weak self] in
      guard let self = self else { return }
      if self.isOpen { self.shadeView.alpha = 0.3 }
      else { self.shadeView.alpha = 0 }
      self.resetConstraints()
    }) { [weak self] _ in // completion
      guard let self = self else { return }
      if !self.isOpen { // remove slider
        self.active.removeSubVC(self.slider)
        self.shadeView.isHidden = true
        self.sliderView.isHidden = true
        view.layoutIfNeeded()
        if let closure = self.tmpCloseClosure { self.tmpCloseClosure = nil; closure(self) }
        if let closure = self.closeClosure { closure(self) }
      }
      else {
        if let closure = self.tmpOpenClosure { self.tmpOpenClosure = nil; closure(self) }
        if let closure = self.openClosure { closure(self) }
      }
    }
  }
  
  /// open the slider (slider sliding in)
  public func open(animated: Bool = true, closure: ((Slider)->())? = nil) {
    tmpOpenClosure = closure
    slide(toOpen: true, animated: animated)
  }
  
  /// close the slider (slide out)
  public func close(animated: Bool = true, closure: ((Slider)->())? = nil) {
    tmpCloseClosure = closure
    slide(toOpen: false, animated: animated)
  }
} // class Slider

/**
 *  Adoption of horizontal ButtonSlider with aditional open coverage used in taz cannot be placed there due
 *   class is called from NorthLib taz project is hidden from NorthLib so on execution the ratio was not set
 *   in release only in debug
 */
open class MyButtonSlider:ButtonSlider{
  
  let ContentSliderMaxWidth = 420.0
  
  open var openShiftRatio: CGFloat = 0.7
  
  open var ocoverage: CGFloat? {
    didSet {
      if oldValue == ocoverage { return }
      guard let ocoverage = ocoverage, isOpen else { return }
      shiftRatio = ocoverage < ContentSliderMaxWidth ? openShiftRatio : 0.1
      resetConstraints()
    }
  }
  open override var coverage: CGFloat {
    get { return ocoverage ?? super.coverage }
    set { super.coverage = newValue }
  }
  open override func slide(toOpen: Bool, animated: Bool = true) {
    if toOpen == true, let ocoverage = ocoverage, ocoverage < ContentSliderMaxWidth {
      shiftRatio = openShiftRatio
    }
    else if toOpen == false && shiftRatio != 0.1 {
      shiftRatio = 0.1
    }
    super.slide(toOpen: toOpen, animated: animated)
  }
  
  open func hideContentAnimated(){
    contentView.hideAnimated()
  }
}


/**
 *  A ButtonSlider is a horizontal Slider that uses an image as a Button at the 
 *  top left/right corner of the active view controller to slide in a slider view 
 *  controller.
 */
open class ButtonSlider: Slider {
  private var buttonMovedOut:Bool = false
  
  /// Maximum absolute coverage of the active view controller
  public var maxCoverage: CGFloat? = nil {
    didSet { evaluateCoverage() }
  }
  
  /// image to use as button
  public var image: UIImage? {
    didSet {
      guard let img = image else { return }
      button.setImage(img, for: .normal)
      evaluateCoverage()
    }
  }
  public var hideButtonOnClose = false
  public var button = CustomButton(type: .custom)
  public var buttonAlpha: CGFloat = 1.0 {
    didSet { button.alpha = buttonAlpha }
  }
  public var shiftRatio: CGFloat = 0.1 { didSet { resetConstraints() } }
  public var shift: CGFloat { (image?.size.width ?? 0) * shiftRatio }
  public var visibleButtonWidth: CGFloat { (image?.size.width ?? 0) * (1-shiftRatio) }
  public var topInset: CGFloat = 10 { didSet { resetConstraints() } }
  public override var fromLeft: Bool { didSet { resetConstraints() } }
  
  public lazy var leadingButtonConstraint: NSLayoutConstraint =
    button.leadingAnchor.constraint(equalTo: sliderView.trailingAnchor)
  public lazy var trailingButtonConstraint: NSLayoutConstraint =
    button.trailingAnchor.constraint(equalTo: sliderView.leadingAnchor)
  public lazy var topButtonConstraint: NSLayoutConstraint =
    button.topAnchor.constraint(equalTo: active.view.safeAreaLayoutGuide.topAnchor)
  public lazy var widthButtonConstraint: NSLayoutConstraint =
    button.widthAnchor.constraint(equalToConstant: 0)
  public lazy var heightButtonConstraint: NSLayoutConstraint =
    button.heightAnchor.constraint(equalToConstant: 0)
  
  private func evaluateCoverage() {
    guard let img = image else { return }
    let awidth = active.view!.bounds.size.width
    let cov: CGFloat = maxCoverage ?? awidth
    coverage = min(cov, awidth - img.size.width)
  }
  
  public override func resetConstraints() {
    super.resetConstraints()
    topButtonConstraint.constant = topInset
    if let img = image {
      widthButtonConstraint.constant = img.size.width
      heightButtonConstraint.constant = img.size.height
    }
    if fromLeft {
      if buttonMovedOut == false { leadingButtonConstraint.constant = -shift}
      leadingButtonConstraint.isActive = true
      trailingButtonConstraint.isActive = false
    }
    else {
      trailingButtonConstraint.constant = shift
      trailingButtonConstraint.isActive = true
      leadingButtonConstraint.isActive = false
    }
    NSLayoutConstraint.activate([topButtonConstraint, widthButtonConstraint,
                                 heightButtonConstraint])
    active.view?.layoutIfNeeded()
  }
  
  /// Updates the Horizontal Button Slider Width if open
  /// - Parameter newWidth: new Slider Width otherwise coverage will be used
  /// keep in mind, if called from: "viewWillTransition(to size:" coverage my returns wrong value
  public func updateSliderWidthIfNeeded(_ newWidth: CGFloat? = nil){
    if isOpen == false { return }
    widthConstraint.constant = newWidth ?? coverage
  }

  
  @objc public func buttonPressed(sender: UIButton) {
    toggleSlider()
  }
  
  override func setupInvariableConstraints() {
    super.setupInvariableConstraints()
    pin(sliderView.top, to: active.view!.top, priority: .required)
  }
  
  public init(slider: UIViewController, into active: UIViewController) {
    active.view.addSubview(button)
    button.translatesAutoresizingMaskIntoConstraints = false
    self.button.additionalTapOffset = 5.0
    super.init(slider: slider, into: active, isHorizontal: true)
    active.view.bringSubviewToFront(button)
    button.addTarget(self, action: #selector(buttonPressed(sender:)), for: .touchUpInside)
  }
  
  public func buttonMoveOut( _ duration: TimeInterval = 0.7, _ delay: TimeInterval = 0.1, atEnd: (()->())? = nil ) {
    UIView.animate(withDuration: duration/2, delay: delay, options: .curveEaseOut, animations: {
      self.leadingButtonConstraint.constant = -self.button.frame.size.width+2
      self.active.view.layoutIfNeeded()
    } ) { _ in
      UIView.animate(withDuration: duration/2, delay: 0, options: .curveEaseOut, animations: {
        self.leadingButtonConstraint.constant = -self.button.frame.size.width+7
        self.active.view.layoutIfNeeded()
      } ) { [weak self] _ in
        if let closure = atEnd { closure() }
        self?.collapsedButtonAnimation = false
      }
    }
  }
  
  var collapsedButtonAnimation = false {
    didSet {
      guard collapsedButtonAnimation == false else { return }
      log("collapsedButtonAnimation set to false collapsedButtonNext is: \(collapsedButtonNext ?? false)")
      collapsedButton = collapsedButtonNext ?? collapsedButton
      collapsedButtonNext = nil
    }
  }
  var collapsedButtonNext: Bool?
  
  
  /// move in/out the slider button with animation on value change
  ///
  public var collapsedButton: Bool = false {
    didSet {
      if oldValue == collapsedButton { return }
      
      self.button.additionalTapOffset = collapsedButton ? 50.0 : 5.0
      
      if collapsedButtonAnimation {
        collapsedButtonNext = collapsedButton
        ///Prevent race condition: if animation just finished set the next value otherwise reset to old value
        ///default value for nil-coalescing operator is irellevant
        collapsedButton = collapsedButtonAnimation ? oldValue : collapsedButtonNext ?? collapsedButton
        return
      }
      collapsedButtonAnimation = true
      hideButtonOnClose = collapsedButton
      if collapsedButton {
        buttonMovedOut = true
        buttonMoveOut() }
      else {
        buttonMovedOut = false
        buttonMoveIn()
      }
    }
  }
  
  func buttonMoveIn( _ duration: TimeInterval = 0.7, _ delay: TimeInterval = 0.1, atEnd: (()->())? = nil ) {
    UIView.animate(withDuration: duration/2, delay: delay, options: .curveEaseOut, animations: {
      self.leadingButtonConstraint.constant = -self.button.frame.size.width+2
      self.active.view.layoutIfNeeded()
    } ) { _ in
      UIView.animate(withDuration: duration/2, delay: 0, options: .curveEaseOut, animations: {
        self.leadingButtonConstraint.constant = 0
        self.active.view.layoutIfNeeded()
      } ) {[weak self] _ in
        if let closure = atEnd { closure() }
        self?.collapsedButtonAnimation = false
      }
    }
  }
  
  public func buttonFadeOut( _ duration: TimeInterval, atEnd: (()->())? = nil ) {
    UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut, animations: {
      self.button.alpha = 0
    } ) { _ in
      if let closure = atEnd { closure() }
    }
  }
  
  public func buttonFadeIn( _ duration: TimeInterval, atEnd: (()->())? = nil ) {
    UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.03,
                   initialSpringVelocity: 0.0, options: .curveEaseOut, animations: {
      self.button.alpha = self.buttonAlpha
    } ) { _ in
      if let closure = atEnd { closure() }
    }
  }
  
  open override func slide(toOpen: Bool, animated: Bool = true) {
    buttonMovedOut = !toOpen
    super.slide(toOpen: toOpen, animated: animated)
    if hideButtonOnClose, toOpen == false { buttonMoveOut()}
  }
  
  public func blinkButton() {
    let tout: TimeInterval = 1.2
    let tin: TimeInterval = 1.5
    self.buttonFadeOut(tout) {
      self.buttonFadeIn(tin)
    }
  }
  
} // class ButtonSlider

/// A small UIResponder extension to retrieve the first responder
public extension UIResponder {
  private struct Dummy {
    static weak var responder: UIResponder?
  }
  static var first: UIResponder? {
    Dummy.responder = nil
    UIApplication.shared.sendAction(#selector(_storeFirstResponder), to: nil, 
                                    from: nil, for: nil)
    return Dummy.responder
  }
  @objc private func _storeFirstResponder() { Dummy.responder = self }
}

/**
 A VerticalSheet is a vertical Slider that provides for text input fields and 
 and shifts the View up/down when the keyboard appears/disappears and the input field
 could be hidden.
 */
open class VerticalSheet: Slider {
  // Minimal distance between keyboard and text field
  let minDistance: CGFloat = 20
  
  // Keyboard distance slid up
  var kbDistance: CGFloat?
  
  //MARK: Slide Up
  public func slideUp(_ dist: CGFloat) {
    debug("up: \(dist)")
    guard isOpen else { return }
    UIView.animate(seconds: duration) { [weak self] in
      guard let self = self else { return }
      self.topConstraint.constant += dist
      self.bottomConstraint.constant -= dist
      self.active.view.layoutIfNeeded()
    }
  }
  
  /// Move the slider down
  public func slideDown(_ dist: CGFloat) { slideUp(-dist) }
  
  // Keyboard change notification handler, shifts sheet if necessary
  @objc func handleKeyboardChange(notification: Notification) {
    guard let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] 
      as? NSValue)?.cgRectValue else { return }
    guard kbDistance == nil else { return }
    let firstResponder = UIResponder.first
    var view: UIView? = firstResponder as? UITextField
    if view == nil { view = firstResponder as? UITextView }
    if let view = view {
      var textFrame = view.frame
      textFrame = UIWindow.keyWindow!.convert(textFrame, from: view.superview)
      debug("keyboardFrame: \(keyboardFrame), textFrame: \(textFrame)")
      let kbY = keyboardFrame.origin.y
      let tY = textFrame.origin.y + textFrame.size.height
      if tY > kbY + minDistance {
        kbDistance = tY - (kbY + minDistance)
        debug("Sliding up: \(kbDistance!)")
        slideUp(kbDistance!)
      }
    }
  }
  
  // Keyboard hide notification handler, shifts sheet back if necessary
  @objc func handleKeyboardHide(notification: Notification) {
    if let dist = kbDistance {
      debug("Sliding down: \(dist)")
      slideDown(dist)
      kbDistance = nil
    }
  }
  
  public init(slider: UIViewController, into active: UIViewController,
              fromBottom: Bool = true) {
    super.init(slider: slider, into: active, isHorizontal: false, isFromDefault: fromBottom,
               isDecorate: true)
    NotificationCenter.default.addObserver(self, 
      selector: #selector(handleKeyboardChange(notification:)), 
      name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    NotificationCenter.default.addObserver(self, 
      selector: #selector(handleKeyboardHide(notification:)), 
      name: UIResponder.keyboardWillHideNotification, object: nil)
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self, 
      name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    NotificationCenter.default.removeObserver(self, 
      name: UIResponder.keyboardWillHideNotification, object: nil)
  }  
} // VerticalSheet

/// A BottomSheet is a vertical Slider growing from the bottom
open class BottomSheet: VerticalSheet {
  public init(slider: UIViewController, into active: UIViewController, maxWidth:CGFloat?=nil) {
    super.init(slider: slider, into: active, fromBottom: true)
    if let maxWidth = maxWidth, let view = active.view {
      for constraint in horizontalnvariableConstraints ?? [] {
        constraint.isActive = false
      }
      //iOS 12 dislike change of Priority even in init
      horizontalnvariableConstraints = [
        pin(sliderView.left, to: view.left, priority: .defaultHigh),
        pin(sliderView.right, to: view.right, priority: .defaultHigh)]
      
      sliderView.pinWidth(maxWidth, relation: .lessThanOrEqual, priority: .required)
      sliderView.centerX()
    }
  }
  
  public func setCoverage(_ coverage: CGFloat, for activeViewHeight:CGFloat?){
    let aH = activeViewHeight ?? active.view.bounds.height
    let cov =  min(coverage, aH)
    coverageRatio = cov/aH
  }
}

public class FullscreenBottomSheet : BottomSheet{
  
  public var onUserSlideToClose : (()->())?
  
  /// close the slider (slide out)
  public override func close(animated: Bool = true, closure: ((Slider)->())? = nil) {
    tmpCloseClosure = closure
    if let closure = onUserSlideToClose {
      closure()
    }
    else {
      slide(toOpen: false, animated: animated)
    }
  }
  
  public var activeVC:UIViewController {
    get { return active }
    set { active = newValue }
  }
  
  public var sliderVC:UIViewController {
    get { return slider }
    set { slider = newValue }
  }
  
  // Keyboard change notification handler, shifts sheet if necessary
  @objc override func handleKeyboardChange(notification: Notification) {
    guard let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
      as? NSValue)?.cgRectValue else { return }
    guard kbDistance == nil else { return }
    kbDistance = keyboardFrame.size.height
    slideUp(keyboardFrame.size.height)
  }
  
  public override func slideUp(_ dist: CGFloat) {
    guard isOpen else { return }
    UIView.animate(seconds: duration) { [weak self] in
      guard let self = self else { return }
      self.bottomConstraint.constant -= (dist)
      self.heightConstraint.constant -= (dist)
      self.active.view.layoutIfNeeded()
    }
  }
}

/**
 A RoundedRect is a view that consists solely of a rectangle which left and right 
 edges are half circles.
 */
open class RoundedRect: UIView {
  
  /// The color to draw the rectangle in
  open var color: UIColor = UIColor.gray { didSet { self.setNeedsDisplay() } }

  override open func draw(_ rect: CGRect) {
    let path = UIBezierPath(roundedRect: self.bounds, cornerRadius: self.bounds.height/2)
    color.setFill()
    path.fill()
  }
  
  override public init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = UIColor.clear
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
    backgroundColor = UIColor.clear
  }
  
}


public class CustomButton: UIButton {
  public var additionalTapOffset:CGFloat = 0
  
  public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return bounds.insetBy(dx: -additionalTapOffset, dy: -additionalTapOffset).contains(point)
    }
}
