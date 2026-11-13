//
//  FileLoggerFoundation.swift
//
//  Created by Norbert Thies on 19.06.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import Foundation

extension Log.FileLogger {
  
  /// URL of file to log to
  public var url: URL? {
    if let fn = filename { return URL(fileURLWithPath: fn) }
    else { return nil }
  }
  
  /// FileLogger logging to cache directory
  public static var cached: Log.FileLogger =
    Log.FileLogger(Log.FileLogger.tmpLogfile)

} // extension Log.FileLogger
