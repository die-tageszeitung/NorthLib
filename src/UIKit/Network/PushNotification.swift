//
//  PushNotification.swift
//
//  Created by Norbert Thies on 14.01.20.
//  Copyright © 2020 Norbert Thies. All rights reserved.
//

import UIKit

public typealias FetchCompletionHandler = ((UIBackgroundFetchResult)->())

/// Wrapper class for push notifications
open class PushNotification: NSObject, UNUserNotificationCenterDelegate, DoesLog {

  /// AlertPayload defines the alert message of the standard payload
  public class AlertPayload: Decodable, ToString {
    public var title: String?
    public var subtitle: String?
    public var body: String?
    public var launchImage: String?
    public var titleLocKey: String?
    public var titleLocArgs: [String]?
    public var subtitleLocKey: String?
    public var subtitleLocArgs: [String]?
    public var locKey: String?
    public var locArgs: [String]?
    
    public func toString() -> String {
      var ret = ""
      if let str = title { ret += "title: \"\(str)\"\n" }
      if let str = subtitle { ret += "subtitle: \"\(str)\"\n" }
      if let str = body { ret += "body: \"\(str)\"\n" }
      if let str = launchImage { ret += "launchImage: \"\(str)\"\n" }
      if let str = titleLocKey { ret += "titleLocKey: \"\(str)\"\n" }
      if let str = titleLocArgs { ret += "titleLocArgs: \"\(str)\"\n" }
      if let str = subtitleLocKey { ret += "subtitleLocKey: \"\(str)\"\n" }
      if let str = subtitleLocArgs { ret += "subtitleLocArgs: \"\(str)\"\n" }
      if let str = locKey { ret += "locKey: \"\(str)\"\n" }
      if let str = locArgs { ret += "locArgs: \"\(str)\"\n" }
      return ret
    }
    
    enum CodingKeys: String, CodingKey {
      case  title, subtitle, body, 
            launchImage = "launch-image", 
            titleLocKey = "title-loc-key", 
            titleLocArgs = "title-loc-args",
            subtitleLocKey = "subtitle-loc-key", 
            subtitleLocArgs = "subtitle-loc-args", 
            locKey = "loc-key", 
            locArgs = "loc-args"
    }
    
    required public init(from decoder: Decoder) throws {
      if let s = try? decoder.singleValueContainer().decode(String.self) {
        self.body = s
      }
      else {
        let dec = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try dec.decodeIfPresent(String.self, forKey: .title)
        self.subtitle = try dec.decodeIfPresent(String.self, forKey: .subtitle)
        self.body = try dec.decodeIfPresent(String.self, forKey: .body)
        self.launchImage = try dec.decodeIfPresent(String.self, 
                           forKey: .launchImage)
        self.titleLocKey = try dec.decodeIfPresent(String.self, 
                           forKey: .titleLocKey)
        self.titleLocArgs = try dec.decodeIfPresent([String].self, 
                            forKey: .titleLocArgs)
        self.subtitleLocKey = try dec.decodeIfPresent(String.self, 
                              forKey: .subtitleLocKey)
        self.subtitleLocArgs = try dec.decodeIfPresent([String].self, 
                               forKey: .subtitleLocArgs)
        self.locKey = try dec.decodeIfPresent(String.self, forKey: .locKey)
        self.locArgs = try dec.decodeIfPresent([String].self, forKey: .locArgs)
      }
    }
  }
  
  /// SoundPayload defines the sound message of the standard payload
  public class SoundPayload: Decodable, ToString {
    public var name: String?
    public var critical: Int?
    public var volume: Int?
    
    /// Returns true if critical notification
    public var isCritical: Bool { 
      guard let val = critical else { return false }
      return val != 0
    }

    public func toString() -> String {
      var ret = ""
      if let str = name { ret += "name: \"\(str)\"\n" }
      if let val = critical { ret += "critical: \"\(val != 0 ? "true" : "false")\"\n" }
      if let val = volume { ret += "volume: \"\(val)\"\n" }
      return ret
    }
    
    enum CodingKeys: String, CodingKey {
      case  name, critical, volume
    }
    
    required public init(from decoder: Decoder) throws {
      if let s = try? decoder.singleValueContainer().decode(String.self) {
        self.name = s
      }
      else {
        let dec = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try dec.decodeIfPresent(String.self, forKey: .name)
        self.critical = try dec.decodeIfPresent(Int.self, forKey: .critical)
        self.volume = try dec.decodeIfPresent(Int.self, forKey: .volume)
      }
    }
  }
  
  /// StandardPayload defines the payload beneath the "aps" key as defined by Apple
  public class StandardPayload: Decodable, ToString {
    public var alert: AlertPayload?
    public var badge: Int?
    public var sound: SoundPayload?
    public var threadId: String?
    public var category: String?
    public var contentAvailable: Int?
    public var mutableContent: Int?
    public var targetContentId: String?
    
    /// Returns true if silent notification
    public var isSilent: Bool { 
      guard let val = contentAvailable else { return false }
      return val != 0
    }
    
    /// Returns true if content is mutable by app
    public var isMutable: Bool { 
      guard let val = mutableContent else { return false }
      return val != 0
    }

    enum CodingKeys: String, CodingKey {
      case  alert, badge, sound, category,
            threadId = "thread-id",
            contentAvailable = "content-available",
            mutableContent = "mutable-content",
            targetContentId = "target-content-id"
    }

    public func toString() -> String {
      var ret = ""
      if let val = alert { ret += "alert:\n\(val.toString().indent(by: 2))" }
      if let val = badge { ret += "badge: \"\(val)\"\n" }
      if let val = sound { ret += "sound:\n\(val.toString().indent(by: 2))" }
      if let val = threadId { ret += "threadId: \"\(val)\"\n" }
      if let val = category { ret += "category: \"\(val)\"\n" }
      if let val = contentAvailable { ret += "contentAvailable: \"\(val)\"\n" }
      if let val = mutableContent { ret += "mutableContent: \"\(val)\"\n" }
      if let val = targetContentId { ret += "targetContentId: \"\(val)\"\n" }
      return ret
    }
  }
  
  /// Payload contains the payload of a push notification
  public class Payload: DoesLog, ToString {
    /// The raw payload
    public var raw: [String:Any]
    /// The custom payload (minus the standard payload)
    public var custom: [String:Any]
    /// JSON data of payload
    public var json: String { return Payload.jsonString(raw) }
    /// The standard payload
    public var standard: StandardPayload?

    /// Returns true if silent notification
    public var isSilent: Bool { 
      guard let val = standard else { return false }
      return val.isSilent
    }
    
    /// Returns true if content is mutable by app
    public var isMutable: Bool { 
      guard let val = standard else { return false }
      return val.isMutable
    }
    
    /// Returns true if critical notification
    public var isCritical: Bool { 
      guard let val = standard?.sound else { return false }
      return val.isCritical
    }
    
    /// Get JSON from "some" object
    public static func json(_ data: Any) -> Data {
      return try! JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
    }
    
    /// Get JSON string from "some" object
    public static func jsonString(_ data: Any) -> String {
      return String(data: json(data), encoding: .utf8)!
    }
    
    /// Initialize with Dictionary
    public init(_ payload: [AnyHashable:Any]) {
      self.raw = payload as! [String:Any]
      self.custom = self.raw
      self.custom["aps"] = nil
      do {
        let dec = JSONDecoder()
        self.standard = try dec.decode(StandardPayload.self, 
                                       from: Payload.json(raw["aps"]!))
      }
      catch let err {
        error(err)
      }
    }
    
    public func toString() -> String {
      var ret = "JSON Payload:\n\(json.indent(by: 2))\n"
      if let std = self.standard { 
        ret += "Standard Payload:\n\(std.toString().indent(by: 2))"
      }
      else { ret += "No Standard Payload\n" }
      if custom.count > 0 {
        ret += "Custom Payload:\n\(Payload.jsonString(custom).indent(by: 2))\n"
      }
      else { ret += "No Custom Payload\n" }
      return ret
    }
    
  } // Payload
  
  /// Default notification options
  public static var options: UNAuthorizationOptions = [.alert, .sound, .badge, .provisional]
  /// Unique device token (aka device ID)
  public var deviceId: String?
  /// isPermitted returns true if the user has accepted push notifications
  public var isPermitted: Bool { return deviceId != nil }
  
  // Closure to call upon user permission success or failure
  private var permissionClosure: ((PushNotification)->())?
  // Closure to call upon remote push delivery
  private var receiveClosure: ((PushNotification, Payload, FetchCompletionHandler?)->())?
  // Closure to call upon application is started from local notification
  private var openFromNotificationClosure: ((UNUserNotificationCenter, UNNotificationResponse, ()->()) -> ())?
 
  /// Asks the user to permit push notifications (if not already permitted)
  public func permit(opt: UNAuthorizationOptions = options, 
                     closure: @escaping (PushNotification)->()) {
    permissionClosure = closure
    UNUserNotificationCenter.current().requestAuthorization(
      options: opt) { (granted, error) in
      var ok: Bool
      if let err = error { ok = false; Log.error(err) }
      else { ok = granted }
      if ok {
        onMain { UIApplication.shared.registerForRemoteNotifications() }
      }
      else { self.register(token: nil) }
    } 
  }
  
  /// Defines closure to call upon reception of notifications
  public func onReceive(closure: @escaping (PushNotification, Payload, FetchCompletionHandler?)->()) {
    receiveClosure = closure
  }
  
  // Defines closure to call upon application is started from local notification
  public func onOpenApplicationFromNotification(closure: @escaping (UNUserNotificationCenter, UNNotificationResponse, ()->()) -> ()) {
    openFromNotificationClosure = closure
  }
  /// UNUserNotificationCenter delegate handler
  /// The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application returns from application:didFinishLaunchingWithOptions:.
  public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    log("have a openFromNotificationClosure? \(openFromNotificationClosure != nil)")
    openFromNotificationClosure?(center,response,completionHandler)
  }
    
  public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler(UNNotificationPresentationOptions.alert)
  }
  
  /// Register device token
  func register(token: Data?) {
    if let token = token {
      deviceId = token.hex
      debug("✅ Push notifications accepted, deviceId: \(deviceId!)")
    }
    else {
      deviceId = nil
      debug("❌ User denied push notifications")
    }
    if let closure = permissionClosure { onMain { closure(self) } }
  }

  /// Receive notification
  func receive(_ payload: [AnyHashable:Any], _ fetchCompletionHandler: FetchCompletionHandler?) {
    let pl = Payload(payload)
    debug("Push Notification received: \(pl.json.count) bytes has fetchCompletionHandler: \(fetchCompletionHandler != nil)")
    if let closure = receiveClosure { onMain { closure(self, pl, fetchCompletionHandler) } }
  }  
  
} // PushNotification

extension PushNotification {
  public func handleTestRemoteNotification(_ payload: [AnyHashable:Any]) {
    debug("handleTestRemoteNotification!")
    self.receive(payload, nil)
  }
}

/// This is not the real status bar, it's a scrollview that resides beneath 
/// the status bar of the same dimensions. It is used to detect status bar
/// touches.
open class StatusBar: UIScrollView, UIScrollViewDelegate, HandleOrientation {

  // Closure called upon orientation changes
  public var orientationChangedClosure = OrientationClosure()
  
  // Parent view of viewcontroller
  private var parent: UIView {
    let win = UIApplication.shared.delegate!.window!
    return win!.rootViewController!.view!
  }
  
  /// Frame of real status bar
  public static var realFrame: CGRect {
    UIWindow.keyWindow?.windowScene?.statusBarManager?.statusBarFrame ?? CGRect.zero
  }
  
  /// Returns true if the real status bar is hidden
  public static var isHidden: Bool { 
    return UIViewController.keyWindow?.windowScene?.statusBarManager?
      .isStatusBarHidden ?? true
  }
  
  // Closure to call on status bar touch
  private var sbTap: ((StatusBar)->())?
  
  /// Defines a closure to call on status bar taps
  public func onTap(_ closure: ((StatusBar)->())?) {
    sbTap = closure
  }
  
  // Status bar has been tapped 
  public func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
    if let tap = sbTap { tap(self) }
    return false
  }
    
  // Create status bar beneath real status bar
  public init () {
    let sbframe = StatusBar.realFrame
    super.init(frame: sbframe)
    let view = parent
    self.contentSize = CGSize(width: sbframe.width, height: sbframe.height+1)
    self.delegate = self
    self.isScrollEnabled = true
    self.scrollsToTop = true
    self.scrollRectToVisible(CGRect(x: 0, y: 1, width: sbframe.width, 
                             height: sbframe.height), animated: false)
    view.addSubview(self)
    self.translatesAutoresizingMaskIntoConstraints = false
    self.heightAnchor.constraint(equalToConstant: 
      sbframe.height).isActive = true
    self.widthAnchor.constraint(equalTo: view.widthAnchor, 
                                multiplier: 1.0).isActive = true
    self.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
    self.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    // Check for interface rotations
    onOrientationChange {
      if !self.isFaceDown { self.isHidden = StatusBar.isHidden }
    }
  }
  
  required public init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
} // StatusBar

/// A Protocol indicating that a view controller may be rotated.
public protocol CanRotate {}

public protocol CanRotateFromUnderlying {}

/// An AppDelegate that handles notifications and status bars
open class NotifiedDelegate: UIResponder, UIApplicationDelegate, 
           UIScrollViewDelegate, DoesLog {
  
  /// The object handling push notifications
  public var notifier = PushNotification()
  /// Send status bar touches?
  public lazy var statusBar = StatusBar()
  
  /// The singleton NotifiedDelegate object
  public static var singleton: NotifiedDelegate! = nil
  
  /// Defines a closure to call on status bar taps
  public func onSbTap(_ closure: ((StatusBar)->())?) {
    statusBar.onTap(closure)
  }
  
  /// Ask for push notification permission
  public func permitPush(closure: @escaping (PushNotification)->()) {
    notifier.permit(closure: closure)
  }
  
  /// Call closure when a push notification has been received
  public func onReceivePush(closure: @escaping (PushNotification,
    PushNotification.Payload, FetchCompletionHandler?)->()) {
    notifier.onReceive(closure: closure)
  }
  
  /// Call closure when a push notification has been received
  public func onOpenApplicationFromNotification(closure: @escaping (UNUserNotificationCenter, UNNotificationResponse, ()->()) -> ()) {
    notifier.onOpenApplicationFromNotification(closure: closure)
  }
  
  /// Set up singleton
  public override init() {
    super.init()
    NotifiedDelegate.singleton = self
    UNUserNotificationCenter.current().delegate = notifier
  }

  // MARK: - UIApplicationDelegate protocol methods
  
  // Have permission to use notifications
  public func application(_ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    notifier.register(token: deviceToken)
  }
  
  // User denied permission
  public func application(_ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error) {
    notifier.register(token: nil)
  }
  
  // Notification received
  public func application(_ application: UIApplication, didReceiveRemoteNotification
    userInfo: [AnyHashable : Any], fetchCompletionHandler
    completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    notifier.receive(userInfo, completionHandler)
  }
  
  /// Lock all view controllers not obeying the CanRotate protocol to portrait orientation
  public func application(_ application: UIApplication, supportedInterfaceOrientationsFor 
    window: UIWindow?) -> UIInterfaceOrientationMask {
    let topVc = topViewController(in: window?.rootViewController)
    if topVc is CanRotate {
      return .allButUpsideDown
    }
    else if topVc is CanRotateFromUnderlying && topVc?.navigationController?.viewControllers.last is CanRotate {
      return .allButUpsideDown
    }
    else if ((topVc?.presentingViewController as? UITabBarController)?.selectedViewController as? NavigationController)?.topViewController is CanRotate {
      ///in PDF the appearance of the context menu triggers this call and viewWillTransition > no menu is displayed on the phone and the behavior is ugly
      ///the presented VC is _UIContextMenuInteraction a private apple api
      return .allButUpsideDown
    }
    return .portrait
  }
  
  func topViewController(in rootViewController: UIViewController?) -> UIViewController? {
    guard let rootViewController = rootViewController else { return nil }
    if let tabBarController = rootViewController as? UITabBarController {
      return topViewController(in: tabBarController.selectedViewController)
    } else if let navigationController = rootViewController as? UINavigationController {
      return topViewController(in: navigationController.visibleViewController)
    } else if let presentedViewController = rootViewController.presentedViewController {
      return topViewController(in: presentedViewController)
    } else if let firstChild = rootViewController.children.first {
      return firstChild
    }
    return rootViewController
  }
  
} // NotifiedDelegate
