//
//  VCExtensions.swift
//
//  Created by Norbert Thies on 01.05.16.
//  Copyright © 2016 Norbert Thies. All rights reserved.
//

import UIKit


public extension UIViewController {
  
  /// Returns the topmost modaly presented ViewController or self if no modal VC is there
  var topmostModalVc : UIViewController {
    get {
      var topmostModalVc : UIViewController = self
      while true {
        if let modal = topmostModalVc.presentedViewController {
          topmostModalVc = modal
        }
        else {
          return topmostModalVc
        }
      }
    }
  }
  
  /// Returns the top most view controller, ie. either the root view controller
  /// or its top most presented view controller
  static var top: UIViewController? {
    if let keyWindow = UIApplication.shared.activeKeyWindow,
       let root = keyWindow.rootViewController {
      return root.topmostModalVc
    }
    return nil
  }
  
  /**
   * `presentSubVC(controller:inView:)` takes a view controller 'controller'
   * and presents it in a subview 'inView' so that all views of 'controller'' are clipped by
   * the bounds of 'inView'.
   * - Parameters:
   *   - controller: the view controller to present
   *   - inView:     the view in which controller is presented (and clipped)
   * - Returns: controller
   */
  @discardableResult
  func presentSubVC(controller ctr: UIViewController,
                    inView view:UIView) -> UIViewController {
    ctr.view.frame = view.bounds
    ctr.willMove(toParent: self)
    view.addSubview(ctr.view)
    view.clipsToBounds = true
    self.addChild(ctr)
    ctr.didMove(toParent: self)
    return ctr
  }
  
  /**
   * `presentSubVC(name:inView:)` reads a view controller named 'name',
   * reads it from the default storyboard and presents it in a subview 'inView' so
   * that all views of 'name'' are clipped by the bounds of 'inView'.
   * - Parameters:
   *   - name:   the name of the view controller to present
   *   - inView: the view in which controller is presented (and clipped)
   * - Returns:
   *   - the view controller if it could be read from the storyboard
   *   - nil if the view controller couldn't be found
   */
  func presentSubVC(name: String, inView view: UIView)
    -> UIViewController? {
      if let ctr = self.storyboard?.instantiateViewController(withIdentifier: name) {
        return presentSubVC(controller: ctr, inView: view)
      }
      else { return nil }
  }
  
  /// removes a subview controller
  func removeSubVC(_ ctr: UIViewController) {
    ctr.willMove(toParent: nil)
    ctr.view.removeFromSuperview()
    ctr.removeFromParent()
  }
  
  /// returns the width of the device's screen
  var screenWidth: CGFloat { return UIScreen.main.bounds.size.width }
  
  /// returns the height of the device's screen
  var screenHeight: CGFloat { return UIScreen.main.bounds.size.height }

  /**
   * `confirm(_:atView:block:)` produces a modal popup box (popover, UIAlert) to
   * ask the user for confirmation. It presents a "yes" and "no" button for the
   * user to select.
   * - Parameters:
   *   - message:  String asking for confirmation
   *   - atView:   view used as anchor for the popover
   *   - block:    closure to call when button is pressed
   */
  func confirm(_ message: String, atView sourceView: UIView,
                block:@escaping (Bool)->()) {
    let actions = UIAlertController.init( title: "Bestätigung",
                                          message: message, preferredStyle: .actionSheet )
    actions.addAction( UIAlertAction.init( title: "Ja", style: .default ) {
      (handler: UIAlertAction) in
      block( true )
    } )
    actions.addAction( UIAlertAction.init( title: "Nein", style: .default ) {
      (handler: UIAlertAction) in
      block( false )
    } )
    actions.popoverPresentationController?.sourceView = sourceView
    actions.popoverPresentationController?.sourceRect =
      CGRect(x: 0, y: 0, width: 0, height: 0)
    present(actions, animated: true, completion: nil)
  }
  
  /**
   * `top` returns the top most view controller
   */
  class func top(controller: UIViewController? = currentRootController)
    -> UIViewController? {
    if let navigationController = controller as? UINavigationController {
      return top(controller: navigationController.visibleViewController)
    }
    if let tabController = controller as? UITabBarController {
      if let selected = tabController.selectedViewController {
        return top(controller: selected)
      }
    }
    if let presented = controller?.presentedViewController {
      return top(controller: presented)
    }
    return controller
  }
    
  /// The App's root view controller
  static var currentRootController: UIViewController? { 
    UIApplication.shared.activeKeyWindow?.rootViewController 
  }
  
  /// check if applications key window root controller is requested type or is navigationcontroller and
  /// contain requested type in its viewControllers property
  /// - Parameter types : type to check
  /// - Returns: true if controller is in navigation/view hirarchy
  class func keyWindowViewControllerContain(_ types: AnyClass...) -> Bool {
    let root = currentRootController
    
    for ctrl in (root as? UINavigationController)?.viewControllers ?? [] {
      for type in types {
        print("\(ctrl) is none of: \(type)")
        if ctrl.isKind(of: type) { return true}
      }
    }
    
    if let rctrl = root {
      for type in types {
        print("2. \(rctrl) is none of: \(type)")
        if rctrl.isKind(of: type) { return true }
      }
    }
    
    return false
  }
  
  
  /**
   loadFromNib instantiates a view controller from a nib file
   */
  class func loadFromNib() -> Self {
    func instantiateFromNib<T: UIViewController>() -> T {
      return T.init(nibName: String(describing: T.self), bundle: nil)
    }    
    return instantiateFromNib()
  }
  
  /**
   Returns true if the view controller is visible
   */
   var isVisible: Bool { return viewIfLoaded?.window != nil }

  /**
   Present a view controller at a certain view or at the view of the top level 
   view controller
   */
  func presentAt(_ view: UIView? = nil, completion: (() -> Void)? = nil) {
    var v: UIView
    var vc: UIViewController
    var rect: CGRect
    if view != nil { 
      v = view!
      if let pvc = v.parentViewController { vc = pvc }
      else { return }
      rect = CGRect(x: v.bounds.size.width/2, y: v.bounds.size.height/2, width: 1, height: 1)
    }
    else {
      vc = UIViewController.top()!
      v = vc.view
      rect = CGRect(x: v.bounds.size.width/2, y: 20, width: 1, height: 1)
    }
    self.popoverPresentationController?.sourceView = v
    self.popoverPresentationController?.sourceRect = rect
    vc.present(self, animated: true, completion: completion)
  }
  
} // extension UIViewController


// MARK: - ext: UIViewController Modal Stack 
extension UIViewController{
  /// dismiss helper for stack of modal presented VC's
  public static func dismiss(stack:[UIViewController], animated:Bool, completion: (() -> Void)?){
    var stack = stack
    let vc = stack.pop()
    vc?.dismiss(animated: animated, completion: {
      if stack.count > 0 {
        UIViewController.dismiss(stack: stack, animated: false, completion: completion)
      } else {
        completion?()
      }
    })
  }
  
  /// helper to find presenting VC for stack of modal presented VC's
  public var rootPresentingViewController : UIViewController {
    get{
      var vc = self
      while true {
        if let pvc = vc.presentingViewController {
          vc = pvc
        }
        return vc
      }
    }
  }
  
  /// helper to find 1st presended VC in stack of modal presented VC's
  public var rootModalViewController : UIViewController? {
    get{
      return self.rootPresentingViewController.presentedViewController
    }
  }
  
  /// helper for stack of modal presented VC's, to get all modal presented VC's below self
  public var modalStack : [UIViewController] {
    get{
      var stack:[UIViewController] = []
      var vc:UIViewController = self
      while true {
        if let pc = vc.presentingViewController {
          stack.append(vc)
          vc = pc
        }
        else {
          return stack
        }
      }
    }
  }
}
