//
//  String Extensions
//
//  Created by Norbert Thies on 20.07.16.
//  Copyright © 2016 Norbert Thies. All rights reserved.
//
//  This file implements various String extensions based on the Foundation framework.
//

import Foundation


/// Pattern matching string extension
public extension String {
  
  /// allMatches returns an array of strings representing all matches
  /// of the passed regular expression in 'self'.
  func allMatches(regexp: String) -> [String] {
    do {
      let re = try NSRegularExpression(pattern: regexp)
      let res = re.matches(in: self, range: NSRange(self.startIndex..., in: self))
      return res.map {
        String(self[Range($0.range, in: self)!])
      }
    } catch { return [] }
  }
  
  /// groupMatches returns an array of strings representing matches of the passed
  /// regular expression.
  ///
  /// Each match itself is an array
  /// of strings matching the groups used in the regular expression. The first
  /// element of the String array is always the completely matched regular expression.
  /// Ie. "<123> <456>".groupMatches(regexp: #"<(\d+)>"#) yields
  /// [["<123>", "123"], ["<456>", "456"]].
  /// If a group contains subgroups then the match representing the enclosing
  /// group preceeds the subgroup in the array. Ie "<123>".groupMatches(#"<(1(\d+))>"#)
  /// returns ["<123>", "123", "23"].
  func groupMatches(regexp: String) -> [[String]] {
    do {
      let re = try NSRegularExpression(pattern: regexp)
      let res = re.matches(in: self, range: NSRange(self.startIndex..., in: self))
      return res.map { match in
        return (0..<match.numberOfRanges).map {
          let rangeBounds = match.range(at: $0)
          guard let range = Range(rangeBounds, in: self) else { return "" }
          return String(self[range])
        }
      }
    } catch let error {
      Log.fatal(error)
      return []
    }
  }
  
} // extension String  - pattern matching

// MARK: - extension String isValidEmail
extension String {
  public func isValidEmail() -> Bool {
    let emailRegEx = "[A-Z0-9a-z.!#_%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
    return emailPred.evaluate(with: self)
  }
}

// MARK: - Localized Helper without Comment
public func Localized(_ key: String) -> String {
  return NSLocalizedString(key, comment: "n/a")
}
public func Localized(keyWithFormat: String, _  arguments: CVarArg...) -> String {
  return String(format: Localized(keyWithFormat), arguments: arguments)
}

public extension String {
  
  /// Remove leading and trailing white space of a multiword string
  var trimed: String {
    return self.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  /// returns lastPathComponent
  var lastPathComponent: String {
    return (self as NSString).lastPathComponent
  }

}

public extension String {
  /// App Version 1.234.567 returns "1234567" | 1.2.3 returns 1002003 | 1.20.30 returns 1020030
  /// Warning   01.2001.40003 > 01.2002.0000001, do not use it for 4 digit Version Numbers
  var semanticVersionCode: String {
    return "\(Int(self.split(separator: ".").compactMap{String(format: "%03d", Int($0) ?? 0)}.joined()) ?? 42)"
  }
}
