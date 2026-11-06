//
//  AdoptingColorSheme.swift
//  NorthLib
//
//  Created by Ringo on 03.09.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

public let globalStylesChangedNotification = "globalStylesChanged"

public protocol UIStyleChangeDelegate: NSObject, NotificationObserving {
  
  /// Function to be called to apply Styles, put your updateable Style Stuff here
  func applyStyles()
  
  /// Register Handler for Current Object
  /// Will call applyStyles() on register @see extension UIStyleChangeDelegate
  func registerForStyleUpdates()
}

public extension UIStyleChangeDelegate {
  /// Register Handler for Current Object
  /// execute applyStyles() on call
    func registerForStyleUpdates() {
        applyStyles()

        Notification.receive(globalStylesChangedNotification, observer: self) { [weak self] _ in
            self?.applyStyles()
        }
    }
}
