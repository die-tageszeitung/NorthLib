//
//  Console.swift
//  
//
//  Created by Norbert Thies on 06.07.23.
//

import NorthLowLevel

/// Rudimentary wrapper around Console/tty functions
open class Console: DoesLog {
  
  var input: UnsafeMutablePointer<tty_t>?
  var output: UnsafeMutablePointer<tty_t>?
  
  public init(_ path: String? = nil) {
    if let path {
      path.withCString { p in
        input = tty_fopen(p)
        output = tty_fopen(p)
      }
    }
    else {
      input = tty_open(0)
      output = tty_open(1)
    }
  }
  
  /// Read a String from the console without leading and trailing WS
  func gets() -> String? {
    var s = tty_getstring(input)
    defer { str_release(&s) }
    if let s { 
      let str = String(validatingUTF8: s) 
      return str?.trim
    }
    return nil
  }
  
  /// Read a String from the console without echo
  func negets() -> String? {
    var s = tty_negetstring(input)
    defer { str_release(&s) }
    if let s { 
      let str = String(validatingUTF8: s) 
      return str?.trim
    }
    return nil
  }
  
  /// Write String to the console (no newline is added)
  func puts(_ str: String) {
    _ = str.withCString { s in
      tty_write(output, s)
    }
  }

  /// Write String to the console (newline is added)
  func putsln(_ str: String) {
    let s = str + "\n"
    _ = s.withCString { s in
      tty_write(output, s)
    }
  }

  deinit {
    if input != nil {
      tty_close(input)
    }
    if output != nil {
      tty_close(output)
    }
  }
  
} // Console
