//
//  Error.swift
//
//  Created by Norbert Thies on 18.06.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import NorthLowLevel

extension Result {
  /// error() is similar to get() and returns the Failure value if available
  public func error() -> Failure? {
    if case .failure(let err) = self { return err }
    else { return nil }
  }
  
  /// value returns the success value (or nil if no success)
  /// An Error is logged.
  public func value(file: String = #file, line: Int = #line,
    function: String = #function) -> Success? {
    switch self {
    case .success(let val): return val
    case .failure(let err):
      Log.error(err, object: nil, file: file, line: line, function: function)
      return nil
    }
  }
} // Result

extension DoesLog {
  
  @discardableResult
  public func error(_ msg: String? = nil, file: String = #file, line: Int = #line,
                    function: String = #function) -> Log.Error {
    return Log.error(msg, object: self, file: file, line: line, function: function)
  }
 
  @discardableResult
  public func serror(_ msg: String? = nil, file: String = #file, line: Int = #line,
                     function: String = #function) -> Log.Error {
    var tmp: String
    let serr = "System Error: \(String(cString: str_error(-1)!))"
    if let s = msg { tmp = "\(s)\n  \(serr)" }
    else { tmp = serr }
    return Log.error(tmp, object: self, file: file, line: line, function: function)
  }
  
  @discardableResult
  public func check(_ value: Bool, _ msg: String? = nil, file: String = #file,
                    line: Int = #line, function: String = #function) -> Bool {
    var ret = false
    if value { ret = true }
    else {
      var str = "*** Check failed"
      if let m = msg { str += ": \(m)" }
      Log.error(str, object: self, file: file, line: line, function: function)
    }
    return ret
  }
  
  @discardableResult
  public func error<T: Swift.Error>(_ error: T, file: String = #file, line: Int = #line,
                function: String = #function) -> Log.EnclosedError<T> {
    return Log.error(error, object: self, file: file, line: line, function: function)
  }
  
  @discardableResult
  public func logIf<T: Swift.Error>(_ error: T?, file: String = #file, line: Int = #line,
                function: String = #function) -> Log.EnclosedError<T>? {
    guard let error = error else { return nil }
    return Log.error(error, object: self, file: file, line: line, function: function)
  }
  
  @discardableResult
  public func fatal(_ msg: String? = nil, file: String = #file, line: Int = #line,
                    function: String = #function) -> Log.Error {
    return Log.fatal(msg, object: self, file: file, line: line, function: function)
  }
  
  @discardableResult
  public func fatal<T: Swift.Error>(_ error: T, file: String = #file, line: Int = #line,
                function: String = #function) -> Log.EnclosedError<T> {
    return Log.fatal(error, object: self, file: file, line: line, function: function)
  }
  
  @discardableResult
  public func exception(_ msg: String? = nil, file: String = #file, line: Int = #line,
                        function: String = #function) -> Log.Error {
    return Log.exception(msg, object: self, file: file, line: line, function: function)
  }
  
  @discardableResult
  public func exception<T: Swift.Error>(_ error: T, file: String = #file,
      line: Int = #line, function: String = #function) -> Log.EnclosedError<T> {
    return Log.exception(error, object: self, file: file, line: line,
                         function: function)
  }
  
} // extension DoesLog


extension Log {
  
  /** 
   A Log.Error contains a Log.Message that also serves as an Error and can be thrown
   as an exception.
   
   A logged Error may refer to an Error that may have caused this Error. Therefore
   it may optionally refer to an Error that has occurred previously.
   */
  open class Error: Swift.Error {
    
    var message: Message
    
    /// A previous Exception causing this Exception
    public var previous: Log.Error? = nil
    
    /// The error description
    public var description: String { message.toString() }
    
    /// The localized description according to the Error protocol
    public var localizedDescription: String { description }

    /// Initialisation with a previous ErrorMessage
    public init( level: LogLevel, className: String?, fileName: String, funcName: String,
                 line: Int, message: String?, previous: Log.Error? ) {
      self.message = Message(level:level, className:className, fileName:fileName, funcName:funcName,
                             line:line, message:message)
      self.previous = previous
    }
    
  } // class Log.Error
  
  open class EnclosedError<T: Swift.Error>: Log.Error {
    
    /// The enclosed Error
    public var enclosed: T
    
    public init(enclosed: T, level: LogLevel, className: String?, fileName: String,
                funcName: String, line: Int, message: String?, previous: Log.Error?) {
      self.enclosed = enclosed
      super.init(level:level, className:className, fileName:fileName, funcName:funcName,
                 line:line, message:message, previous: previous)
      var emsg: String
      switch enclosed {
        case let str as String: emsg = str
        case let e as Log.Error: emsg = e.description
        default: emsg = "\(typeName(enclosed)): \(String(describing: enclosed))"
      }
      if let msg = self.message.message {
        self.message.message = msg + "\n  " + "Enclosed Error: \(emsg)"
      }
      else { self.message.message = "Enclosed Error: \(emsg)" }
    }

  } // class Log.EnclosedError
    
  @discardableResult
  public static func error(_ message: String? = nil, previous: Log.Error? = nil, object: Any? = nil,
    logLevel: LogLevel = .Error, file: String = #file, line: Int = #line,
    function: String = #function) -> Log.Error {
    let msg = Error(level: logLevel, className: class2s(object), fileName: file, funcName: function,
                    line: line, message: message, previous: previous)
    log(msg.message)
    return msg
  }
    
  @discardableResult
  public static func error<T: Swift.Error>(_ error: T, previous: Log.Error? = nil, object: Any? = nil,
    logLevel: LogLevel = .Error, file: String = #file, line: Int = #line,
    function: String = #function) -> EnclosedError<T> {
    let msg = EnclosedError<T>(enclosed: error, level: logLevel, className: class2s(object), 
        fileName: file, funcName: function, line: line, message: nil, previous: previous)
    log(msg.message)
    return msg
  }
  
  @discardableResult
  public static func exception(_ message: String? = nil, previous: Log.Error? = nil, object: Any? = nil,
    logLevel: LogLevel = .Error, file: String = #file, line: Int = #line,
    function: String = #function) -> Log.Error {
    let msg = Error(level: logLevel, className: class2s(object), fileName: file, funcName: function,
                    line: line, message: message, previous: previous)
    msg.message.isException = true
    log(msg.message)
    return msg
  }
  
  @discardableResult
  public static func exception<T: Swift.Error>(_ error: T, previous: Log.Error? = nil, object: Any? = nil,
    logLevel: LogLevel = .Error, file: String = #file, line: Int = #line,
    function: String = #function) -> EnclosedError<T> {
    let msg = EnclosedError<T>(enclosed: error, level: logLevel, className: class2s(object), 
      fileName: file, funcName: function, line: line, message: nil, previous: previous)
    msg.message.isException = true
    log(msg.message)
    return msg
  }
 
  @discardableResult
  public static func fatal(_ message: String? = nil, previous: Log.Error? = nil, object: Any? = nil,
    logLevel: LogLevel = .Fatal, file: String = #file, line: Int = #line,
    function: String = #function) -> Log.Error {
    let msg = Error(level: logLevel, className: class2s(object), fileName: file, funcName: function,
                    line: line, message: message, previous: previous)
    log(msg.message)
    return msg
  }
  
  @discardableResult
  public static func fatal<T: Swift.Error>(_ error: T, previous: Log.Error? = nil, object: Any? = nil,
    logLevel: LogLevel = .Fatal, file: String = #file, line: Int = #line,
    function: String = #function) -> EnclosedError<T> {
    let msg = EnclosedError<T>(enclosed: error, level: logLevel, className: class2s(object), 
      fileName: file, funcName: function, line: line, message: nil, previous: previous)
    log(msg.message)
    return msg
  }
  
} // extension Log
