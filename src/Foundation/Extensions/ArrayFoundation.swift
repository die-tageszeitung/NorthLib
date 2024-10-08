//
//  ArrayFoundation.swift
//
//  Created by Norbert Thies on 12.12.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import Foundation

public extension Array where Element: NSCopying {
  
  /// creates a deep copy of the array
  func copy() -> Array {
    self.map { elem in elem.copy() as! Element }
  }
}

public extension Array {
  ///append element if not nil
  mutating func appendIfPresent(_ element: Element?) {
    if let element = element {
      self.append(element)
    }
  }
}

public extension Array where Element == String {

  /// Returns a new string by concatenating the elements of the sequence,
  /// adding the given separator between each element.
  ///
  /// The following example shows how an array of strings can be joined to a
  /// single, comma-separated string:
  ///
  ///     let formats = ["html", "pdf", "mp3"]
  ///     let list = formats.joined(separator: ", ", lastSeparator: " and ")
  ///     print(list)
  ///     // Prints "html, pdf and mp3"
  ///
  /// - Parameter separator: A string to insert between each of the elements
  ///   - Parameter lastSeparator: A string to insert between last elements
  ///   in this sequence. The default separator is an empty string.
  /// - Returns: A single, concatenated string.
  func joined(separator: String, lastSeparator: String) -> String {
    guard count > 1 else { return self.first ?? "" }
    let allButLast = self.dropLast().joined(separator: separator)
    let lastElement = self.last ?? ""
    return allButLast + lastSeparator + lastElement
  }
}
