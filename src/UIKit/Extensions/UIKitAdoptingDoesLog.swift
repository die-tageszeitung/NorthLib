//
//  UIKitAdoptingDoesLog.swift
//
//  Created by Norbert Thies on 21.08.17.
//  Copyright © 2017 Norbert Thies. All rights reserved.
//

import UIKit

/// Common UIKit types adopting DoesLog to perform logging
extension UIView: @retroactive DoesLog {}
extension UIViewController: @retroactive DoesLog {}
