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
  
} // extension Date

/// A small extension to yield seconds
public extension TimeInterval {
  static var week: Double { get { return 7*day} }
  static var day: Double { get { return 24*hour} }
  static var hour: Double { get { return 60*minute} }
  static var minute: Double { get { return 60} }
}
