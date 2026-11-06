//
//  Notification.swift
//
//  Created by Norbert Thies on 27.04.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import Foundation

public protocol NotificationObserving: AnyObject {
  var notificationObservers: [Notification.Observer] { get set }
}

public extension NotificationObserving {
  func removeObservers() {
    notificationObservers.forEach(Notification.remove)
    notificationObservers.removeAll()
  }
  
  func removeObserver(_ observer: Notification.Observer) {
      Notification.remove(observer: observer)
      notificationObservers.removeAll { $0 === observer }
  }
}

private final class ObserverToken: @unchecked Sendable {
  private let lock = NSLock()
  private var storedValue: Notification.Observer

  init(_ value: Notification.Observer) {
    storedValue = value
  }

  var value: Notification.Observer {
    get {
      lock.lock()
      defer { lock.unlock() }
      return storedValue
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      storedValue = newValue
    }
  }
}

public extension Notification {
  
  typealias Observer = NSObjectProtocol?
  
  /// The sender of a Notification
  var sender: Any? { return object }
  
  /// info returns value from userInfo
  func info(_ key: String) -> Any? {
    guard let dict = userInfo, let cont = dict[key] else { return nil }
    return cont
  }
  
  /// The content having been sent
  var content: Any? { info("content") }
  
  /// Has an Error been sent?
  var error: Error? { info("error") as? Error }
  
  /**
   If the Notification has been received via 'receive', this method removes the
   Observer defined by 'receive' and thereby withdraws from further Notifications
   */
  func withdraw() {
    guard let dict = userInfo, let observer = dict["observerToken"] as? NSObjectProtocol
    else { return }
    Notification.remove(observer: observer)
  }
  
  /// Send Notification
  static func send(_ message: String, content: Any? = nil, error: Error? = nil,
                   sender: Any? = nil) {
    let nn = NSNotification.Name(message)
    var dict: [AnyHashable:Any] = [:]
    dict["content"] = content
    dict["error"] = error
    let notification = Notification(name: nn, object: sender, userInfo: dict)
    NotificationCenter.default.post(notification)
  }
  
  /// Send Result<Type,Error> as Notification
  static func send<Type>(_ message: String, result: Result<Type,Error>,
                         sender: Any? = nil) {
    if let err = result.error() {
      send(message, error: err, sender: sender)
    }
    else { send(message, content: result.value() ?? nil, sender: sender) }
  }
  
  /// Receive Notification and return observer object
  @discardableResult
  static func receive(_ message: Notification.Name,
                      from: Any? = nil,
                      observer: NotificationObserving? = nil,
                      closure: @escaping (Notification)->())
  -> Observer {
    let observerToken = ObserverToken(nil)

    observerToken.value = NotificationCenter.default.addObserver(
      forName: message,
      object: from,
      queue: nil
    ) { notification in
      var notif = notification
      var dict = notification.userInfo ?? [:]
      dict["observerToken"] = observerToken.value
      notif.userInfo = dict
      closure(notif)
    }

    if let observer {
      observer.notificationObservers.append(observerToken.value)
    }

    return observerToken.value
  }
  
  /// Receive Notification and return observer object
  @discardableResult
  static func receive(_ message: String,
                      from: Any? = nil,
                      observer: NotificationObserving? = nil,
                      closure: @escaping (Notification)->())
  -> Observer {
    return receive(
      NSNotification.Name(message),
      from: from,
      observer: observer,
      closure: closure
    )
  }
  
  /// Receive Notification and remove observer immediately after reception
  @discardableResult
  static func receiveOnce(_ message: Notification.Name,
                          from: Any? = nil,
                          observer: NotificationObserving? = nil,
                          closure: @escaping (Notification)->()) -> Observer {
    return receive(message, from: from, observer: observer) { notif in
      if let observer,
         let token = notif.info("observerToken") as? NSObjectProtocol {
        observer.removeObserver(token)
      } else {
        notif.withdraw()
      }

      closure(notif)
    }
  }

  /// Receive Notification and remove observer immediately after reception
  @discardableResult
  static func receiveOnce(_ message: String,
                          from: Any? = nil,
                          observer: NotificationObserving? = nil,
                          closure: @escaping (Notification)->()) -> Observer {
    return receiveOnce(
      NSNotification.Name(message),
      from: from,
      observer: observer,
      closure: closure
    )
  }
  
  /// Remove observer
  static func remove(observer: Observer) {
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }
  
} // Notification Extensions
