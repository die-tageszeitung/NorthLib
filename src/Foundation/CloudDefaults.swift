//
//  CloudDefaults.swift
//  NorthLib
//
//  Created by Norbert Thies on 01.07.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import Foundation

/**
 The CloudDefaults class works as an iCloud based *Defaults* class
 */

public final class CloudDefaults: KVStore, Singleton {
  
  /// Key/Value base for UserDefaults
  struct CloudDefaultsBase: KVStoreBase {
    var udef: NSUbiquitousKeyValueStore
    init(suite: String? = nil) { udef = NSUbiquitousKeyValueStore.default }
    func get(key: String) -> String? { udef.string(forKey: key) }
    func set(key: String, val: String) { udef.set(val, forKey: key) }
    func delete(key: String) {udef.removeObject(forKey: key) }
    func synchronize() { udef.synchronize() }
  }
  
  /// The singleton user defaults array
  private static var instance = CloudDefaults()
  public static var singleton: CloudDefaults { return instance }
  public static func reinitialize() { instance = CloudDefaults() }
  
  /// Init with suite name to share defaults between apps
  private init(suite: String? = nil) {
    super.init(base: CloudDefaultsBase(suite: suite), name: nil, suite: suite)
    Notification.receive(NSUbiquitousKeyValueStore.didChangeExternallyNotification, observer: self)
    { [weak self] notif in
      guard let self = self else { return }
      if let changedKeys = notif.info(NSUbiquitousKeyValueStoreChangedKeysKey) as?
        [String] {
        for k in changedKeys {
          self.$onChange.notify(sender: self, content: (key: k, val:
            self.get(key: k), scope: nil))
        }
      }
    }
  }

}
  
@propertyWrapper
public class CloudDefault<T: StringConvertible>: KeyValue<CloudDefaults,T> {
  
  /// The wrapped value is interpreted as type T
  public override var wrappedValue: T {
    get { T.fromString(value) }
    set { value = T.toString(newValue) }
  }
  /// The projected value is the wrapper itself
  public override var projectedValue: CloudDefault<T> { self }

}
