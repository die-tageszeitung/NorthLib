//
//  FileFoundation.swift
//
//  Created by Norbert Thies on 20.11.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//
//  File extensions based on the Foundation framework
//

import Foundation

extension File {
  
  /// The default file manager
  public static var fm: FileManager { return FileManager.default }

  /// File modification time as Date
  public var mTime: Date { 
    get { return UsTime(self.mtime).date }
    set { self.mtime = UsTime(newValue).sec }
  }
  
  /// File access time as Date
  public var aTime: Date { 
    get { return UsTime(self.atime).date }
    set { self.atime = UsTime(newValue).sec }
  }
  
  /// File mode change time as Date
  public var cTime: Date { return UsTime(self.ctime).date }

  /// A File searched for in the main bundle
  public convenience init?(inMain fn: String) {
    let pref = File.progname(fn)
    let ext = File.extname(fn)
    guard let path = Bundle.main.path(forResource: pref, ofType: ext)
      else { return nil }
    self.init(path)
  }
  
  /// Initialisation with URL
  public convenience init(_ url: URL) {
    self.init(url.path)
  }
  
  /// Reads one data chunk from the file's current position
  public func readData() -> Data? {
    guard let mem = self.read() else { return nil }
    return mem.moveToData()
  }
    
  /// Writes the passed data to the file's current position
  @discardableResult
  public func write(data: Data) -> Int {
    let ptr = data.withUnsafeBytes { $0 }
    return write(ptr: ptr.baseAddress, length: data.count)
  }

  /// Returns a file URL
  public var url: URL { return URL(fileURLWithPath: path) }
  
  /// Returns the contents of the file (if it is an existing file)
  public var data: Data { 
    get {
      guard exists && isFile else { return Data() }
      let data = try? Data(contentsOf: url)
      if let data = data { return data }
      log("return data failed prevented crash!")
      return Data()
    }
    set (data) { try! data.write(to: url) }
  }
  
  /// Returns the contents of the file as String (if it is an existing file)
  public var string: String { 
    get {
      guard exists && isFile else { return String() }
      return data.string
    }
    set (string) {
      self.data = string.data(using: .utf8)!
    }
  }

  /// Returns the SHA256 checksum of the file's contents
  public var sha256: String { return data.sha256 }
  
} // File


/// The Dir class models a directory in the local file system
extension Dir {
    
  /// isBackup determines whether this directory is excluded from backups
  public var isBackup: Bool {
    get {
      guard exists else { return false }
      let val = try! url.resourceValues(forKeys: [.isExcludedFromBackupKey])
      return val.isExcludedFromBackup!
    }
    set {
      guard exists else { return }
      var val = URLResourceValues()
      var url = self.url
      val.isExcludedFromBackup = newValue
      try! url.setResourceValues(val)
    }
  }
  
  /// returns the path to the document directory
  public static var documentsPath: String {
    return try! fm.url(for: .documentDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true).path
  }
  
  /// returns the path to the Inbox directory
  public static var inboxPath: String {
    return "\(Dir.documentsPath)/Inbox"
  }
  
  /// returns the path to the app support directory
  public static var appSupportPath: String {
    return try! FileManager.default.url(for: .applicationSupportDirectory,
      in: .userDomainMask, appropriateFor: nil, create: true).path
  }
  
  /// returns the path to the cache directory
  public static var cachePath: String {
    return try! FileManager.default.url(for: .cachesDirectory,
      in: .userDomainMask, appropriateFor: nil, create: true).path
  }
  
  /// returns the searchResults directory
  public static var searchResultsPath: String {
    return Dir.appSupportPath.appending("/tmp-searchresults")
  }
  
  /// returns the path to the home directory
  public static var homePath: String {
    return NSHomeDirectory()
  }
  
  /// returns the document directory
  public static var documents: Dir {
    return Dir(Dir.documentsPath)
  }

  /// returns the Inbox directory
  public static var inbox: Dir {
    return Dir(Dir.inboxPath)
  }
  
  /// returns the application support directory
  public static var appSupport: Dir {
    return Dir(Dir.appSupportPath)
  }
  
  /// returns the cache directory
  public static var cache: Dir {
    return Dir(Dir.cachePath)
  }
  
  /// returns the home directory
  public static var home: Dir {
    return Dir(Dir.homePath)
  }
  
  /// returns the searchResults directory
  public static var searchResults: Dir {
    return Dir(Dir.searchResultsPath)
  }
    
  /// returns a list of files in the inbox
  public static func scanInbox(_ ext: String) -> [String] {
    return Dir.inbox.scanExtensions(ext)
  }
  
} // Dir
