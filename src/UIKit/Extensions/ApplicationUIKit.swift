//
//  ApplicationUIKit.swift
//  NorthLib
//
//  Created by Ringo Müller on 10.02.26.
//

import UIKit

/// A simple UIApplication extension
public extension UIApplication {
  var activeKeyWindow: UIWindow? {
    connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }
}
