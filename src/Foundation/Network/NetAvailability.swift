//
//  NetAvailability.swift
//
//  Created by Norbert Thies on 23.05.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import Foundation
import SystemConfiguration

/**
 The class NetAvailability enables the tracking of the connection status to the 
 internet. 
 
 All connection status checking is based on an instance of this class. E.g.
 ````
 let net = NetAvailability()
 if net.isAvailable { print("network available") }
 ````
 allows for checking whether internet is available at all. The expression 
 ````
 net.isMobile
 ```` 
 queries whether the connection to the internet is via a cellular or mobile network.
 If you are interested whether a certain host is reachable you may use:
 ````
 let net = NetAvailability("www.apple.com")
 if net.isAvailable { print("can reach apple.com") }
 ````
 If you are interested in network availability changes you may use `onChange` to 
 define a closure that is called upon changes:
 ````
 net.onChange { (flags: SCNetworkReachabilityFlags) in
   print("network availability has changed, flags=\(flags\)")
 }
 ````
 If you are only interested in events that call a closure when internet availability 
 goes up or down, you may use:
 ````
 let net = NetAvailability()
 
 net.whenUp {
   print("network available")
 }
 
 net.whenDown {
   print("network no longer available")
 }
 ````
 */
open class NetAvailability {
  
  // destination to test for reachability
  private var destination: SCNetworkReachability
  
  fileprivate var lastFlags: SCNetworkReachabilityFlags
  
  fileprivate var reachabilityFlags: SCNetworkReachabilityFlags {
    var flags = SCNetworkReachabilityFlags()
    SCNetworkReachabilityGetFlags(self.destination, &flags)
    return flags
  }
  
  /// Is network connectivity available?
  public func isAvailable(flags: SCNetworkReachabilityFlags? = nil) -> Bool {
    var fl = flags
    if fl == nil { fl = reachabilityFlags }
    return isReachable(flags: fl!)
  }
  
  /// Is network connectivity available?
  public var isAvailable: Bool { return isAvailable() }

  /// Is network connection via mobile networks?
  public func isMobile(flags: SCNetworkReachabilityFlags? = nil) -> Bool {
#if canImport(UIKit)
    var fl = flags
    if fl == nil { fl = reachabilityFlags }
    return isReachable(flags: fl!) && fl!.contains(.isWWAN)
#else
    return false
#endif
  }
  
  /// Is network connection via mobile networks?
  public var isMobile: Bool { return isMobile() }
  
  private func isReachable(flags: SCNetworkReachabilityFlags) -> Bool {
    let isReachable = flags.contains(.reachable)
    let needsConnection = flags.contains(.connectionRequired)
    let autoConnect = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
    let withoutUser = autoConnect && !flags.contains(.interventionRequired)
    return isReachable && (!needsConnection || withoutUser)
  }
  
  /// Check for general network availability
  required public init(_ destination: SCNetworkReachability? = nil) {
    if let destination = destination { self.destination = destination }
    else {
      var addr = sockaddr()
      addr.sa_len = UInt8(MemoryLayout<sockaddr>.size)
      addr.sa_family = sa_family_t(AF_INET)
      self.destination = SCNetworkReachabilityCreateWithAddress(nil, &addr)!
    }
    var fl = SCNetworkReachabilityFlags()
    SCNetworkReachabilityGetFlags(self.destination, &fl)
    self.lastFlags = fl
    let callback: SCNetworkReachabilityCallBack = { (reachability,flags,info) in
      guard let info = info else { return }      
      let net = Unmanaged<NetAvailability>.fromOpaque(info).takeUnretainedValue()
      net.changeCallback(flags: flags)
      net.lastFlags = flags
    }
    var context = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, 
                    copyDescription: nil)
    context.info = UnsafeMutableRawPointer(Unmanaged<NetAvailability>.passUnretained(self).toOpaque())
    SCNetworkReachabilitySetCallback(self.destination, callback, &context)
    let current = OperationQueue.current?.underlyingQueue
    SCNetworkReachabilitySetDispatchQueue(self.destination, current!)
  }
  
  // deinit removes the callback
  deinit {
    SCNetworkReachabilitySetDispatchQueue(self.destination, nil)
    SCNetworkReachabilitySetCallback(self.destination, nil, nil)
  }
  
  /// Check for reachability of the given host
  convenience public init(host: String) {
    let hdest = SCNetworkReachabilityCreateWithName(nil, host)
    self.init(hdest)
  }
  
  // changeCallback is called upon network reachability changes
  private func changeCallback(flags: SCNetworkReachabilityFlags) {
    if let closure = self._onChangeClosure {
      if lastFlags != flags { closure(flags) }//prevent double call
    }
    if let closure = self._whenUpClosure {
      if isAvailable(flags: flags) && !isAvailable(flags: lastFlags) { closure() }
    }
    if let closure = self._whenDownClosure {
      if !isAvailable(flags: flags) && isAvailable(flags: lastFlags) { closure() }
    }
  }
  
  var _onChangeClosure: ((SCNetworkReachabilityFlags)->())? = nil
  var _whenUpClosure: (()->())? = nil
  var _whenDownClosure: (()->())? = nil
  
  /// Defines the closure to call when a network change has happened
  public func onChange(_ closure: ((SCNetworkReachabilityFlags)->())?) {
    _onChangeClosure = closure
  }
  
  /// Defines the closure to call when the network goes up
  public func whenUp(_ closure: (()->())?) {
    _whenUpClosure = closure
  }
  
  /// Defines the closure to call when the network goes down
  public func whenDown(_ closure: (()->())?) {
    _whenDownClosure = closure
  }  
  
} // NetAvailability

public class ExtendedNetAvailability: DoesLog {
  /**
   [...]
   SCNetworkReachability and  NWPathMonitor
   is not perfect; it can result in both false positives (saying that something is reachable when it’s not) and false negatives (saying that something is unreachable when it is). It also suffers from TOCTTOU issues.
   [...]
   Source: https://developer.apple.com/forums/thread/105822
   Written by: Quinn “The Eskimo!”   Apple Developer Relations, Developer Technical Support, Core OS/Hardware
    => this is maybe the problem within our: Issue not appears, download not work issues
   */
  /// netAvailability is used to check for network access to the Feeder
  public var netAvailability: NetAvailability? {
    didSet {
      oldValue?.onChange{ _ in }
      netAvailability?.onChange{[weak self] flags in
        guard let self = self,
              let conn = netAvailability?.isAvailable(flags:flags) else { return }
        self._onChangeClosure?(conn)
      }
    }
  }
  
  var _onChangeClosure: ((Bool)->())? = nil
  
  /// Defines the closure to call when a network change has happened
  public func onChange(_ closure: ((Bool)->())?) {
    _onChangeClosure = closure
  }
  
  var netStatusVerification = Date()
  
  
  public var isMobile: Bool { netAvailability?.isMobile ?? false }
  
  public var wasConnected: Bool {
    guard let netAvailability = netAvailability else { return false }
    return netAvailability.isAvailable(flags: netAvailability.lastFlags)
  }
  
  /// Factory Method to create NetAvailability Instances for isConnected check and verification
  private func createNetAvailability() -> NetAvailability? {
    guard let host = URL(string: self.url)?.host else { return nil }
    return NetAvailability(host: host)
  }
  
  public var url: String {
    didSet {
      netStatusVerification = Date()
      self.netAvailability = createNetAvailability()
    }
  }
  
  /// Defines the closure to call when a network change has happened
  public func recheck(force: Bool = false) {
    netStatusVerification = Date()
    guard let netAvailability = self.netAvailability else {
      self.netAvailability = createNetAvailability()
      return
    }
    
    if force || createNetAvailability()?.reachabilityFlags != netAvailability.lastFlags {
      self.netAvailability = createNetAvailability()
      _onChangeClosure?(self.netAvailability?.isAvailable ?? false)
    }
  }
  
  public init(url: String) {
    self.url = url
  }
  
  public var isConnected: Bool {
    if netAvailability == nil { netAvailability = createNetAvailability() }
    guard let netAvailability = netAvailability else { return false }

    let recheckDuration = Device.isSimulator ? 30.0 : 5*60.0
    
    if abs(netStatusVerification.timeIntervalSinceNow) > recheckDuration {
      recheck()
    }
    
    let lastFlags = netAvailability.lastFlags
    let currentFlags = netAvailability.reachabilityFlags
    let connected = netAvailability.isAvailable(flags:currentFlags)
    
    if lastFlags != currentFlags {
      _onChangeClosure?(connected)
    }
    return connected
  }
}
