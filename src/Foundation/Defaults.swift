//
//  Defaults.swift
//
//  Created by Norbert Thies on 08.04.17.
//  Copyright © 2017 Norbert Thies. All rights reserved.
//

import Foundation

/** The Defaults class is just some syntactic sugar around iOS' UserDefaults.
 
 In addition to simple key/value pairs this class manages so called scoped key/values.
 A scoped key is a key prefixed by a string "<scope>.". This may be useful if default
 values may depend on whether they are used on an iPad or on an iPhone.
 Eg. 
   let dfl = Defaults.singleton
   dfl["iPhone","width"] = "120"
   dfl["iPad","width"] = "240"
 will create the key/value pairs "iPhone.width"="120" and "iPad.width"="240".
 When Defaults.singleton is created, a scope corresponding to the device currently 
 in use is added. Eg. if running on an iPhone, Defaults.singleton implicitly performs
   addScope("iPhone")
 */
public final class Defaults: KVStore, Singleton {
  
  /// Key/Value base for UserDefaults
  struct DefaultsBase: KVStoreBase {
    var udef: UserDefaults
    init(suite: String? = nil) { udef = UserDefaults(suiteName: suite)! }
    func get(key: String) -> String? { udef.string(forKey: key) }
    func set(key: String, val: String) { udef.set(val, forKey: key) }
    func delete(key: String) {udef.removeObject(forKey: key) }
    func synchronize() { udef.synchronize() }
  }
  
  /// The singleton user defaults array
  public static var singleton: Defaults = Defaults()
  
  /// Init with suite name to share defaults between apps
  public init(suite: String? = nil) {
    super.init(base: DefaultsBase(suite: suite), name: nil, suite: suite)
    if Device.isIphone { addScope("iPhone") }
    else if Device.isIpad { addScope("iPad") }
    else if Device.isMac { addScope("mac") }
    else if Device.isTv { addScope("tv") }
    else if Device.isSimulator { addScope("simulator") }
  }

}
  
@propertyWrapper
public class Default<T: StringConvertible>: KeyValue<Defaults,T> {
  
  /// The wrapped value is interpreted as type T
  public override var wrappedValue: T {
    get { T.fromString(value) }
    set { value = T.toString(newValue) }
  }
  /// The projected value is the wrapper itself
  public override var projectedValue: Default<T> { self }

}
