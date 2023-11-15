//
//  Alert.swift
//
//  Created by Norbert Thies on 28.02.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

/// Add option to store dismiss Handler/completion for actionSheet Function as nested class
public class AlertController : UIAlertController {
  fileprivate var onDisappearClosures: [()->()] = []
  
  /// Define closure to call when a cell is newly displayed
  public func onDisappear(closure: (()->())?) {
    guard let cl = closure else { return }
    onDisappearClosures += cl
  }
  
  public override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    for cl in onDisappearClosures { cl() }
    onDisappearClosures = []
  }
}


/// A wrapper around some UIAlertController using static methods
open class Alert {
  public static var sharedAlertTintColor:UIColor?
  
  /// Popup message to user
  public static func message(title: String? = nil,
                             message: String,
                             presentationController: UIViewController? = nil,
                             closure: (()->())? = nil
                             ) {
    self.message(title: title,
                 message: message,
                 additionalActions: nil,
                 presentationController: presentationController,
                 closure: closure)
  }
  
  public static func message(title: String? = nil,
                             message: String,
                             additionalActions : [UIAlertAction]? = nil,
                             presentationController: UIViewController? = nil,
                             closure: (()->())? = nil) {
    var actions = additionalActions ?? []
    let okButton = UIAlertAction(title: "OK", style: .cancel) { _ in closure?() }
    actions.append(okButton)
    self.message(title: title,
                 message: message,
                 actions: actions,
                 presentationController: presentationController)
  }
  
  public static func message(title: String? = nil,
                             message: String,
                             actions : [UIAlertAction],
                             aditionalView: UIView? = nil,
                             presentationController: UIViewController? = nil) {
    onMain {
      let alert = AlertController(title: title, message: message, preferredStyle: .alert)
      for action in actions {
        alert.addAction(action)
      }
      if let aditionalView = aditionalView {
//        alert.view.addSubview(aditionalView)
        alert.addTextField { tf in
          let layer = UIView()
          layer.backgroundColor = .red
          layer.onTapping { _ in
            layer.backgroundColor = .green
          }
          tf.borderStyle = .none
          tf.addSubview(layer)
          pin(layer, to: tf)
        }
//        let target: UIView = alert.textFields?.first ?? alert.view
//        pin(aditionalView.left, to: target.left)
//        pin(aditionalView.right, to: target.right)
//        pin(aditionalView.bottom, to: target.bottom)
      }
      let target = presentationController ?? UIViewController.top()
      target?.present(alert, animated: true, completion: nil)
    }
  }
  
  /// Ask the user for confirmation (as action sheet)
  public static func confirm(title: String? = nil,
                             message: String,
                             okText: String = "OK",
                             cancelText: String = "Abbrechen",
                             isDestructive: Bool = false,
                             presentationController: UIViewController? = nil,
                             closure: ((Bool)->())?) {
    onMain {
      var okStyle: UIAlertAction.Style = .default
      if isDestructive { okStyle = .destructive }
      //Prevent Line Break if no title given
      //message ist automatic title (bold) if no title given!
      let popupMessage = title==nil ? message : "\n\(message)"
      let alert = AlertController(title: title, message:popupMessage , preferredStyle: .alert)
      if let tint = Alert.sharedAlertTintColor {
        alert.view.tintColor = tint
      }
      
      let okButton = UIAlertAction(title: okText, style: okStyle) { _ in closure?(true) }
      let cancelButton = UIAlertAction(title: cancelText, style: .cancel) { _ in closure?(false) }
      alert.addAction(okButton)
      alert.addAction(cancelButton)
      //present even if there is still a modal View presented
      let target = presentationController ?? UIViewController.top()
      target?.present(alert, animated: true, completion: nil)
    }
  }

  /// Generates a UIAlertAction
  public static func action(_ title: String, style: UIAlertAction.Style = .default, 
                            closure: @escaping (String)->()) -> UIAlertAction {
    return UIAlertAction(title: title, style: style) {_ in closure(title) }
  }

  /// Presents an action sheet with a number of buttons
  public static func actionSheet(title: String? = nil, message: String? = nil,
                                 actions: [UIAlertAction], completion : (()->())? = nil)  {
    
    onMain {
      var msg: String? = nil
      if let message = message { msg = "\n\(message)" }
      //Use Alert on iPad due provide popoverPresentationControllers Source view is unknown
      let style : UIAlertController.Style = Device.singleton == .iPad ? .alert : .actionSheet
      let alert = AlertController(title: title, message: msg, preferredStyle: style)
      let cancelButton = UIAlertAction(title: "Abbrechen", style: .cancel)
      alert.onDisappear(closure: completion)
      for a in actions { alert.addAction(a) }
      alert.addAction(cancelButton)
      UIViewController.top()?.present(alert, animated: true, completion: nil)
    }
  }

  /// Presents an action sheet with a number of buttons
  public static func actionSheet(title: String? = nil, message: String? = nil, 
                                 actions: UIAlertAction...) {
    actionSheet(title: title, message: message, actions: actions)
  }
  
} // Alert


public extension UIAlertController {
  func defaultStyle(){
    if let col = Alert.sharedAlertTintColor {
      self.view.tintColor = col
    }
  }
}
