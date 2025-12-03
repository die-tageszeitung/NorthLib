//
//  Specifications.swift
//
//  Created by Norbert Thies on 25.05.20.
//  Copyright © 2020 Norbert Thies, Ringo Müller. All rights reserved.
//

import UIKit

/**
 A ZoomedImageView presents an Image in an ImageView that is scrollable
 and zoomable.
 
 It consists of an ImageView managed by a ScrollView and an additional x-shaped
 button which may be used to terminate the ImageView. The button is only visible
 when a closure is defined that is called when the button has been pressed.
 
 The ImageView displays an OptionalImage. If the main image is available, zooming
 and scrolling of that image is enabled. Initially the image is sized and
 positioned so that it is completely visible but couldn't be enlarged without
 cropping a part of the image. If the main image is not available, the waiting image
 is displayed without being zoomable or scrollable and a spinner is shown in
 the centre of the view.
 
 If the main image is displayed a double tap either enlarges the image so that
 its resolution matches the resolution of the screen or (if already enlarged)
 it is shrinked to its initial size and position.
 */
public protocol ZoomedImageViewSpec where Self: UIView {
  /// The scrollview managing the ImageView
  var scrollView: UIScrollView { get }
  /// The Imageview displaying either the main or the waiting image
  var imageView: UIImageView { get }
  /// The image to display
  var optionalImage: OptionalImage? { get set }
  /// The X-Button (may be used to close the ZoomedImageView)
  var xButton: Button<CircledXView> { get }
  // Spinner indicating activity if !OptionalImage.isAvailable
  var spinner: UIActivityIndicatorView { get }
  /// The context menu to display
  var menu: ContextMenu { get }
  
  /// Initialize with optional image, displays the main image if available.
  /// Otherwise the waiting image is displayed and via 'whenAvailable' a closure
  /// is defined to replace the waiting image with the main image (when it is available)
  init(optionalImage: OptionalImage?)
  
  /// Define closure to call when the X-Button is pressed
  func onX(closure: @escaping ()->())
  
  /// Define closure to call when the user is zooming beyond the resolution
  /// of the image. 'zoomFactor' defines the maximum zoom after which a higher
  /// resolution image is requested.
  func onHighResImgNeeded(zoomFactor: CGFloat,
                          closure: ((OptionalImage, @escaping (Bool) -> ()) -> ())?)
  
  /// Defines a closure to call when the user has tapped into the image.
  /// The coordinates passed to the closure are relative content size 
  /// coordinates: 0 <= x,y <= 1
  func onTap(closure: ((OptionalImage, Double, Double) -> ())?)
  
  func whenScrolled( minRatio: CGFloat, _ closure: @escaping (CGFloat)->() )
  
  func invalidateLayout()
}

public protocol ModalCloseable where Self: UIViewController {
  var xButton: Button<ImageView> { get }
}

public extension ModalCloseable {
  static var buttonDist: CGFloat{
    return UIWindow.size.width < 370
    ? CGFloat(13.0)
    : CGFloat(15.0)
  }
  
  func setupXButtonIfNeeded(targetView:UIView,
                            topDist:CGFloat = buttonDist,
                            rightDist:CGFloat = buttonDist){
    if xButton.superview != nil { return }
    targetView.addSubview(xButton)
    pin(xButton.right, to: targetView.right, dist: -rightDist)
    pin(xButton.top, to: targetView.top, dist: topDist)
    xButton.onPress { [weak self] _ in
      guard let self = self else { return }
      self.navigationController?.dismiss(animated: true)
    }
  }
}


public extension ZoomedImageViewSpec {
  
  /// This closure is called when the X-Button has been pressed
  func onX(closure: @escaping ()->()) {
    xButton.isHidden = false
    xButton.onPress {_ in closure() }
  }
  
  /// Setup the xButton
  func setupXButton() {
    xButton.pinHeight(35)
    xButton.pinWidth(35)
    xButton.color = .black
    xButton.buttonView.isCircle = true
    xButton.buttonView.circleColor = UIColor.rgb(0xdddddd)
    xButton.buttonView.color = UIColor.rgb(0x707070)
    xButton.buttonView.innerCircleFactor = 0.5
    self.addSubview(xButton)
    pin(xButton.right, to: self.rightGuide(), dist: -15)
    pin(xButton.top, to: self.topGuide(), dist: 15)
    xButton.isHidden = true
  }
  
  /// Setup the spinner
  func setupSpinner() {
    spinner.style = .large
    spinner.color = .white
    spinner.hidesWhenStopped = true
    addSubview(spinner)
    pin(spinner.centerX, to: self.centerX)
    pin(spinner.centerY, to: self.centerY)
    self.bringSubviewToFront(spinner)
  }
    
} // ZoomedImageViewSpec

/**
 An ImageCollectionVC utilizes PageCollectionVC to show a collection of ZoomedImageViews.
 
 After being initialized the attribute 'images' is set to contain an array of
 OptionalImageItem. The attribute 'index' (from PageCollectionVC) is used to point
 to that image which is to display on the screen. Each zoomable image fills the complete
 space of ImageCollectionVCs view. Hence the size of every cell of the collection
 view is identical to the size of the collection view's self.view.
 ImageCollectionVC displays an xButton alike ZoomedImageView's xButton which by default
 (no 'onX' closure was specified) performs
    self.navigationController?.popViewController(animated: true)
       or
    self.presentingViewController.dismiss(...)
 if the X has been tapped.
 
 To indicate on which page a user is currently positioned a PageControl is displayed
 if there are more than one image. The ImageCollectionVC only updates the pageControl
 attributes:
   currentPage - to indicate which image is displayed
   numberOfPages - to specify how many dots are displayed in total
 In Case of too many Pages, the PageControll dots are cut of at the Edge of the CollectionView. IN that Case we can limit the max shown dots with: pageControlMaxDotsCount. Set pageControlMaxDotsCount = 0 would display all dots no matter if they can be shown.
 */
public protocol ImageCollectionVCSpec where Self: PageCollectionVC {
  
  /// The Images to display
  var images: [OptionalImage] { get set }

  /// The X-Button (may be used to close the ImageCollectionVC)
  var xButton: Button<CircledXView> { get }
  
  /// The PageControl used to display an indicator of how many images are available
  /// set nil to disable
  var pageControl: UIPageControl? { get set }
  
  /// Max count of dots in pageControl, set to 0 show all dots
  var pageControlMaxDotsCount: Int { get set}
  
  /// The color used for pageControl
  var pageControlColors: (current: UIColor?, other: UIColor?) { get set }
  
  /// Define closure to call when the user is zooming beyond the resolution
  /// of the image. 'zoomFactor' defines the maximum zoom after which a higher
  /// resolution image is requested.b
  func onHighResImgNeeded(zoomFactor: CGFloat,
                          closure: ((OptionalImage, @escaping (Bool) -> ()) -> ())?)
  
  /// Defines a closure to call when the user has tapped into the image.
  /// The coordinates passed to the closure are relative content size
  /// coordinates: 0 <= x,y <= 1
  func onTap(closure: ((OptionalImage, Double, Double) -> ())?)
  
} // ImageCollectionVC

public extension ImageCollectionVCSpec {
  /// Setup the xButton
  func setupXButton() {
    xButton.pinHeight(35)
    xButton.pinWidth(35)
    xButton.color = .black
    xButton.buttonView.isCircle = true
    xButton.buttonView.circleColor = UIColor.rgb(0xdddddd)
    xButton.buttonView.color = UIColor.rgb(0x707070)
    xButton.buttonView.innerCircleFactor = 0.5
    self.view.addSubview(xButton)
    pin(xButton.right, to: self.view.rightGuide(), dist: -15)
    pin(xButton.top, to: self.view.topGuide(), dist: 15)
    xButton.isHidden = UIAccessibility.isVoiceOverRunning == false
  }
  
  /// An example of setting up the PageControl
  func setupPageControl() {
    guard let pageControl = self.pageControl else { return }
    pageControl.hidesForSinglePage = true
    pageControl.isUserInteractionEnabled = false
    self.view.addSubview(pageControl)
    pin(pageControl.centerX, to: self.view.centerX)
    // Example values for dist to bottom and height
    pin(pageControl.bottom, to: self.view.bottomGuide(), dist: -15)
    /// Height Pin has no Effect @Test PinHeight 1
    //self.pageControl.pinHeight(1)
    /// PageControl example color, set here would overwrite external set
    //self.pageControlColors = (current: UIColor.rgb(0xcccccc),
    //                           other: UIColor.rgb(0xcccccc, alpha: 0.3))
  }
  
  /// Setting pageControl's colors:
  var pageControlColors: (current: UIColor?, other: UIColor?) {
    get {
      (current: pageControl?.currentPageIndicatorTintColor,
       other: pageControl?.pageIndicatorTintColor)
    }
    set {
      pageControl?.currentPageIndicatorTintColor = newValue.current
      pageControl?.pageIndicatorTintColor = newValue.other
    }
  }
  
} // ImageCollectionVC

/**
 The Overlay class manages the two view controllers 'overlay' and 'active'.
 'active' is currently visible and 'overlay' will be presented on top of
 'active'. To accomplish this, two views are created, the first one, 'shadeView'
 is positioned on top of 'active.view' with the same size and colored 'shadeColor'
 with an alpha between 0...maxAlpha. This view is used to shade the active view
 controller during the open/close animations. The second view, overlayView is
 used to contain 'overlay' and is animated during opening and closing operations.
 In addition two gesture recognizers (pinch and pan) are used on shadeView to
 start the close animation. The pan gesture is used to move the overlay to the
 bottom of shadeView. The pinch gesture is used to shrink the overlay
 in size while being centered in shadeView. When 'overlay' has been shrunk to
 'closeRatio' (see attribute) or moved 'closeRatio * overlayView.bounds.size.height'
 points to the bottom then 'overlay' is animated automatically away from the
 screen. While the gesture recognizers are working or during the animation the
 alpha of shadeView is changed to reflect the animation's ratio (alpha = 0 =>
 'overlay' is no longer visible). The gesture recognizers coexist with gesture
 recognizers being active in 'overlay'.
 */
public protocol OverlaySpec {
  /// The view shading the active view controller
  /// will be put on active vc' view
  /// no Need to be Public & in Spec
  /// var shadeView: UIView? { get }
  /// The view being animated (in the center of shadeView)
  var overlayView: UIView? { get }
  /// The size of overlayView and the overlay (nil => size of shadeView)
  var overlaySize: CGSize? { get set }
  /// Maximum alpha of shadeView
  var maxAlpha: Double { get set }
  /// Color used to shade the active view controller
  var shadeColor: UIColor { get set }
  /// When should the animation start? Eg. 0.5
  var closeRatio: CGFloat { get set }
  
  func onClose(closure: (() -> ())?)
    
  /// initialize with overlay and active view controllers
  init(overlay: UIViewController, into active: UIViewController)
  
  /// open the overlay view controller, ie. present it optionally with an
  /// animation: from the center by default or fromBottom
  func open(animated: Bool, fromBottom: Bool, completion: (() -> Void)?)
  
  /// close the overlay, optionally animated (same type as opening)
  func close(animated: Bool)
  
  /// shrink the overlay to a CGRect, ie. animate it's shrinking to a rect on the
  /// screen and then close it.
  func shrinkTo(rect: CGRect)
  
  /// shrink the overlay to a view and then close it
  func shrinkTo(view: UIView)
  
} // OverlaySpec
