//
//  SerialQueue.swift
//
//  Created by Norbert Thies on 20.01.22.
//  Copyright © 2022 Norbert Thies. All rights reserved.
//

/**
 * SerialQueue is intended as protocol for types offering a simple method
 * _queue_ to put a closure on a serial queue for later processing.
 */
public protocol SerialQueue {
  /// Queue label
  var label: String { get set }
  /// Put closure on a serial queue
  @discardableResult 
  func queue<Type>(closure: @escaping ()->Type)->Type
  /// Initialize with queue name
  init(label: String)
}

extension SerialQueue {
  /// Since Swifts standard library doesn't support serial queues, we simply
  /// call the closure.
  @discardableResult
  public func queue<Type>(closure: ()->Type) -> Type {
    return closure()
  }
}
