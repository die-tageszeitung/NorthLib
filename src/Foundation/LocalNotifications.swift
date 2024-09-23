//
//  LocalNotifications.swift
//  NorthLib
//
//  Created by Ringo Müller on 22.11.21.
//  Copyright © 2021 Norbert Thies. All rights reserved.
//

import Foundation
import UserNotifications

open class LocalNotifications: DoesLog {
  
  ///Helper to trigger local Notification if App is in Background
  ///use payload to add custom data
  public static func notify(title:String? = nil,
                            subtitle:String? = nil,
                            message:String,
                            sound: UNNotificationSound = UNNotificationSound.default,
                            badge: Int? = nil,
                            attachmentURL: URL? = nil,
                            categoryIdentifier: String? = nil,
                            notificationIdentifier: String? = nil,
                            payload: [AnyHashable : Any]? = nil,
                            delay: TimeInterval = 5.0

  ){
    let fireDate = Date().addingTimeInterval(delay)
    let identifier = notificationIdentifier ?? "Notification-\(title ?? subtitle ?? message)-\(fireDate.ddMMyy_HHmmss)"
    
    let content = UNMutableNotificationContent()
    if let title = title { content.title = title }
    if let subtitle = subtitle { content.subtitle = subtitle }
    content.body = message
    content.sound = sound
    if let payload = payload { content.userInfo = payload }
  
    if let attachmentURL = attachmentURL {
      do {
        let attachment = try UNNotificationAttachment(identifier: "\(identifier)-ai", url: attachmentURL)
        content.attachments = [attachment]
      }
      catch let error { Log.fatal(error) }
    }
    if let categoryIdentifier = categoryIdentifier { content.categoryIdentifier = categoryIdentifier }
    if let badge = badge { content.badge = NSNumber(value: badge) }
    

    let dateComponents = Calendar.current.dateComponents(Set(arrayLiteral: Calendar.Component.year, Calendar.Component.month, Calendar.Component.day, Calendar.Component.hour, Calendar.Component.minute, Calendar.Component.second), from: fireDate)
    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
    let request = UNNotificationRequest(identifier: "\(identifier)-ni",
                                        content: content,
                                        trigger: trigger)
    UNUserNotificationCenter.current().add(request, withCompletionHandler: { error in
      if let error = error {
        Log.log("notification with error: \(error)")
      } else {
        Log.log("notification setup succeed")
      }
    })
    Log.log("notification added for \(fireDate.ddMMyy_HHmmss)")
  }
}
