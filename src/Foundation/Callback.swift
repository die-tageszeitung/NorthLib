//
//  Callback.swift
//
//  Created by Norbert Thies on 25.05.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import Foundation

/**
 A ThreadClosure wraps a closure and the Thread it was defined on for later
 execution.
 
 Assume you create a ThreadClosure object on Thread *A* like this:
 ````
 let tclosure = ThreadClosure { print("test") }
 ````
 and later on a different (or the same) Thread *B* do:
 ````
 tclosure()
 or
 tclosure.call()
 ````
 then the closure stored in *tclosure* will be performed on Thread *A* and "test"
 will be printed to the console.
 */
open class ThreadClosure<T>: NSObject {
  /// The Thread this closure should execute on
  var thread: Thread
  /// The closure passed to init
  var closure: (T)->()
  
  /// Initialize with given closure in current thread of execution
  public init(_ closure: @escaping (T)->()) {
    self.closure = closure
    self.thread = Thread.current
  }
  
  /// Calls the closure on the Thread it was defined on
  public func call(arg: T, wait: Bool = false) {
    self.perform(#selector(callClosure), on: thread, with: arg,
                 waitUntilDone: wait)
  }
  public func callAsFunction(arg: T, wait: Bool = false)
    { call(arg: arg, wait: wait) }
  
  @objc private func callClosure(arg: Any) {
    guard let targ = arg as? T else { return }
    closure(targ)
  }
}

/// Let ThreadClosure default to Void
extension ThreadClosure where T == Void {
  public func call(wait: Bool = false) {
    call(arg: (), wait: wait)
  }
  public func callAsFunction(wait: Bool = false)
    { call(arg: (), wait: wait) }
}

/**
 Callback defines a property wrapper which manages callbacks to closures
 and sends notifications to interested parties.
 
 Let's start with a simple example:
 ````
 class A {
   ...
   @Callback
   var whenReady: Callback<Void>.Store
   ...
 }
 ````
 This defines a simple class *A* defining a variable *whenReady* which is in
 effect a function storing closures in an array hidden inside the wrapper.
 The idea is to call these closures when some method of *A* wishes
 to notify them.
 
 Let's further examine the use of *whenReady*:
 ````
 let a = A()
 a.whenReady { _ in print(1) }
 a.whenReady { _ in print(2) }
 ````
 and an extension to *A* notifying the closures `{print(1)}, {print(2)}`
 ````
 extension A {
   func someMethod() {
     $whenReady.notify(sender: self)
   }
 }
 ````
 The extension uses the projected value of *whenReady* to refer to the wrapper
 itself and uses its method *notify* to call the closures which in turn print
 *1* and *2*.
 
 The closures are called with an argument arg: Callback.Arg which is the tuple
 (content: Any?, sender: Any?). By convention *sender* is the object calling
 the closure and *content* is *some* arbitrary content. We could augment the
 above noted method as follows:
 ````
 extension A {
   func someMethod() {
     $whenReady.notify(sender: self, content: "test")
   }
 }
 ````
 and outside of *A* we could write the closure to call as:
 ````
 a.whenReady { arg in
   if let (content, sender) = arg as? Callback.Arg {
     // do somthing with content and sender
   }
 }
 ````
 
 # How to remove a closure
 
 Sometimes you may want to remove a previously defined closure from the
 list of closures:
 ````
 let index = a.$whenReady { arg in
   if let ...
 }
 ````
 using the projected value *$whenReady* instead of the wrapped
 value *whenReady* the closure is stored as well but its index
 into the closure array is returned.
 Using this index you may later:
 ````
 a.$whenReady.remove(index)
 ````
 remove the closure from the list. In fact the array is not shortened
 but the element is set to nil. Therefore the reference to the closure is
 removed and it will no longer be called.
 
 # Callbacks to different threads
 
 Along with each closure beeing stored in the wrapper's closure array the thread
 in which the closure was defined is stored as well. When calling the closures
 each is called in that thread it was defined in. All closures are called by the
 run loop and not by the object notifying the closures. Hence closures notifying
 closures recursively will not lead to a stack full of closures and possible reference
 cycles.
 
 # Callbacks as Notifications

 In addition to closure calls the Callback property wrapper may also be used to
 send Notifications for a looser coupling of program code. To receive notifications
 access to the sending object is not necessary. The receiving party must only know
 the notification's message name. The class defining the wrapper could use the following
 syntax to send a Notification "test" when *whenReady* closures are called:
 ````
 class A {
   ...
   @Callback("test")
   var whenReady: Callback<Void>.Store
   ...
 }
 ````
 Somewhere else in your source code the Notification may be received using:
 ````
 Notification.receive("test", observer: self) { notif in
   if let sender = notif.sender { /* do somthing with sender */ }
   if let content = notif.content { /* do something with content */ }
 }
 ````
 However it's not necessary to specify the Notification name when defining the
 property wrapper. You may do it at a later time:
 ````
   let a = A()
   a.$whenReady.notification = "test2"
 ````
 This would emit notifications with message name "test2".
 To disable *whenReady* Notifications set the notification name to nil:
 ````
   a.$whenReady.notification = nil
 ````
 
 # Remarks
 
 - Sometimes it's necessary to perform some computations before calling back to
 the closures. If these computations should only be performed when there are
 any closures defined or Notifications have been enabled then check this using:
 ````
   if $whenReady.needsNotification {
     // perform computations
     $whenReady.notify(...)
   }
 ````
 
 - If some setup is only needed when there are any closures added or notifications
 enabled you can define a closure to be called:
 ````
   $whenReady.whenActivated { isActivated in
     if isActivated { /* closure added or notification enabled */ }
     else { /* no more closures waiting and no notification defined */ }
   }
 ````
 
 - There are two generic convenience Callback methods to access sender and content
 parts of the argument passed to the closures - `Callback.sender` and
 `Callback.content`, e.g.:
 ````
   whenReady { arg in
     if let sender: A = Callback.sender(arg) { ... }
     if let content: Bool = Callback.content(arg) { ... }
   }
 ````
 */
@propertyWrapper
open class Callback<T> {
  
  // Syntactic sugar
  public typealias Closure = (T)->()
  public typealias Store = (@escaping Closure)->()
  public typealias Arg = (content: T, sender: Any?)
  
  // Array of closures
  private var closures: [ThreadClosure<T>?] = []
  /// nb. of closures stored
  public var count: Int { return closures.count }
  // Semaphore protecting access to *closures*
  private var semaphore = DispatchSemaphore(value: 1)
  // Activation closure
  private var activated: ((Bool)->())? = nil
  
  /// Define closure to call when closures are stored in/removed from the array
  /// or when notifications change
  public func whenActivated(closure: ((Bool)->())?) {
    activated = closure
    activated?(needsNotification)
  }
  
  /// Name of notification to send (if any)
  public var notification: String? = nil {
    didSet { activated?(needsNotification) }
  }
  
  /// Is a Notification defined or are there closures defined?
  public var needsNotification: Bool { notification != nil || closures.count > 0 }
  
  /// The wrapped value is a function storing closures in the closure arry.
  public var wrappedValue: Callback<T>.Store { { c in self.store(closure: c) } }
  
  /// Object called as function
  public func callAsFunction(closure: @escaping Closure) -> Int {
    store(closure: closure)
  }
  
  /// Store a closure in the closure array and return its index which
  /// can be used to remove the closure from the array at a later time.
  @discardableResult
  public func store(closure: @escaping Closure) -> Int {
    self.semaphore.wait()
    let ret = self.closures.count
    self.closures += ThreadClosure(closure)
    self.semaphore.signal()
    activated?(needsNotification)
    return ret
  }
  
  /// The projected value is the wrapper itself
  public var projectedValue: Callback { self }
  
  /// Notify all closures and send an optional Notification
  public func notify(sender: Any?, content: T, wait: Bool = false) {
    self.semaphore.wait()
    let list = self.closures
    self.semaphore.signal()
    for closure in list {
      if let closure = closure {
        closure.call(arg: content, wait: wait)
      }
    }
    if let notification = self.notification {
      Notification.send(notification, content: content, sender: sender)
    }
  }
  
  /// Removes a single closure from the array
  @discardableResult
  public func remove(_ index: Int) -> ThreadClosure<T>? {
    self.semaphore.wait()
    let closure = closures[index]
    if closure != nil {
      closures[index] = nil
    }
    self.semaphore.signal()
    activated?(needsNotification)
    return closure
  }
  
  /// Removes all closures from the array
  public func removeAll() {
    self.semaphore.wait()
    closures = []
    self.semaphore.signal()
    activated?(needsNotification)
  }
  
  /// Directs the wrapper to send an additional notification
  public init(notification: String) {
    self.notification = notification
  }
  
  /// Directs the wrapper to not send any notifications
  public init() {}
}

/// Let @Callback default to Void and provide a more concise notify method
extension Callback where T == Void {
  public func notify(sender: Any?, wait: Bool = false) {
    notify(sender: sender, content: (), wait: wait)
  }
}

/// A SingleCallback allows only one closure to be stored. The last closure
/// overrides the previous ones.
@propertyWrapper
open class SingleCallback<T>: Callback<T> {
  
  public override var wrappedValue: Callback<T>.Store { { c in
    self.removeAll()
    self.store(closure: c)
  } }
  
  /// The projected value is the wrapper itself
  public override var projectedValue: SingleCallback { self }
  
}
