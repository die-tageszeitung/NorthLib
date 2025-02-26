//
//    
//  NorthLib
//
//  Created by Ringo Müller on 27.05.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

// MARK: - OptionalImage (Protocol)
/// An Image with a smaller "Waiting Image"
public protocol OptionalImage {
  /// The main image to display
  var image: UIImage? { get set }
  /// An alternate image to display when the main image is not yet available
  var waitingImage: UIImage? { get set }
  /// Returns true if 'image' is available
  var isAvailable: Bool { get }
  /// Defines a closure to call when the main image becomes available
  func whenAvailable(closure: (()->())?)
}

extension OptionalImage {
  public var isAvailable: Bool { return image != nil }
}

// MARK: - OptionalImageItem : OptionalImage
/// Reference Implementation
open class OptionalImageItem: OptionalImage{
  private var availableClosure: (()->())?
  fileprivate var onUpdatingClosureClosure: (()->())? = nil
  fileprivate var zoomFactorForRequestingHigherResImage : CGFloat = 1.1
  fileprivate var _image: UIImage?
  public var image: UIImage?{
    get { return _image }
    set {
      _image = newValue
      availableClosure?()
    }
  }
  public var waitingImage: UIImage?
  public required init(waitingImage: UIImage? = nil) {
    self.waitingImage = waitingImage
  }
}

// MARK: - OptionalImageItem: Closures
extension OptionalImageItem{
  public func whenAvailable(closure: (()->())?) {
    availableClosure = closure
  }
}
// MARK: -
// MARK: - ZoomedImageView
open class ZoomedImageView: UIView, ZoomedImageViewSpec {
  
  @Default("doubleTapToZoomPdf")
  public var doubleTapToZoomPdf: Bool
  
  deinit { debug("\(self)") }
  public static var isDebug = true
  var isDebugLogging: Bool { Self.isDebug }
  
  var imageViewBottomConstraint: NSLayoutConstraint?
  var imageViewLeadingConstraint: NSLayoutConstraint?
  var imageViewTopConstraint: NSLayoutConstraint?
  var imageViewTrailingConstraint: NSLayoutConstraint?
  var layoutInitialized = false
  
  public var useExtendedLayoutAdjustments = false
  
  private var onHighResImgNeededClosure: ((OptionalImage,
  @escaping (Bool) -> ()) -> ())?
  private var onHighResImgNeededZoomFactor: CGFloat = 1.1
  private var highResImgRequested = false
  private var orientationClosure:OrientationClosure? = OrientationClosure()
  private var singleTapRecognizer : UITapGestureRecognizer?
  public let doubleTapRecognizer = UITapGestureRecognizer()
  private var zoomEnabled :Bool = true {
    didSet{
      self.scrollView.pinchGestureRecognizer?.isEnabled = zoomEnabled
    }
  }
  private var onTapClosure: ((_ image: OptionalImage,
    _ x: Double,
    _ y: Double)->())? = nil {
    didSet{
      if let tap = singleTapRecognizer {
        tap.removeTarget(self, action: #selector(handleSingleTap))
        singleTapRecognizer = nil
      }
      
      if onTapClosure != nil {
        let tap = UITapGestureRecognizer(target: self,
                                         action: #selector(handleSingleTap))
        tap.numberOfTapsRequired = 1
        self.imageView.addGestureRecognizer(tap)
        self.imageView.isUserInteractionEnabled = true
        tap.require(toFail: doubleTapRecognizer)
        singleTapRecognizer = tap
      }
    }
  }
  
  public private(set) var scrollView: UIScrollView = UIScrollView()
  public private(set) var imageView: UIImageView = UIImageView()
  public private(set) var xButton: Button<CircledXView> = Button<CircledXView>()
  public private(set) var spinner: UIActivityIndicatorView = UIActivityIndicatorView()
  public private(set) lazy var menu = ContextMenu(view: imageView, smoothPreviewForImage: true)
  public var optionalImage: OptionalImage?{
    willSet {
      if let itm = optionalImage as? OptionalImageItem {
        itm.onUpdatingClosureClosure = nil
      }
    }
    didSet {
      updateImage()
    }
  }
  
  // MARK: Life Cycle
  public required init(optionalImage: OptionalImage?) {
    self.optionalImage = optionalImage
    super.init(frame: CGRect.zero)
    setup()
  }
  
  override public init(frame: CGRect) {
    fatalError("init(frame:) has not been implemented");
  }
  
  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented");
  }
  
  fileprivate func zoomOutAndCenter() {
    layoutInitialized = false
    self.updateConstraintsForSize(self.bounds.size)
    self.setNeedsLayout()
    self.layoutIfNeeded()
  }
  
  // MARK: layoutSubviews
  open override func layoutSubviews() {
    super.layoutSubviews()
    if !layoutInitialized, self.bounds.size != .zero{
      layoutInitialized = true
      self.updateMinimumZoomScale()
      if self.scrollView.zoomScale != self.scrollView.minimumZoomScale {
        //zoom out if needed
        //triggers scrollViewDidZoom => updateConstraintsForSize
        self.scrollView.zoomScale = self.scrollView.minimumZoomScale
      }
      else {
        //center!
        self.updateConstraintsForSize(self.bounds.size)
      }
    }
  }

  public func invalidateLayout(){
    zoomOutAndCenter()
  }
  
  fileprivate var startDragging: CGPoint? // content y offset at start of dragging
  public var whenScrolledHandler : WhenScrolledHandler?
  public func whenScrolled(minRatio: CGFloat, _ closure: @escaping (CGFloat) -> ()) {
    whenScrolledHandler = (minRatio, closure)
  }
  
  public var whenZoomedHandler : ((_ isZoomIn: Bool) -> ())?
  public func whenZoomed(closure: ((_ isZoomIn: Bool) -> ())?) {
    whenZoomedHandler = closure
  }
}

public typealias WhenScrolledHandler = (minRatio: CGFloat, closure: (CGFloat) -> ())

// MARK: - Setup
extension ZoomedImageView{
  func setup() {
    setupScrollView()
    setupXButton()
    setupSpinner()
    setupDoubleTapGestureRecognizer()
    updateImage()
    orientationClosure?.onOrientationChange(closure: {[weak self] in
      guard let self = self else { return }
      let sv = self.scrollView //local name for shorten usage
      let wasMinZoom = sv.zoomScale == sv.minimumZoomScale
      self.updateMinimumZoomScale()
      if wasMinZoom || sv.zoomScale < sv.minimumZoomScale {
        sv.zoomScale = sv.minimumZoomScale
      }
    })
  }
  
  // MARK: updateImage
  func updateImage() {
    if let oi = optionalImage, oi.isAvailable, let detailImage = oi.image {
      setImage(detailImage)
      zoomEnabled = true
      spinner.stopAnimating()
      self.zoomOutAndCenter()
    }
    else {
      //show waitingImage if detailImage is not available yet
      if let img = optionalImage?.waitingImage {
        setImage(img)
        self.scrollView.zoomScale = 1
        zoomEnabled = false
      } else {
        //Due re-use its needed to unset probably existing old image
        imageView.image = nil
      }
      spinner.startAnimating()
      optionalImage?.whenAvailable { [weak self] in
        guard let self = self else { return }
        if let img = self.optionalImage?.image {
          self.setImage(img)
          self.layoutIfNeeded()
          self.zoomEnabled = true
          self.spinner.stopAnimating()
          //due all previewImages are not allowed to zoom,
          //exchanged image should be shown fully
          self.optionalImage?.whenAvailable(closure: nil)
          //Center
          self.zoomOutAndCenter()
        }
      }
    }
  }
  

  
  // MARK: setupScrollView
  func setupScrollView() {
    imageView.contentMode = .scaleAspectFit
    scrollView.delegate = self
    scrollView.maximumZoomScale = 1.1
    scrollView.zoomScale = 1.0
    ///prevent pinch/zoom smaller than min while pinch
    scrollView.bouncesZoom = true
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.addSubview(imageView)
    addSubview(scrollView)
    pin(scrollView, to: self)
    (imageViewTopConstraint, imageViewBottomConstraint, imageViewLeadingConstraint, imageViewTrailingConstraint) =
      pin(imageView, to: scrollView)
  }
}

// MARK: - Handler
extension ZoomedImageView{
  public func onHighResImgNeeded(zoomFactor: CGFloat = 1.1,
                                 closure: ((OptionalImage,
    @escaping (Bool)-> ()) -> ())?) {
    self.onHighResImgNeededClosure = closure
    self.scrollView.maximumZoomScale = closure == nil ? 1.0 : 2.0
    self.onHighResImgNeededZoomFactor = zoomFactor
  }
}

// MARK: - Menu Handler
extension ZoomedImageView{
  public func addMenuItem(title: String,
                          icon: String,
                          closure: @escaping (Any?) -> ()) {
    menu.addMenuItem(title: title, icon: icon, closure: closure)
  }
}

// MARK: - Tap Recognizer
extension ZoomedImageView{
  public func onTap(closure: ((OptionalImage, Double, Double) -> ())?) {
    self.onTapClosure = closure
  }
  
  // Set up the gesture recognizers for single and doubleTap
  func setupDoubleTapGestureRecognizer() {
    ///double Tap
    doubleTapRecognizer.addTarget(self,
                                  action: #selector(handleDoubleTap))
    doubleTapRecognizer.numberOfTapsRequired = 2
    scrollView.addGestureRecognizer(doubleTapRecognizer)
    doubleTapRecognizer.isEnabled = zoomEnabled
  }
  
  // MARK: Single Tap
  @objc func handleSingleTap(sender: UITapGestureRecognizer){
    let loc = sender.location(in: imageView)
    let size = imageView.frame.size
    guard let closure = onTapClosure else { return }
    guard let oi = self.optionalImage else { return }
    log("Current render Zoom: \((imageView.image?.size.width ?? 0)/UIScreen.main.bounds.size.width) "
        + "Image width: \(imageView.image?.size.width ?? 0) "
        + "CGImage Width: \(imageView.image?.cgImage?.width ?? 0)", logLevel: .Debug)
    closure(oi,
            Double(loc.x / (size.width / scrollView.zoomScale )),
            Double(loc.y / (size.height / scrollView.zoomScale )))
  }
  
  // MARK: Double Tap
  @objc func handleDoubleTap(sender : Any) {
    guard let tapR = sender as? UITapGestureRecognizer else {
      return
    }
    if zoomEnabled == false || doubleTapToZoomPdf == false {
      self.setNeedsLayout()
      self.layoutIfNeeded()
      return
    }
       
    /// On Double Tap if not Min Zoom Scale zoom out to min Zoom Scale + eppsilon
    /// if user manually zoomed for just a bit, to see an effect
    if scrollView.zoomScale > 1.0 {
      scrollView.setZoomScale(1.0, animated: true)
    }
    else if scrollView.zoomScale > scrollView.minimumZoomScale + 0.2 {
      scrollView.setZoomScale(scrollView.minimumZoomScale,
                              animated: true)
      whenZoomedHandler?(false)
    }
    else { ///Otherwise Zoom In in to tap loacation
      let maxZoom = scrollView.maximumZoomScale
      let zoom = (self.optionalImage as? ZoomedPdfImageSpec)?.doubleTapNextZoomStep ?? 2.0
      
      scrollView.maximumZoomScale = zoom
      
      log("double tap zoom to scrollView.maximumZoomScale: \(scrollView.maximumZoomScale)",
          logLevel: .Debug)
      let tapLocation = tapR.location(in: tapR.view)
      let newCenter = imageView.convert(tapLocation, from: scrollView)
      let zoomRect
        = CGRect(origin: newCenter, size: CGSize(width: 1, height: 1))
      scrollView.zoom(to: zoomRect,
                      animated: true)
      scrollView.isScrollEnabled = true
      if maxZoom > 2 { scrollView.maximumZoomScale = maxZoom  }
      whenZoomedHandler?(true)
    }
  }
}

// MARK: - Helper
extension ZoomedImageView{
  
  // MARK: setImage
  fileprivate func setImage(_ image: UIImage) {
    imageView.image = image
    imageView.frame = CGRect(x: imageView.frame.origin.x,
                             y: imageView.frame.origin.y,
                             width: image.size.width,
                             height: image.size.height)
    updateMinimumZoomScale()
  }
  
  // MARK: scrollToTopLeft
  public func scrollToTopLeft(animated:Bool = false){
    self.scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: animated)
  }
  
  // MARK: zoomToFitHeight
  public func zoomToFitHeight(animated:Bool = false){
    let adjustment = useExtendedLayoutAdjustments
                     ? Toolbar.ContentToolbarHeight + UIWindow.verticalInsets
                     : 0
    let heightScale = (self.bounds.size.height - adjustment) / (imageView.image?.size.height ?? 1)
    let minScale = min(heightScale, 1)
    if self.scrollView.zoomScale != minScale {
      self.scrollView.setZoomScale(minScale, animated: animated)
    }
  }
  
  // MARK: zoomToFitWidth
  public func zoomToFitWidth(animated:Bool = false){
    let widthScale = self.bounds.size.width / (imageView.image?.size.width ?? 1)
    let minScale = min(widthScale, 1)
    if self.scrollView.zoomScale != minScale {
      self.scrollView.setZoomScale(minScale, animated: animated)
    }
  }
  
  // MARK: zoomToFitHalfWidth
  public func zoomToFitHalfWidth(animated:Bool = false){
    let widthScale = 2*self.bounds.size.width / (imageView.image?.size.width ?? 2)
    let minScale = min(widthScale, 1)
    if self.scrollView.zoomScale != minScale {
      self.scrollView.setZoomScale(minScale, animated: animated)
    }
  }
  
  func doUpdateMinimumZoomScale(){
    updateMinimumZoomScale()
    zoomOutAndCenter()
  }
  
  // MARK: updateMinimumZoomScale
  fileprivate func updateMinimumZoomScale(){
    let widthScale = self.bounds.size.width / (imageView.image?.size.width ?? 1)
    let adjustment = useExtendedLayoutAdjustments
                     ? Toolbar.ContentToolbarHeight + UIWindow.verticalInsets
                     : 0
    let heightScale = (self.bounds.size.height - adjustment) / (imageView.image?.size.height ?? 1)
    let minScale = min(widthScale, heightScale, 1)
    scrollView.minimumZoomScale = minScale
  }
  // MARK: updateConstraintsForSize
  fileprivate func updateConstraintsForSize(_ size: CGSize) {
    let adjustment = useExtendedLayoutAdjustments
                     ? Toolbar.ContentToolbarHeight + UIWindow.safeInsets.bottom - UIWindow.safeInsets.top
                     : 0
    let yOffset = max(0, (size.height - imageView.frame.height - adjustment) / 2)
    imageViewTopConstraint?.constant = yOffset
    imageViewBottomConstraint?.constant = yOffset
    
    let xOffset = max(0, (size.width - imageView.frame.width) / 2)
    imageViewLeadingConstraint?.constant = xOffset
    imageViewTrailingConstraint?.constant = xOffset
    
    let contentHeight = yOffset * 2 + self.imageView.frame.height
    self.layoutIfNeeded()
    self.scrollView.contentSize = CGSize(width: self.scrollView.contentSize.width, height: contentHeight)
  }
  
  
  // MARK: updateImagewithHighResImage
  func updateImagewithHighResImage(_ image: UIImage) {
    guard let oldImg = imageView.image else {
      self.setImage(image)
      return
    }
    scrollView.isUserInteractionEnabled = false
    let contentOffset = scrollView.contentOffset
    self.setImage(image)
    let newSc = oldImg.size.width * scrollView.zoomScale / image.size.width
    scrollView.zoomScale = newSc
    scrollView.setContentOffset(contentOffset, animated: false)
    self.updateConstraintsForSize(self.bounds.size)
    scrollView.isUserInteractionEnabled = true
  }
}

// MARK: - UIScrollViewDelegate
extension ZoomedImageView: UIScrollViewDelegate{
  public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    return imageView
  }
  
  public func scrollViewDidZoom(_ scrollView: UIScrollView) {
    //Center if needed
    updateConstraintsForSize(self.bounds.size)
    //request high res Image if possible
    if zoomEnabled,
      self.onHighResImgNeededZoomFactor <= scrollView.zoomScale,
      self.highResImgRequested == false,
      let closure = onHighResImgNeededClosure {
      guard let _optionalImage = optionalImage else { return }
      self.highResImgRequested = true
      closure(_optionalImage, { [weak self] success in
        guard let self = self, let oi = self.optionalImage else { return }
        if success, let img = oi.image {
          self.updateImagewithHighResImage(img)
        }
        self.highResImgRequested = false
      })
    }
  }
  
  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    startDragging = scrollView.contentOffset
  }
  
  public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if let sd = startDragging {
      let co = scrollView.contentOffset
      let size = scrollView.bounds.size
      if size.height == 0, size.width == 0 { return }
      
      guard let handler = whenScrolledHandler else { return }
      
      let yRatio = (sd.y - co.y)/size.height
      if abs(yRatio) >= handler.minRatio {
        handler.closure(yRatio)
        startDragging = nil
        return
      }
      
      let xRatio = (sd.x - co.x)/size.width
      if abs(xRatio) >= handler.minRatio {
        handler.closure(xRatio)
        startDragging = nil
        return
      }
    }
    startDragging = nil
  }
}
