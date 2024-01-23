//
//  ArrayBase.swift
//
//  Created by Norbert Thies on 12.12.18.
//  Copyright © 2018 Norbert Thies. All rights reserved.
//

import NorthLowLevel

public extension Array {
  
  /// appends one Element to an array
  @discardableResult
  static func +=(lhs: inout Array<Element>, rhs: Element) -> Array<Element> {
    lhs.append(rhs)
    return lhs
  }

  /// appends an array to an array
  @discardableResult
  static func +=(lhs: inout Array<Element>, rhs: Array<Element>) -> Array<Element> {
    lhs.append(contentsOf: rhs)
    return lhs
  }
  
  /// removes first element
  @discardableResult
  mutating func pop() -> Element? { 
    return self.isEmpty ? nil : self.removeFirst() 
  }
  
  /// appends one element at the end
  @discardableResult
  mutating func push(_ elem: Element) -> Self
  { self.append(elem); return self }
  
  /// rotates elements clockwise (n>0) or anti clockwise (n<0)
  func rotated(_ n: Int) -> Array {
    var ret: Array = []
    if n > 0 {
      ret += self[n..<count]
      ret += self[0..<n]
    }
    else if n < 0 {
      let from = count + n
      ret += self[from..<count]
      ret += self[0..<from]
    }
    else { ret = self }
    return ret
  }
  
  /// Safe acces to Array Items by Index returns null if Index did not exist
  func valueAt(_ index : Int) -> Element?{
    return self.indices.contains(index) ? self[index] : nil
  }
  
  /// Throwing bounds checking access by index
  func value(at index: Int) throws -> Element {
    guard self.indices.contains(index) else { throw "Array index out of bounds" }
    return self[index]
  }

  ///Safe acces to Array Items by Index returns null if Index did not exist, allows reverse index
  func valueAt(_ index : Int, allowReverseSearch: Bool) -> Element?{
    if allowReverseSearch {
      return valueAt(index < 0 ? self.count - 1 + index : index)
    }
    return valueAt(index)
  }
  
} // Array

extension Array: Copying where Element: Copying {
  
  /// creates a deep copy
  public func deepcopy() throws -> Array {
    try self.map { elem in try elem.deepcopy() }
  }
  
}

extension Array {
  /// The penultimate element of the collection.
  ///
  /// If the collection is empty, or has less then 2 elements the value of this property is `nil`.
  ///
  ///     let numbers = [10, 20, 30, 40, 50]
  ///     if let 2ndLastNumber = numbers.penultimate {
  ///         print(2ndLastNumber)
  ///     }
  ///     // Prints "10"
  @inlinable public var penultimate: Element? {
    get{
      let idx = count - 2///-2!! -1 is last!!
      guard idx >= 0 else { return nil }
      return valueAt(idx)
    }
  }
}


