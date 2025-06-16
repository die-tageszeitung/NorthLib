//
//  DateFoundation.swift
//
//  Created by Norbert Thies on 06.07.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import Foundation

public extension Date {
  
  /// Returns components relative to gregorian calendar in optionally given time zone
  func components(tz: String? = nil) -> DateComponents {
    var cal = Calendar.current
    if let tz = tz {
      if let tmp = TimeZone(identifier: tz) {
        cal = Calendar(identifier: .gregorian)
        cal.timeZone = tmp
      }
    }
    let cset = Set<Calendar.Component>([.year, .month, .day, .hour, .minute, .second, .weekday])
    return cal.dateComponents(cset, from: self)    
  }
 
  /// Returns a String as ISO-Date/Time, ie. "YYYY-MM-DD hh:mm:ss"
  func isoTime(tz: String? = nil) -> String {
    let dc = components(tz: tz)
    return String(format: "%04d-%02d-%02d %02d:%02d:%02d.%06d", dc.year!, dc.month!,
                  dc.day!, dc.hour!, dc.minute!, dc.second!)
  }
 
  /// Returns a String as ISO-Date, ie. "YYYY-MM-DD"
  func isoDate(tz: String? = nil) -> String {
    let dc = components(tz: tz)
    return String(format: "%04d-%02d-%02d", dc.year!, dc.month!, dc.day!)
  }
  
  /// Add (or subtract) number of days
  mutating func addDays(_ days: Int) {
    self = Calendar.current.date(byAdding: .day, value: days, to: self)!
  }
  
  /// Returns the start of the day for the current date in the current calendar.
  var startOfDay: Date {
      return Calendar.current.startOfDay(for: self)
  }

  var endOfDay: Date? {
    var components = DateComponents()
    components.day = 1
    components.second = -1
    return Calendar.current.date(byAdding: components, to: startOfDay)
  }
  
  /// The number of seconds that have passed since the start of the day.
  var secondsSinceStartOfDay: TimeInterval {
      return timeIntervalSince(Calendar.current.startOfDay(for: self))
  }
  
  func addingHours(_ hours: Int) -> Date {
      return self.addingTimeInterval(TimeInterval(hours * 3600))
  }
  
  var startOfMonth: Date? {
    let components = Calendar.current.dateComponents([.year, .month], from: startOfDay)
    return Calendar.current.date(from: components)
  }
  
  
  var endOfMonth: Date? {
    guard let startOfMonth = startOfMonth else {
      return nil
    }
    return Calendar.current.date(byAdding: DateComponents(month: 1, second: -1),
                                 to: startOfMonth)
  }
  
  /// Check if an given Date exists and time Interval is smaller than given timeInterval
  /// - Parameters:
  ///   - date: date to compare with now
  ///   - interval: interval to use; default 1 Hour
  /// - Returns: true if exists and not expired
  static func existsAndNotExpired(_ date: Date?, intervall:TimeInterval = TimeInterval.hour) -> Bool {
    guard let d = date else { return false }
    return Date().timeIntervalSince(d) < intervall
  }
  
  var ddMMyy_HHmmss:String{
    get{
      let dateFormatterGet = DateFormatter()
      dateFormatterGet.dateFormat = "yy-MM-dd_HH:mm:ss"
      return dateFormatterGet.string(from: self)
    }
  }
  
  var timeFromDate:String{
    get{
      let dateFormatterGet = DateFormatter()
      dateFormatterGet.dateFormat = "HH:mm"
      return dateFormatterGet.string(from: self)
    }
  }
  
} // extension Date

/// A small extension to yield seconds
public extension TimeInterval {
  static var week: Double { get { return 7*day} }
  static var day: Double { get { return 24*hour} }
  static var hour: Double { get { return 60*minute} }
  static var minute: Double { get { return 60} }
}

public extension TimeInterval {
  var minuteSecondsString: String? {
    guard self.isFinite && self.isNaN == false else { return nil }
    let formater = DateComponentsFormatter()
    formater.zeroFormattingBehavior = .pad
    formater.unitsStyle = .positional
    formater.allowedUnits = [.minute, .second]
    return formater.string(from: self)
  }
  
  /// Converts the TimeInterval into a human-readable string using `DateComponentsFormatter`.
  var readable: String {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated // Use short units like "h", "m", "s"
    formatter.allowedUnits = [.day, .hour, .minute, .second] // Customize units as needed
    formatter.zeroFormattingBehavior = .dropAll // Drop zero values
    return formatter.string(from: self) ?? "0s"
  }
}
