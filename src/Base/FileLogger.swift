//
//  FileLogger.swift
//
//  Created by Norbert Thies on 19.06.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import NorthLowLevel
import Foundation

extension Log {
  
  /// A FileLogger writes all passed log messages to a File
  open class FileLogger: Logger {
    
    public static let maxAge: TimeInterval = 48 * 3600
    public static let maxSize = 300 * 1024
    
    public func rotateIfNeeded() {
      guard let fn = filename else { return }
      
      let file = File(fn)
      let age = Date().timeIntervalSince1970 - TimeInterval(file.mtime)
      
      ///do not rotate empty files initially
      guard file.size > 0 else { return }
      
      guard age > Self.maxAge || file.size > Self.maxSize else {
        return
      }
      ///Log only appears on App-Resume not in Application Start
      Log.log("###### Rotate Logfile while App is Running #########")
      rotate()
      Log.log("###### Rotated Logfile while App is Running #########")
    }
     
    @discardableResult
    public func rotate() -> Bool {
      guard let currentFilename = filename else { return false }

      // Close current logfile
      file_close(&fp)

      let lastFile = File(FileLogger.lastLogfile)
      let currentFile = File(currentFilename)

      // Rotate existing last logfile
      if lastFile.exists {
        lastFile.copy(to: FileLogger.secondLastLogfile, isOverwrite: true)
      }

      // Save current logfile as last logfile
      currentFile.copy(to: FileLogger.lastLogfile, isOverwrite: true)

      // Always create a fresh logfile
      return file_open(&fp, currentFilename, "w") == 0
    }
    
    /// pathname of file to log to
    public private(set) var filename: String?
    
    /// file descriptor of file to log to
    public private(set) var fp: fileptr_t?
    
    /// contents of logfile as Memory
    public var mem: Memory? {
      if let fn = filename {
        return File(fn).mem
      }
      return nil
    }
    
    /// default/current logfile
    public static var tmpLogBase: String = "\(Dir.tmpPath)/default"
    public static var tmpLogfile: String = tmpLogBase + ".log"
    
    /// former Logfile
    public static var lastLogfile: String = tmpLogBase + "-old.log"
    
    /// prev old Logfile
    public static var prevLastLogfile: String = tmpLogfile + ".old"
    
    /// oldest Logfile used only for internal users
    public static var secondLastLogfile: String = tmpLogBase + "-old2.log"
    
    /// The FileLogger must be initialized with a filename
    public init(_ fname: String? = nil) {
      let fn = fname ?? FileLogger.tmpLogfile
      if file_open(&fp, fn, "a") == 0 {
        self.filename = fn
      }
      super.init()
    }
    
    // closes file pointer upon deconstruction
    deinit { file_close(&self.fp) }
    
    /// log a message to the logfile
    public override func log(_ msg: Message) {
      if let fp = self.fp {
        var txt = String(describing: msg)
        if !txt.hasSuffix("\n") { txt = txt + "\n" }
        _ = txt.withCString { file_write(fp, $0, str_len($0)) }
        file_flush(fp)
      }
    }
    
  } // class FileLogger
  
} // extension Log
