//
//  Overlay.swift
//  NorthLib
//
// Created by Ringo Müller-Gromes on 23.06.20.
// Copyright © 2020 Ringo Müller-Gromes for "taz" digital newspaper. All rights reserved.
//
import UIKit

/**
 The Overlay class manages the two view controllers 'overlay' and 'active'.
 'active' is currently visible and 'overlay' will be presented on top of
 'active'. To accomplish this, two views are created, the first one, 'shadeView'
 is positioned on top of 'active.view' with the same size and colored 'shadeColor'
 with an alpha between 0...maxAlpha. This view is used to shade the active view
 controller during the open/close animations. The second view, overlayView is
 used to contain 'overlay' and is animated during opening and closing operations.
 In addition two gesture recognizers (pinch and pan) are used on shadeView to
 start the close animation. The pan gesture is used to move the overlay to the bottom of shadeView.
 The pinch gesture is used to shrink the overlay
 in size while being centered in shadeView. When 'overlay' has been shrunk to
 'closeRatio' (see attribute) or moved 'closeRatio * overlayView.bounds.size.height'
 points to the bottom then 'overlay' is animated automatically away from the
 screen. While the gesture recognizers are working or during the animation the
 alpha of shadeView is changed to reflect the animation's ratio (alpha = 0 =>
 'overlay' is no longer visible). The gesture recognizers coexist with gesture
 recognizers being active in 'overlay'.
 */
/**
 This Class is the container and holds the both VC's
 presentation Process: UIViewControllerContextTransitioning?? or simply
 =====
 ToDo List
 ======
 O Low Prio: Fix From Rect to Rect open/close
 O OverlaySpec
 O=> var overlaySize: CGSize?
 O pinch & zoom & pan only in overlayView or may also in a wrapper over activeVC.view
 */

// MARK: - OverlayAnimator
public class Overlay: NSObject, OverlaySpec, UIGestureRecognizerDelegate {
  //usually 0.4-0.5
  private var openDuration: Double { get { return debug ? 3.0 : 0.4 } }
  private var closeDuration: Double { get { return debug ? 3.0 : 0.25 } }
  public var debug = false
  private var closeAction : (() -> ())?
  private var updatedCloseFrame : (() -> (CGRect?))?
  private var onCloseHandler: (() -> ())?
  
  var shadeView: UIView?
  public private(set) var overlayVC: UIViewController
  var activeVC: UIViewController
  
  public var overlayView: UIView?
  public var contentView: UIView?//either overlayVC.view or its wrapper
  public var overlaySize: CGSize?
  /// optional bottom offset e.g. for Toolbar
  public var bottomOffset: CGFloat?
  public var maxAlpha: Double = 0.8
  public var shadeColor: UIColor = .black
  public var enablePinchAndPan: Bool = true
  public var closeRatio: CGFloat = 0.5 {
    didSet {
      //Prevent math issues
      if closeRatio > 1.0 { closeRatio = 1.0 }
      if closeRatio < 0.1 { closeRatio = 0.1 }
    }
  }
  
  // MARK: - init
  public required init(overlay: UIViewController, into active: UIViewController) {
    overlayVC = overlay
    activeVC = active
    super.init()
  }
  
  // MARK: - onClose/onCloseHandler
  public func onClose(closure: (() -> ())?) {
    if closure == nil {
      self.closeAction = nil
    }
    self.onCloseHandler = closure
  }
  
  public func onRequestUpdatedCloseFrame(closure: (() -> (CGRect?))?) {
    self.updatedCloseFrame = closure
  }
  
  public func setCloseActionToShrink(){
    closeAction = { [weak self] in
      guard let self = self else { return }
      guard let fromFrame = self.overlayView?.frame else {
        self.close(animated: true, toBottom: true)
        return
      }
      guard let toFrame = self.updatedCloseFrame?() else {
        self.close(animated: true, toBottom: true)
        return
      }
      self.close(fromRect: fromFrame, toRect: toFrame)
    }
  }
  
  // MARK: - addToActiveVC
  private func addToActiveVC(){
    ///ensure not presented anymore
    if overlayVC.view.superview != nil { removeFromActiveVC()}
    /// config the shade layer
    shadeView = UIView()
    shadeView?.backgroundColor = shadeColor
    shadeView!.alpha = 0.0
    activeVC.addChild(overlayVC)
    overlayVC.beginAppearanceTransition(true, animated: false)
    activeVC.view.addSubview(shadeView!)
    pin(shadeView!, to: activeVC.view)
    contentView = overlayVC.view
    ///configure the overlay vc (TBD::may also create a new one?!)
    let overlayView = UIView()
    overlayView.isHidden = true
    self.overlayView = overlayView
    /// add the pan
    
    
    if enablePinchAndPan {
      let pinchGestureRecognizer
        = UIPinchGestureRecognizer(target: self,
                                   action: #selector(didPinchWith(gestureRecognizer:)))
      let panGestureRecognizer
        = UIPanGestureRecognizer(target: self,
                                 action: #selector(didPanWith(gestureRecognizer:)))
      
      overlayView.addGestureRecognizer(panGestureRecognizer)
      overlayView.addGestureRecognizer(pinchGestureRecognizer)
      pinchGestureRecognizer.delegate = self
    } else {
      let tapToCloseGestureRecognizer
            = UITapGestureRecognizer(target: self,
                                     action: #selector(didTapBackgroundToClose(gestureRecognizer:)))
      overlayView.addGestureRecognizer(tapToCloseGestureRecognizer)
    }
    
    //    overlayView.delegate = self
    overlayView.alpha = 1.0
    //    if let size = overlaySize {
    //      overlayView.pinSize(size)
    //    }else{
    overlayView.frame = activeVC.view.frame
    //
    //    }
    overlayView.clipsToBounds = true
    ///configure the overlay vc and add as child vc to active vc
    if let overlaySize = overlaySize {
      contentView = UIView()
      contentView!.addSubview(self.overlayVC.view)
      self.overlayVC.view.pinSize(overlaySize)
      
    }
//    activeVC.addChild(overlayVC)DOUBLE!
    overlayView.addSubview(contentView!)
    pin(contentView!, to: overlayView)
    if overlaySize == nil {
      overlayVC.view.frame = activeVC.view.frame
    }
    activeVC.view.addSubview(overlayView)
    //ToDo to/toSafe/frame.....
    //the ChildOverlayVC likes frame no autolayout
    //for each child type the animation may needs to be fixed
    //Do make it niche for ImageCollection VC for now!
    //set overlay view's origin if size given: center
    if overlaySize != nil {
      pin(overlayVC.view.centerX, to: contentView!.centerX)
      pin(overlayVC.view.centerY, to: contentView!.centerY)
      contentView?.setNeedsLayout()
      contentView?.layoutIfNeeded()
    }
    
    let constr = pin(overlayView, toSafe: activeVC.view)
    if let offset = bottomOffset {
      constr.bottom?.isActive = false
      pin(overlayView.bottom, to: activeVC.view.bottom, dist: -offset)
    }
    
    overlayVC.endAppearanceTransition()
    overlayVC.didMove(toParent: activeVC)
    
    if let ct = overlayVC as? OverlayChildViewTransfer {
      ct.delegate.addToOverlayContainer(overlayView)
    }
    
    if let elms = (overlayVC as? AccessibilityTargetsProvider)?.accessibilityViews,
        elms.count > 0 {
      activeVC.accessibilityElements = elms
    }
  }

  
  // MARK: showWithoutAnimation
  private func showWithoutAnimation(){
    addToActiveVC()
    self.overlayVC.view.isHidden = false
    shadeView?.alpha = CGFloat(self.maxAlpha)
    overlayView?.isHidden = false
    closeAction = {self.close(animated: false)}
  }
    
  // MARK: open animated
  public func open(animated: Bool, fromBottom: Bool, completion: (() -> Void)? = nil) {
    addToActiveVC()
    closeAction = { self.close(animated: animated, toBottom: fromBottom) }
    guard animated,
      let contentView = contentView,
      let targetSnapshot
      = contentView.snapshotView(afterScreenUpdates: true)  else {
        showWithoutAnimation()
        return
    }
    targetSnapshot.alpha = 0.0
    
    if fromBottom {
      targetSnapshot.frame = activeVC.view.frame
      targetSnapshot.frame.origin.y += targetSnapshot.frame.size.height
    }
    overlayVC.view.accessibilityViewIsModal = true
    overlayVC.view.isHidden = true
    overlayView?.addSubview(targetSnapshot)
    shadeView?.alpha = 0.0
    overlayView?.isHidden = false
    UIView.animate(withDuration: openDuration, animations: {[weak self] in
      if fromBottom {
        targetSnapshot.frame.origin.y = 0
      }
      self?.shadeView?.alpha = self?.maxAlpha ?? 0.8
      targetSnapshot.alpha = 1.0
    }) {[weak self] (success) in
      self?.overlayVC.view.isHidden = false
      targetSnapshot.removeFromSuperview()
      ///notification did not work, focus stays in Background not for layoutChanged or screenChanged
      ///UIAccessibility.post(notification: .layoutChanged,   argument: self?.overlayVC.view)
      self?.overlayVC.view.accessibilityViewIsModal = true
      self?.activeVC.view.isAccessibilityElement = false
      onMainAfter { completion?() }
    }
  }
  
  // MARK: open fromView toView
  public func openAnimated(fromView: UIView, toView: UIView) {
    addToActiveVC()
    
    let convSourceFrame = activeVC.view.getConvertedFrame(fromView)
    
    var fromFrame = convSourceFrame ?? fromView.frame
    
    guard let fromSnapshot = activeVC.view.resizableSnapshotView(from: fromFrame, afterScreenUpdates: false, withCapInsets: .zero) else {
      showWithoutAnimation()
      return
    }
    
    if toView.frame == .zero {
      overlayVC.view.setNeedsUpdateConstraints()
      overlayVC.view.setNeedsLayout()
      overlayVC.view.updateConstraintsIfNeeded()
      overlayVC.view.layoutIfNeeded()
    }
    
    guard let targetSnapshot = toView.snapshotView(afterScreenUpdates: true) else {
      showWithoutAnimation()
      return
    }
    let toFrame = toView.frame
    targetSnapshot.frame = toView.frame
    overlayVC.view.isHidden = true
    overlayView?.isHidden = false
    targetSnapshot.alpha = 0.0
    
    if debug {
      overlayView?.layer.borderColor = UIColor.green.cgColor
      overlayView?.layer.borderWidth = 2.0
      
      fromSnapshot.layer.borderColor = UIColor.red.cgColor
      fromSnapshot.layer.borderWidth = 2.0
      
      targetSnapshot.layer.borderColor = UIColor.blue.cgColor
      targetSnapshot.layer.borderWidth = 2.0
      
      contentView?.layer.borderColor = UIColor.orange.cgColor
      contentView?.layer.borderWidth = 2.0
      
      print("fromSnapshot.frame:", fromSnapshot.frame)
      print("targetSnapshot.frame:", toFrame)
    }
    
    fromSnapshot.layer.masksToBounds = true
    fromFrame.origin.y = fromFrame.origin.y - (overlayView?.frame.origin.y ?? 0)
    
    fromSnapshot.frame = fromFrame
    targetSnapshot.frame = fromFrame
    
    closeAction = {
      self.close(fromRect: toFrame, toRect: fromFrame)
      fromView.alpha = 0.0
      fromView.isHidden = false
      UIView.animate(seconds: 0.6) {
        fromView.alpha = 1.0
      }
    }
    
    overlayView?.addSubview(fromSnapshot)
    overlayView?.addSubview(targetSnapshot)
    
    fromView.isHidden = true
    
    UIView.animateKeyframes(withDuration: 0.6, delay: 0, animations: {
      UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.3) {
        self.shadeView?.alpha = CGFloat(self.maxAlpha)
        
      }
      UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 5.0) {
        fromSnapshot.alpha = 0.0
      }
      UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 1.0) {
        targetSnapshot.frame = toFrame
        targetSnapshot.alpha = 1.0
      }
      
    }) { (success) in
      self.contentView?.isHidden = false
      targetSnapshot.removeFromSuperview()
      fromSnapshot.removeFromSuperview()
    }
  }

  
  // MARK: open fromFrame
  /// open the overlay view animated, use snapshot from source/background view
  /// - Parameters:
  ///   - fromFrame: source frame for source snapshot
  ///   - toFrame: target frame for overlay view
  ///   - snapshot: provided snapshot, otherwise a new one will be created from source view with source frame
  ///   - noTargetSnapshot: do not animate target snapshot, show target view without previous snapshot of it
  public func openAnimated(fromFrame: CGRect,
                           toFrame: CGRect,
                           snapshot: UIView? = nil,
                           animateTargetSnapshot : Bool = true) {
    addToActiveVC()
    closeAction = { self.close(fromRect: toFrame, toRect: fromFrame) }
    
    var snapshot = snapshot
    
    if snapshot == nil {
      snapshot = activeVC.view.resizableSnapshotView(from: fromFrame,
                                                     afterScreenUpdates: false,
                                                     withCapInsets: .zero)
    }
    
    guard let fromSnapshot = snapshot else {
      showWithoutAnimation()
      return
    }
    
    var targetSnapshot : UIView?
    
    if animateTargetSnapshot {
      guard let snap = overlayVC.view.snapshotView(afterScreenUpdates: true) else {
        showWithoutAnimation()
        return
      }
      targetSnapshot = snap
    }
    
    self.contentView?.isHidden = true
    overlayView?.isHidden = false
    targetSnapshot?.alpha = 0.0
    
    if debug {
      overlayView?.layer.borderColor = UIColor.green.cgColor
      overlayView?.layer.borderWidth = 2.0
      
      fromSnapshot.layer.borderColor = UIColor.red.cgColor
      fromSnapshot.layer.borderWidth = 2.0
      
      targetSnapshot?.layer.borderColor = UIColor.blue.cgColor
      targetSnapshot?.layer.borderWidth = 2.0
      
      contentView?.layer.borderColor = UIColor.orange.cgColor
      contentView?.layer.borderWidth = 2.0
      
      print("fromSnapshot.frame:", fromSnapshot.frame)
      print("targetSnapshot.frame:", toFrame)
    }
    
    fromSnapshot.layer.masksToBounds = true
    
    var fromFrame = fromFrame
    fromFrame.origin.y -= overlayView?.frame.origin.y ?? 0
    fromSnapshot.frame = fromFrame
    
    fromSnapshot.contentMode = .scaleAspectFit
    
    overlayView?.addSubview(fromSnapshot)
    if let ts = targetSnapshot {
      overlayView?.addSubview(ts)
    }
    
    
    let ratio = animateTargetSnapshot ? 1.0 : 0.7
    
    UIView.animateKeyframes(withDuration: openDuration*ratio, delay: 0, animations: {
            
      UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.3/ratio) {
        self.shadeView?.alpha = CGFloat(self.maxAlpha)
      }
      UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.7/ratio) {
        fromSnapshot.frame = toFrame
      }
      
      if animateTargetSnapshot == false { return }
      
      UIView.addKeyframe(withRelativeStartTime: 0.7/ratio, relativeDuration: 0.15/ratio) {
        targetSnapshot?.alpha = 1.0
      }
      UIView.addKeyframe(withRelativeStartTime: 0.85/ratio, relativeDuration: 0.15/ratio) {
        fromSnapshot.alpha = 0.0
      }
      
    }) { (success) in
      self.contentView?.isHidden = false
      targetSnapshot?.removeFromSuperview()
      fromSnapshot.removeFromSuperview()
    }
  }
  
  // MARK: - removeFromActiveVC
  private func removeFromActiveVC(){
    overlayVC.willMove(toParent: nil)
    overlayVC.beginAppearanceTransition(false, animated: false)
    shadeView?.removeFromSuperview()
    shadeView = nil
    overlayVC.view.removeFromSuperview()
    if let ct = overlayVC as? OverlayChildViewTransfer {
      ct.delegate.removeFromOverlay()
    }
    overlayView?.removeFromSuperview()
    overlayVC.endAppearanceTransition()
    overlayView = nil
    overlayVC.removeFromParent()
    
    if let accessibilityElements
        = (activeVC as? AccessibilityTargetsProvider)?.accessibilityViews {
      activeVC.accessibilityElements = accessibilityElements
      //debug(">>> restore acc with \(accessibilityElements.count) elements")
    }
    closing = false
    self.onCloseHandler?()
    self.closeAction = nil
  }
  
  // MARK: close
  var preventRecursive = false
  public func close(animated: Bool) {
    if preventRecursive {
      close(animated: false, toBottom: false)
    }
    else if let action = closeAction {
      preventRecursive = true
      action()
      preventRecursive = false
    } else {
      close(animated: true, toBottom: false)
    }
  }
  
  var closing = false
  // MARK: close to bottom
  public func close(animated: Bool, toBottom: Bool = false) {
    if animated == false {
      removeFromActiveVC()
      return;
    }
    if closing { return }
    closing = true
    UIView.animate(withDuration: closeDuration, animations: {
      self.shadeView?.alpha = 0
      self.overlayView?.alpha = 0
      if toBottom {
        self.contentView?.frame.origin.y
        = CGFloat(self.shadeView?.frame.size.height ?? 0.0)
      }
    }, completion: { _ in
      self.removeFromActiveVC()
      self.overlayView?.alpha = 1
    })
  }
  
  // MARK: close fromRect toRect
  public func close(fromRect: CGRect, toRect: CGRect) {
    guard let overlaySnapshot = overlayVC.view.resizableSnapshotView(from: fromRect, afterScreenUpdates: false, withCapInsets: .zero) else {
      self.close(animated: true)
      return
    }
    
    var toRect = toRect
    
    if let updatedFrame = self.updatedCloseFrame?() {
      toRect = updatedFrame
    }
    
    overlaySnapshot.contentMode = .scaleAspectFit
    
    
    if debug {
      print("todo close fromRect", fromRect, "toRect", toRect)
      overlaySnapshot.layer.borderColor = UIColor.magenta.cgColor
      overlaySnapshot.layer.borderWidth = 2.0
    }
    toRect.origin.y -= overlayView?.frame.origin.y ?? 0
    overlaySnapshot.frame = fromRect
    overlaySnapshot.contentMode = .scaleAspectFill
    overlayView?.addSubview(overlaySnapshot)
    if closing { return }
    closing = true
    UIView.animateKeyframes(withDuration: closeDuration, delay: 0, animations: {
      UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.1) {
        self.contentView?.alpha = 0.0
      }
      UIView.addKeyframe(withRelativeStartTime: 0.1, relativeDuration: 0.7) {
        overlaySnapshot.frame = toRect
        
      }
      UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2) {
        overlaySnapshot.alpha = 0.0
      }
      UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 1) {
        self.shadeView?.alpha = 0.0
      }
    }) { (success) in
      self.removeFromActiveVC()
      self.overlayView?.alpha = 1.0
      self.contentView?.alpha = 1.0
    }
  }
  
  // MARK: shrinkTo rect
  public func shrinkTo(rect: CGRect) {
    /** TBD OVERLAY SIZE **/
    //    if let fromRect = overlaySize TBD {
    //          close(fromRect: fromRect, toRect: rect)
    //    }
    close(fromRect: overlayVC.view.frame, toRect: rect)
  }
  // MARK: shrinkTo targetView
  public func shrinkTo(view: UIView) {
    if !view.isDescendant(of: activeVC.view) {
      self.close(animated: true)
      return;
    }
    /** TBD OVERLAY SIZE **/
    //    if let fromRect = overlaySize TBD {
    //          close(fromRect: fromRect, toRect: rect)
    //    }
    
    close(fromRect: overlayVC.view.frame, toRect: activeVC.view.convert(view.frame, from: view))
  }
  
  
  var otherGestureRecognizersScrollView : UIScrollView?
  // MARK: - UIGestureRecognizerDelegate
  public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    
    if let sv = otherGestureRecognizer.view as? UIScrollView {
      otherGestureRecognizersScrollView = sv
    }
    return true
  }
  
  // MARK: - didPanWith
  var panStartY:CGFloat = 0.0
  @IBAction func didPanWith(gestureRecognizer: UIPanGestureRecognizer) {
    let translatedPoint = gestureRecognizer.translation(in: overlayView)
    
    if gestureRecognizer.state == .began {
      panStartY = gestureRecognizer.location(in: overlayView).y
        + translatedPoint.y
    }
    
    contentView?.frame.origin.y = translatedPoint.y > 0 ? translatedPoint.y : translatedPoint.y*0.4
    contentView?.frame.origin.x = translatedPoint.x*0.4
    let p = translatedPoint.y/(overlayView?.frame.size.height ?? 0-panStartY)
    if translatedPoint.y > 0 {
      debug ? print("panDown... ",self.shadeView?.alpha as Any, (1 - p), p, self.maxAlpha) : ()
      self.shadeView?.alpha = max(0, min(1-p, CGFloat(self.maxAlpha)))
    }
    
    if gestureRecognizer.state == .ended {
      debug ? print("ended... ",self.shadeView?.alpha as Any, (1 - p), p, self.maxAlpha) : ()
      if 2*p > closeRatio {
        closeAction?()
        self.close(animated: true, toBottom: true)
      }
      else {
        UIView.animate(seconds: closeDuration) {
          self.contentView?.frame.origin = .zero
          self.shadeView?.alpha = CGFloat(self.maxAlpha)
        }
      }
    }
  }
  
  // MARK: - didPinchWith
  var pinchStartTransform: CGAffineTransform?
  let panCloseRatio:CGFloat = 0.7 //ensure not 1!!
  let panShadowRatio:CGFloat = 0.4 //ensure not 1!!
  var canCloseOnEnd = false
  var widthToClose : CGFloat?
  var heightToClose : CGFloat?
  var _a : CGFloat = 0.0
  var _b : CGFloat = 0.0
  @IBAction func didPinchWith(gestureRecognizer: UIPinchGestureRecognizer) {
    if let sv = otherGestureRecognizersScrollView {
      if gestureRecognizer.state == .began {
        if UIDevice.isLandscape {
          heightToClose = panCloseRatio * sv.frame.size.height
          widthToClose = nil
          _a = 1/((1-panShadowRatio)*sv.frame.size.height)
        } else {
          heightToClose = nil
          widthToClose = panCloseRatio * sv.frame.size.width
          _a = 1/((1-panShadowRatio)*sv.frame.size.width)
        }
        _b = 1+1/(panShadowRatio-1)
        canCloseOnEnd = false
      }
      else if gestureRecognizer.state == .ended {
        if canCloseOnEnd {
          self.close(animated: true)
        } else {
          UIView.animate(withDuration: closeDuration, animations: { [weak self] in
            guard let self = self else { return }
            self.shadeView?.alpha = CGFloat(self.maxAlpha)
          })
        }
      }
      else if gestureRecognizer.state == .changed {
        if let minH = heightToClose {
          /// Hack: use scrollviews contentSize height did not change on pinch close only on pinchOpen
          /// width worked, may because of center and pinned contentView
          /// if its not a propper solution calculate alpha with the relation of started and current width
          let currH = sv.subviews.first?.frame.size.height ?? sv.contentSize.height
          canCloseOnEnd = currH < minH
          self.shadeView?.alpha = max(0.0, min(CGFloat(self.maxAlpha),currH*_a + _b))
        }
        else if let minW = widthToClose {
          let currW = sv.contentSize.width
          canCloseOnEnd = currW < minW
          self.shadeView?.alpha = max(0.0, min(CGFloat(self.maxAlpha),currW*_a + _b))
        }
      }
      return;
    }
    ///handle pinch for non inner ScrollView ...do the zoom out here!
    guard gestureRecognizer.view != nil else { return }
    if gestureRecognizer.state == .began {
      pinchStartTransform = gestureRecognizer.view?.transform
    }
    
    if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
      gestureRecognizer.view?.transform = (gestureRecognizer.view?.transform.scaledBy(x: gestureRecognizer.scale, y: gestureRecognizer.scale))!
      gestureRecognizer.scale = 1.0
    }
    else if gestureRecognizer.state == .ended {
      if gestureRecognizer.view?.transform.a ?? 1.0 < closeRatio {
         self.close(animated: true)
      }
      else if(self.pinchStartTransform != nil){
        UIView.animate(seconds: closeDuration) {
          gestureRecognizer.view?.transform = self.pinchStartTransform!
        }
      }
    }
  }
}

// MARK: - OverlayChildViewTransfer
public protocol OverlayChildViewTransfer {
  var delegate : OverlayChildViewTransfer { get }
  /// add and Layout to Child Views
  func addToOverlayContainer(_ container:UIView?)
  ///optional
  func removeFromOverlay()
}

extension OverlayChildViewTransfer{
  public var delegate : OverlayChildViewTransfer { get { return self }}
  public func addToOverlayContainer(_ container:UIView?){}
  public func removeFromOverlay(){}
}


// MARK: ext:ZoomedImageView
extension ZoomedImageView : OverlayChildViewTransfer{
  /// add and Layout to Child Views
  public func addToOverlayContainer(_ container:UIView?){
    guard let container = container else { return }
    container.addSubview(xButton)
    pin(xButton.right, to: container.rightGuide(), dist: -15)
    pin(xButton.top, to: container.topGuide(), dist: 15)
  }
  ///optional
  public func removeFromOverlay(){
    self.xButton.removeFromSuperview()
    self.scrollView.zoomScale = self.scrollView.minimumZoomScale
  }
}

// MARK: ext:ImageCollectionVC
extension ImageCollectionVC : OverlayChildViewTransfer{
  /// add and Layout to Child Views
  public func addToOverlayContainer(_ container:UIView?){
    guard let container = container else { return }
    self.collectionView.backgroundColor = .clear
    container.addSubview(xButton)
    pin(xButton.right, to: container.rightGuide(), dist: -15)
    pin(xButton.top, to: container.topGuide(), dist: 15)
    if let pc = self.pageControl {
      container.addSubview(pc)
      pin(pc.centerX, to: container.centerX)
      // Example values for dist to bottom and height
      pin(pc.bottom, to: container.bottomGuide(), dist: -15)
    }
  }
  
  ///optional
  public func removeFromOverlay(){
    self.xButton.removeFromSuperview()
    self.pageControl?.removeFromSuperview()
  }
}

// MARK: - didTapBackgroundToClose
extension Overlay {
  @IBAction func didTapBackgroundToClose(gestureRecognizer: UITapGestureRecognizer){
   self.close(animated: true)
  }
}

