//
//  String Extensions
//
//  Created by Norbert Thies on 20.07.16.
//  Copyright © 2016 Norbert Thies. All rights reserved.
//
//  This file implements various low level String extensions.
//

import NorthLowLevel

/// String conforms to Error and can thus be thrown:
extension String: @retroactive Error {}

/// String extension supporting subscripts with Int and Int-Ranges.
public extension String {
  
  /**
   Returns the length of a String as number of characters.
      
   This property is simply an alias for 'count'.
   
   - returns: The number of characters in a string
   */
  var length: Int { return count }
  
  /**
   This subscript returns a String made from those characters addressed
   by the given half open Int-Range.
   
   - returns: A new String made of characters from self.
   */
  subscript (r: Range<Int>) -> String {
    let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                        upper: min(length, max(0, r.upperBound))))
    let start = index(startIndex, offsetBy: range.lowerBound)
    let end = index(start, offsetBy: range.upperBound - range.lowerBound)
    return String(self[start..<end])
  }
  
  /**
   This subscript returns a String made from those characters addressed
   by the given Int-ClosedRange.
   
   - returns: A new String made of characters from self.
   */
  subscript (r: ClosedRange<Int>) -> String {
    let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                        upper: min(length, max(0, r.upperBound))))
    let start = index(startIndex, offsetBy: range.lowerBound)
    let end = index(start, offsetBy: range.upperBound - range.lowerBound)
    return String(self[start...end])
  }
  
  /**
   This subscript returns the i'th character as a String.
   
   - returns: A new String made of self's i'th character.
   */
  subscript(i: Int) -> String {
    return self[i..<i+1]
  }
  
} // String subscripts


/// Various other String extensions
public extension String {
  
  /// Remove leading and trailing white space
  var trim: String {
    var tmp = withCString { str_trim($0) }
    let ret = String(cString: tmp!)
    str_release(&tmp)
    return ret
  }
  
  /// Escape XML special characters. Set isAttribute to true if the
  /// String should be used as an XML attribute.
  func xmlEscaped(isAttribute: Bool = false) -> String {
    let is_attribute: Int32 = isAttribute ? 1 : 0
    var tmp = withCString { str_xmlescape($0, is_attribute) }
    let ret = String(cString: tmp!)
    str_release(&tmp)
    return ret
  }
  
  /// Append Character to String
  @discardableResult
  static func +=(lhs: inout String, rhs: Character) -> String {
    lhs.append(rhs)
    return lhs
  }
  
  /// Append CustomStringConvertible to String
  @discardableResult
  static func +=<Type: CustomStringConvertible>(lhs: inout String, rhs: Type) -> String {
    lhs.append(rhs.description)
    return lhs
  }
  
  /// Return repititive String
  /// Eg. "abc" * 3 returns "abcabcabc"
  static func *<Type: BinaryInteger>(lhs: String, rhs: Type) -> String {
    var ret = ""
    let n = Int(rhs)
    for _ in 0..<n { ret += lhs }
    return ret
  }
  static func *<Type: BinaryInteger>(lhs: Type, rhs: String) -> String {
    return rhs*lhs
  }
  
  /** Returns a String witch is quoted, ie. surrounded by quotes.
 
   In addition the following characters are translated:
     \                 :   \\
     "                 :   \"
     linefeed          :   \n
     carriage return   :   \r
     backspace         :   \b
     tab               :   \t
   */
  func quote() -> String {
    var s = "\""
    for ch in self {
      switch ch {
      case "\"" :  s += "\\\""
      case "\\" :  s += "\\\\"
      case "\n" :  s += "\\n"
      case "\r" :  s += "\\r"
      case "\t" :  s += "\\t"
      default: s += ch
      }
    }
    return s + "\""
  }
  
  /** Returns a String with is dequoted, ie. surrounding quotes are removed.
   
   In addition the following escaped characters are translated:
     \\ :  \
     \" :  "
     \n :  linefeed
     \r :  carriage return
     \t :  tab
   */
  func dequote() -> String {
    var s = ""
    var wasEscaped = false
    var isFirst = true
    for ch in self {
      if isFirst && ch == "\"" { isFirst = false; continue }
      if wasEscaped {
        switch ch {
        case "\"" :  s += "\""
        case "\\" :  s += "\\"
        case "n"  :  s += "\n"
        case "r"  :  s += "\r"
        case "t"  :  s += "\t"
        default: s += "\\"; s += ch
        }
        wasEscaped = false
      }
      else {
        if ch == "\\" { wasEscaped = true }
        else { s += ch }
      }
    }
    if s.last == "\"" { s.remove(at: s.index(before: s.endIndex)) }
    return s
  }
  
  /**
   Returns an indented String where each row of characters is indented 
   by the number of spaces given with 'by'.
   
   If the argument 'first' has been given, this String is inserted in front of 
   the first row which is not indented. All succeeding rows are indented as usual.
   Eg. "abc\ndef".indent(by: 2, first: "- ") will result in: "- abc\n  def".
   **/
  func indent(by indent: Int, first: String? = nil) -> String {
    guard indent > 0 else { return self }
    var wasNl = true
    var ret = ""
    if let str = first { ret = str; wasNl = false }
    for ch in self {
      if wasNl { ret += String(repeating: " ", count: indent); wasNl = false }
      ret += ch
      if ch.isNewline { wasNl = true }
    }
    return ret
  }
  
  /// Returns true if self is case insensitive equal to "true", false otherwise
  var bool: Bool { return self.lowercased() == "true" }
  
  /// Returns an Int if possible
  var int: Int? { return Int(self) }
  
} // Various String extensions

/// Regexpr based regular expression String extension
public extension String {

  /// Match the passed regular expression against this string
  func match(_ pattern: String) -> [String]? { try! Regexpr(pattern).match(self) }

  /// Match the passed regular expression against this string globally
  func gmatch(_ pattern: String) -> [[String]]? { try! Regexpr(pattern).gmatch(self) }
  
  /// Substitute self according to sed-like substitution specification
  /// and return the result, self is unchanged.
  func substituted(_ spec: String, num: Int = -1, ndig: Int = -1) -> String?
    { Regexpr.subst(self, by: spec, num: num, ndig: ndig) }
  
  /// Substitute self according to sed-like substitution specification
  @discardableResult
  mutating func subst(_ spec: String, num: Int = -1, ndig: Int = -1) -> Self {
    if let s = self.substituted(spec, num: num, ndig: ndig) { self = s }
    return self
  }
  
  /// Returns true if the left hand side String is matched by the RE pattern
  static func =~(lhs: Self, rhs: Self) -> Bool { try! Regexpr(rhs).matches(lhs) }

}

/// Array<String> extension to convert to/from C's string arrays
public extension Array where Element == String {
  
  /// Calls a closure with C's string array with trailing nil pointer
  func withCStrings<Result>(_ body: (UnsafePointer<UnsafePointer<CChar>?>)
                            throws -> Result) throws -> Result {
    let n = self.count
    guard let av = av_alloc(Int32(n)) else { throw "Insufficient memory" }
    defer { av_release(av) }
    do {
      for i in 0..<n {
        av[i] = self[i].withCString { str_heap($0, 0) }
      }
      return try body(av_const(av))
    }
  }
  
  /// Initialize with C's constant string array
  init(_ av: UnsafePointer<UnsafePointer<CChar>?>) {
    self.init()
    let n = av_length(av)
    for i in 0..<n {
      self.append(String(cString: av[Int(i)]!))
    }
  }
  
  /// Initialize with C's mutable string array
  init(_ av: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>)
    { self.init(av_const(av)) }
  
  /// Return new String array from C's argv
  static func from(argv: UnsafePointer<UnsafePointer<CChar>?>) -> Array<String>
    { Array<String>(argv) }
  
  /// Return new String array from C's argv
  static func from(argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>)
    -> Array<String> { Array<String>(argv) }

} // Array<String> extension
