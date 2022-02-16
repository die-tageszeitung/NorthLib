//
//  Log.swift
//
//  Created by Norbert Thies on 21.08.17.
//  Copyright © 2017 Norbert Thies. All rights reserved.
//

import UIKit

/// Protocol to adopt from classes which like to use self.log, ...
public protocol DoesLog {
  var isDebugLogging: Bool { get }
}

extension DoesLog {
  
  public var isDebugLogging: Bool {
    get { return true }
  }
  
  public func log(_ msg: String? = nil, logLevel: Log.LogLevel = .Info, file:
    String = #file, line: Int = #line, function: String = #function) {
    Log.log(msg, object: self, logLevel: logLevel, file: file, line: line, function: function)
  }
  
  public func debug(_ msg: String? = nil, file: String = #file, line: Int = #line,
              function: String = #function) {
    if isDebugLogging {
      Log.debug(msg, object: self, file: file, line: line, function: function)
    }
  }
  
}


/// Common base classes to adopt DoesLog
extension UIView: DoesLog {}
extension UIViewController: DoesLog {}


/**
 All logging classes are defined in the namespace Log which is a class
 that doesn't allow instatiation of Log objects. 
*/ 

public class Log {
  
  /// class2s returns the classname of the passed object
  static func class2s(_ object: Any?) -> String? {
    var cn: String? = nil
    if let obj = object {
      cn = String(describing: type(of: obj))
    }
    return cn
  }
  
  /// Each logged message is categorized by a LogLevel
  public enum LogLevel: Int, CustomStringConvertible {
    case Debug  = 1
    case Info   = 2
    case Error  = 3
    case Fatal  = 4
    public var description: String { return toString() }
    public func toString() -> String {
      switch self {
      case .Info:  return "Info"
      case .Debug: return "Debug"
      case .Error: return "Error"
      case .Fatal: return "Fatal"
      }
    }
  } // enum Log.LogLevel
  
  /// A message to log
  open class Message: CustomStringConvertible {
    
    public struct Options: OptionSet {
      public let rawValue: Int
      public init(rawValue: Int) { self.rawValue = rawValue }
      
      static let Exception = Options(rawValue: 1<<0)
    } // struct LogMessage.Options
    
    public var isException: Bool {
      get { return self.options.contains(.Exception) }
      set { if newValue { self.options.insert(.Exception) } else { self.options.remove(.Exception) } }
    }
    
    // total number of messages produced
    private static var _messageCount = 0
    // serial queue to synchronize access to _messageCount
    private static var countQueue = DispatchQueue(label: "north.messageCount")
    /// number of messages logged in this session
    public static var messageCount: Int { return countQueue.sync { _messageCount } }
    
    public var serialNumber: Int = 0
    public var tstamp: UsTime
    public var logLevel: LogLevel
    public var options: Options = []
    public var fileName: String
    public var className: String?
    public var funcName: String
    public var line: Int
    public var message: String?
    public var onMainThread: Bool
    
    public var fileBaseName: String { return (fileName as NSString).lastPathComponent }
    public var id: String { return "\(fileBaseName):\(line)" }
    
    public var description: String { return toString() }
    
    public init( level: LogLevel, className: String?, fileName: String, funcName: String,
                 line: Int, message: String? ) {
      self.tstamp = UsTime.now()
      self.logLevel = level
      self.className = className
      self.fileName = fileName
      self.funcName = funcName
      self.line = line
      self.message = message
      self.onMainThread = Thread.isMainThread
      Message.countQueue.sync { [weak self] in
        Message._messageCount += 1
        self?.serialNumber = Message._messageCount
      }
    }
    
    public convenience init( level: LogLevel, object: Any?, fileName: String, funcName: String,
                             line: Int, message: String? ) {
      self.init( level: level, className: Log.class2s(object), fileName: fileName, 
                 funcName: funcName, line: line, message: message )
    }
    
    /// toString returns a minimalistic string representing the current message
    public func toString() -> String {
      let t = tstamp.date.components()
      var s = String( format: "(%@:%02d %02d:%02d:%02d) ", 
                      onMainThread ? "M" : "T",serialNumber, t.hour!,
                      t.minute!, t.second! )
      if let cn = className { s += cn + "." }
      s += "\(funcName) \(logLevel)"
      if isException { s += " Exception" }
      if let str = message { s += ":\n" + str.indent(by:2) }
      else {
        s += ":\n  at line \(line) in file \(fileBaseName)"
      }
      return s
    }
    
  } // class Log.Message
  
  /// A base class defining where to log to. This implementation simply
  /// logs to the standard output
  open class Logger {
    
    // previous/next in list of Loggers
    fileprivate var prev: Logger? = nil
    fileprivate var next: Logger? = nil
    
    public func append( _ logger: Logger ) {
      if let next = self.next { next.prev = logger }
      logger.next = self.next
      self.next = logger
      logger.prev = self
    }
    
    public func removeFromList() {
      if let prev = self.prev { prev.next = self.next }
      if let next = self.next { next.prev = self.prev }
    }
    
    /// whether to log to this destination
    public var isEnabled = true
    
    /// log a message to the standard output
    public func log( _ msg: Message ) {
      print( msg )
    }
    
    /// initializer does nothing
    public init() {}
    
  } // class Log.Logger

  /// minimal log level (.Info by default)
  static public var minLogLevel = LogLevel.Info
  
  // serial queue to synchronize access to _messageCount
  private static var logQueue = DispatchQueue(label: "north.logging")
  
  // head/tail of Loggers
  static private var head: Logger? = nil
  static private var tail: Logger? = nil
  
  /// Dictionary of classes to debug
  static public var debugClasses: [String:Bool] = [:]
  
  /// Closure to call on main thread in case of fatal error
  static var fatalClosure: ((Log.Message)->())? = nil
  
  static public func onFatal(closure: ((Log.Message)->())?) { fatalClosure = closure }
  
  // Log objects shall not be created
  private init() {}
  
  /// isDebugClass returns true if a class of given name is to debug
  static public func isDebugClass( _ className: String? ) -> Bool {
    var ret = false
    if let cn = className {
      if let val = debugClasses[cn] { ret = val }
    }
    return ret
  }
  
  /// define classes to debug
  static public func debug(classes: String...) {
    for cl in classes {
      debugClasses[cl] = true
    }
  }
  
  /// append(logger:) appends logging destinations (derived from class Logger)
  /// to the list of loggers
  static public func append(logger: Logger... ) {
    for lg in logger {
      if let tail = self.tail { tail.append(lg) }
      else { self.head = lg }
      self.tail = lg
    }
  }
  
  /// remove(logger:) removes logging destinations from the list of Loggers
  static public func remove(logger: Logger... ) {
    for lg in logger {
      if lg === head { head = lg.next }
      if lg === tail { tail = lg.prev }
      lg.removeFromList()
    }
  }
  
  /// logs a LogMessage
  static public func log( _ msg: Message ) {
    guard (msg.logLevel.rawValue >= minLogLevel.rawValue) ||
          isDebugClass(msg.className) else { return }
    logQueue.sync {
      if head == nil {
        head = Logger()
        tail = head
      }
      var logger = head
      while let lg = logger {
        if lg.isEnabled { lg.log( msg ) }
        logger = lg.next
      }
    }
    if let closure = fatalClosure, msg.logLevel == .Fatal {
      DispatchQueue.main.async { closure(msg) }
    }
  }
  
  /// log to certain output
  @discardableResult
  public static func log( _ message: String? = nil, object: Any? = nil,
    logLevel: LogLevel = .Info, file: String = #file, line: Int = #line,
    function: String = #function ) -> Message {
    let msg = Message( level: logLevel, object: object, fileName: file, funcName: function,
                       line: line, message: message )
    log(msg)
    return msg
  }
  
  @discardableResult
  public static func debug( _ msg: String? = nil, object: Any? = nil, file: String = #file, line: 
    Int = #line, function: String = #function ) -> Message {
    return log( msg, object: object, logLevel: .Debug, file: file, line: line, function: function )
  }
  
} // class Log
