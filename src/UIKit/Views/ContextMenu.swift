//
//  ContextMenu.swift
//
//  Created by Norbert Thies on 25.05.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

/**
 A ContextMenu is used to display a context menu (if iOS >= 13) or an alert
 controller showing an action sheet when a long touch is performed on a
 certain view.
 */
open class ContextMenu: NSObject, UIContextMenuInteractionDelegate {
  
  /// The view on which to show the context menu
  public var view: UIView
  ///by default the UITargetedPreview animates from real size to ScreenFitting Size
  ///for a large image view in a scroll view, this can lead to an abnormal animation/behaviour
  public var smoothPreviewForImage: Bool = false
  /// prevent multiple appeariance of menu in iOS 12
  /// disabling the long Tap Gesture Recognizer did not worked
  private var open: Bool = false
  
  /// Initialize with a view on which to define the context menu  
  public init(view: UIView, smoothPreviewForImage: Bool = false) {
    self.view = view
    self.smoothPreviewForImage = smoothPreviewForImage
    super.init()
  }
  
  /// Define the menu to display on long touch
  public var menu: [(title: String, icon: String, closure: (String)->())] = [] {
    willSet {
      if menu.count == 0 {
        view.isUserInteractionEnabled = true   
        if #available(iOS 13.0, *) {
          let menuInteraction = UIContextMenuInteraction(delegate: self)
          view.addInteraction(menuInteraction)      
        }
        else {
          let longTouch = UILongPressGestureRecognizer(target: self, 
                            action: #selector(actionMenuTapped))
          longTouch.numberOfTouchesRequired = 1
          view.addGestureRecognizer(longTouch)
        }
      }      
    }
  }
  
  @objc func actionMenuTapped(_ sender: UIGestureRecognizer) {
    if open { return } else { open = true }
    var actionMenu: [UIAlertAction] = []
    for m in menu {
      actionMenu += Alert.action(m.title, closure: m.closure)
    }
    Alert.actionSheet(actions: actionMenu) { [weak self] in
      self?.open = false
    }
  }
  
  /// Add an additional menu item
  public func addMenuItem(title: String, icon: String, 
                          closure: @escaping (String)->()) {
    menu += (title: title, icon: icon, closure: closure)
  }
  
  @available(iOS 13.0, *)
  fileprivate func createContextMenu() -> UIMenu {
    let menuItems = menu.map { m in
      UIAction(title: m.title, image: UIImage(systemName: m.icon)) {_ in m.closure(m.title) }
    }
    return UIMenu(title: "", children: menuItems)
  }
  
  // MARK: - UIContextMenuInteractionDelegate protocol

  @available(iOS 13.0, *)
  public func contextMenuInteraction(_ interaction: UIContextMenuInteraction, 
    configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
    return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) 
    { _ -> UIMenu? in 
      return self.createContextMenu()
    }
  }
  
    
  @available(iOS 13.0, *)
  public func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
      guard self.smoothPreviewForImage == true,
        let imgV = view as? UIImageView else {
          //Use Default Menu Appeariance
          return nil
      }
      /// prevent the white background wich is default and appear in some cases as white outline
      let params = UIPreviewParameters()
      params.backgroundColor = .black
      
      let preview = UIImageView(frame: CGRect(origin: CGPoint.zero,
                                              size: view.frame.size))
      preview.image = imgV.image
      preview.contentMode = imgV.contentMode
      return UITargetedPreview(view:preview,
                               parameters: params,
                               target: UIPreviewTarget(container: view.superview!,
                                                       center: view.center))
  }
} // ContextMenu
