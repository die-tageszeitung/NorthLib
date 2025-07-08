//
//  KVStore.swift
//  NorthLib
//
//  Created by Norbert Thies on 20.06.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import Foundation

/**
 The protocol KVStoreBase defines the functions needed to build a meaningful
 key/value store.
 */

public protocol KVStoreBase {
  /// Get value of given key
  func get(key: String) -> String?
  /// Set a key/value pair
  func set(key: String, val: String)
  /// Delete a key/value pair
  func delete(key: String)
  /// Synchronize store (eg. to disk or network) - optional
  func synchronize()
}

extension KVStoreBase {
  func synchronize() {}
}

/**
 The class KVStore defines some general properties of a key/value store.
 
 A KVStore may be scoped, ie. keys may be stored using a prefix indicating
 the scope.
 Stored keys and values are Strings only.
 */

open class KVStore {
    
  /// An optional additional prefix
  public var suite: String?
  
  /// Name of KVStore (used as Notification name)
  public var name: String
  
  /// An optional fallback KVStore
  public var fallback: KVStore?
  
  /// Base of KVStore
  var base: KVStoreBase
  
  /// Notification content type
  public typealias NotificationArg = (key: String, val: String?, scope: String?)

  @Callback<NotificationArg>
  public var onChange: Callback<NotificationArg>.Store
  
  /// Initialize with optional name and optional suite name
  public init(base: KVStoreBase, name: String?, suite: String? = nil,
              device: String? = nil) {
    self.base = base
    self.name = "\(type(of: self))"
    if let name = name { self.name = name }
    $onChange.notification = self.name
    self.suite = suite
    if let device = device { addScope(device) }
  }
  
  /// Syntactic sugar for Notification.receive
  public func receive(key: String? = nil, closure: @escaping (NotificationArg)->()) {
    Notification.receive(self.name) { notif in
      guard let arg = notif.content as? NotificationArg else { return }
      if let key = key { if key == arg.key { closure(arg) } }
      else { closure(arg) }
    }
  }
  
  /// The scopes used to search for keys
  var scopes: Set<String> = []
  
  /// Adds scope to list of scopes
  public func addScope( _ scope: String? ) {
    if let sc = scope { scopes.insert(sc) }
  }
  
  /// Removes scope from the list of scopes
  public func removeScope( _ scope: String ) {
    scopes.remove( scope )
  }
  
  /// Removes all scopes
  public func removeAllScopes() {
    scopes = []
  }
  
  /// Returns prefix including suite (if defined)
  private func prefix(_ scope: String? = nil) -> String {
    var pref = ""
    if let s = scope { pref += "\(s)." }
    return pref
  }
  
  /// Find value for key in list of scopes
  public func find(_ key: String, scope: String? = nil)
    -> (key: String, val: String?, scope: String?) {
    var k: String
    if let scope = scope {
      k = prefix(scope) + key
      return (k, base.get(key: k), scope)
    }
    for ctx in scopes {
      let pref = prefix(ctx)
      k = pref + key
      if let val = base.get(key: k) {
        return (k, val, ctx)
      }
    }
    k = prefix() + key
    return (k, base.get(key: k), nil)
  }
  
  /// Delete key/value pair from KVStore
  public func delete(key: String) {
    let old = find(key)
    if old.val != nil {
      base.delete(key: key)
      base.synchronize()
    }
    fallback?.delete(key: key)
  }
  
  /// Get value of given key, if undefined retrieve value from fallback store
  /// and store it in local store
  public func get(key: String, scope: String? = nil,
                  fallback fback: KVStore? = nil,
                  dontSearch: Bool = false) -> String? {
    let fallback = fback ?? self.fallback
    var val: String?
    if dontSearch { val = base.get(key: prefix(scope) + key) }
    else { val = find(key, scope: scope).val }
    if let v = val { return v }
    else if let fallback = fallback {
      if let other = fallback.get(key: key, scope: scope, dontSearch: dontSearch) {
        base.set(key: prefix(scope) + key, val: other)
        return other
      }
    }
    return nil
  }
  
  /// Set value of given key, if defined, set it also in fallback store
  public func set(key: String, val: String?, scope: String? = nil,
                  fallback fback: KVStore? = nil, isNotify: Bool = true,
                  dontSearch: Bool = false) {
    var old: (key: String, val: String?, scope: String?)
    let fallback = fback ?? self.fallback
    if let scope = scope {
      let k = prefix(scope) + key
      old = (k, base.get(key: k), scope)
    }
    else if dontSearch {
      old = (key, base.get(key: key), scope)
    }
    else { old = find(key) }
    let k = old.key
    if old.val != val {
      if let v = val {
        base.set(key: k, val: v)
        fallback?.set(key: key, val: v, scope: scope)
      }
      else if old.val != nil {
        base.delete(key: k)
        fallback?.delete(key: key)
      }
      else { return }
      base.synchronize()
      if isNotify { $onChange.notify(sender: self,
                              content: (key: key, val: val, scope: old.scope))
      }
    }
  }
  
  /// object[key] - returns the value associated with key in any defined scope
  /// object[key] = value - sets the associated value in that scope where key
  /// is defined or in the global scope if key isn't defined in any scope
  /// object[key] = nil - removes the key/value pair from KVStore
  public subscript(_ key: String) -> String? {
    get { return get(key: key) }
    set(val) { set(key: key, val: val) }
  }
  
  /// defaults[scope,key] - returns the value associated with key in given scope
  /// defaults[scope,key] = value - sets the associated value in given scope
  /// defaults[scope,key] = nil - removes the key/value pair from Defaults
  public subscript(_ scope: String?, _ key: String) -> String? {
    get { get(key: key, scope: scope, dontSearch: true) }
    set(val) { set(key: key, val: val, scope: scope, dontSearch: true) }
  }
  
  // setIfUndefined sets a key/value pair if there is no previous definition
  private func setIfUndefined(key: String, val: String?, scope: String? = nil,
                              isNotify: Bool = true) {
    let v = get(key: key, scope: scope)
    if v == nil { set(key: key, val: val, scope: scope, isNotify: isNotify) }
  }
  
  /// The Values class is used to associate a dictionary of key/value pairs
  /// with an optional scope
  public class Values {
    var scope: String?
    var values: [String:String?]
    public init(scope: String?, values: [String:String?]) {
      self.scope = scope
      self.values = values
    }
    public convenience init(_ values: [String:String?])
      { self.init(scope: nil, values: values) }
  }

  /// setDefaults is used to set all key/value pairs given in 'values'
  /// if they are not already defined.
  public func setDefaults(values: Values, isNotify: Bool = false, forceWrite: Bool = false) {
    for (k,v) in values.values {
      forceWrite
      ? set(key: k, val: v, scope: values.scope, isNotify: isNotify)
      : setIfUndefined(key: k, val: v, scope: values.scope, isNotify: isNotify)
    }
  }
    
  /// Returns true if a given key is associated with a value
  public func isDefined(_ key: String) -> Bool { return self[key] == nil }
   
} // KVStore

/// Protocol for types converting a String to itself and vice versa
/// Warning: If converting nil, this protocol enforces to return
/// a default non nil value.
public protocol StringConvertible {
  static func fromString(_ str: String?) -> Self
  static func toString(_ val: Self) -> String
}

extension String: StringConvertible {
  public static func fromString(_ str: String?) -> String { str ?? "" }
  public static func toString(_ val: String) -> String { val }
}

extension Bool: StringConvertible {
  public static func fromString(_ str: String?) -> Bool {
    if let str = str { return str.bool }
    return false
  }
  public static func toString(_ val: Bool) -> String {
    return val ? "true" : "false"
  }
}

extension Int: StringConvertible {
  public static func fromString(_ str: String?) -> Int {
    if let str = str { return Int(str) ?? 0 }
    return 0
  }
  public static func toString(_ val: Int) -> String { "\(val)" }
}

extension Double: StringConvertible {
  public static func fromString(_ str: String?) -> Self {
    if let str = str { return Self(str) ?? 0 }
    return 0
  }
  public static func toString(_ val: Self) -> String { "\(val)" }
}

extension Date: StringConvertible {
  public static func fromString(_ str: String?) -> Date { (str ?? "0").usTime.date }
  public static func toString(_ val: Self) -> String { "\(UsTime(val).sec)" }
}

/// A protocol for data structures supporting a singleton instance
public protocol Singleton {
  static var singleton: Self { get }
}

/// A property wrapper for KVStore
@propertyWrapper
open class KeyValue<Store: KVStore & Singleton, T: StringConvertible> {
    
  /// The String to use as Defaults key
  open var key: String
  
  /// The raw String? value (in essence Defaults.singleton[key])
  open var value: String? {
    get { Store.singleton[key] }
    set { Store.singleton[key] = newValue }
  }
  
  /// The wrapped value is the interpreted value as type T
  open var wrappedValue: T {
    get { T.fromString(value) }
    set { value = T.toString(newValue) }
  }

  /// The projected value is the wrapper itself
  open var projectedValue: KeyValue<Store, T> { self }
  
  /// The closures to call when this value has been changed
  @Callback<T>
  open var onChange: Callback<T>.Store
  
  private func setupNotifications() {
    guard $onChange.count == 0 else { return }
    Store.singleton.onChange { [weak self] msg in
      if let self = self,
         self.$onChange.count > 0 && msg.key == self.key {
        self.$onChange.notify(sender: self, content: T.fromString(msg.val))
      }
    }
  }
    
  /// Delete KeyValue entry
  public func delete() { Store.singleton[key] = nil }

  public init(_ key: String) {
    self.key = key
    $onChange.whenActivated { [weak self] _ in
      self?.setupNotifications()
    }
  }
  
} // KeyValue
