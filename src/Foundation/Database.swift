//
//  Database.swift
//
//  Created by Norbert Thies on 10.04.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import Foundation
import CoreData

open class Database: DoesLog, ToString {
  
  /// name of database
  public var name: String
  
  /// name of data model
  public var modelName: String
  
  /// URL of data model
  public var modelURL: URL?
  
  /// actual version of App model
  public var newModelVersion = 1
  
  /// current version of stored DB model
  public var oldModelVersion = 1
  
  /// the model object
  public lazy var model = try! getModel(modelURL: modelURL)
  
  /// the persistent store coordinator
  public lazy var coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
  
  /// The persistent store
  public var persistentStore: NSPersistentStore?
  
  /// application support directory
  public static var appDir: String { return Dir.appSupportPath }
    
  /// directory where DB is stored
  public static var dbDir: String { return Database.appDir + "/database" }
  
  /// path of database with given database name
  public static func dbPath(name: String) -> String
    { return Database.dbDir + "/\(name).sqlite" }

  /// Load model from model dictionary (if available) or from single model
  /// file. Evaluate model version from the model's 'versionIdentifiers' 
  /// property which is expected to be a single integer number.
  private func getModel(modelURL: URL? = nil) throws -> NSManagedObjectModel { 
    var murl: URL? = modelURL
    if murl == nil {
      murl = Bundle.main.url(forResource: modelName, withExtension: "momd") ??
             Bundle.main.url(forResource: modelName, withExtension: "mom")
    }
    guard let murl = murl else {
      throw fatal("Can't find Core Data model for \(modelName)")
    }
    guard let model = NSManagedObjectModel(contentsOf: murl) else {
      throw fatal("Can't read Core Data model for \(modelName)")
    }
    for v in model.versionIdentifiers {
      if let s = v as? String, let mver = Int(s), mver > self.newModelVersion {
        self.newModelVersion = mver
      }
    }
    return model
  }
 
  /// returns true if a database with given name exists
  public static func exists(name: String) -> Bool {
    File(Database.dbPath(name: name)).exists
  }
  
  /// remove database
  public static func dbRemove(name: String) 
    { File(Database.dbPath(name: name)).remove() }
  
  /// rename database
  public static func dbRename(old: String, new: String) {
    let o = File(Database.dbPath(name: old))
    let n = File(Database.dbPath(name: new))
    if o.exists { o.move(to: n.path) }
  }
  
  /// path of database
  public var dbPath: String { return Database.dbPath(name: name) }
  
  /// managed object context of database
  public var context: NSManagedObjectContext?
  
  /// Callback/Notification to send on version change
  @Callback
  public var onVersionChange: Callback<Void>.Store
  
  /// create/open database once and set oldModelVersion and newModelVersion
  /// from the model read and user defaults.
  private func openOnce(closure: @escaping (Error?)->()) {
    self.context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    self.context?.persistentStoreCoordinator = coordinator
    let path = Database.dbPath(name: name)
    let isNew = !File(path).exists
    Dir(Database.dbDir).create()
    let dbURL = URL(fileURLWithPath: path)
    let queue = DispatchQueue.global(qos: .userInteractive)
    queue.async { [weak self] in
      guard let self = self else { return }
      do {
        // let's do lightweight migration if possible
        let options = [NSMigratePersistentStoresAutomaticallyOption: true, 
                       NSInferMappingModelAutomaticallyOption: true]
        self.persistentStore = try self.coordinator.addPersistentStore(ofType:
          NSSQLiteStoreType, configurationName: nil, at: dbURL, options: options)
        DispatchQueue.main.sync { 
          let dfl = Defaults.singleton
          let vkey = "\(self.modelName)Version"
          if let s = dfl[vkey], let ver = Int(s) {
            self.oldModelVersion = ver
          }
          else if isNew { self.oldModelVersion = 0 }
          else { self.oldModelVersion = 1 }
          if self.newModelVersion != self.oldModelVersion {
            self.$onVersionChange.notify(sender: self)
          }
          dfl[vkey] = "\(self.newModelVersion)"
          closure(nil) 
        }
      }
      catch let err {
        closure(self.error(err))
      }
    }
  }

  public func open(closure: @escaping (Error?)->()) {
    self.openOnce { [weak self] err in
      guard let self = self else { return }
      if err != nil {
        Database.dbRemove(name: self.name)
        self.openOnce { [weak self] err in
          guard let self = self else { return }
          if err != nil { 
            closure(self.error("Can't create create database"))
          }
          else { closure(nil) }
        }
      }
      else { closure(nil) }
    }
  }
  
  /// Closes the DB
  public func close() {
    if let ps = persistentStore { try! coordinator.remove(ps) }
  }
  
  /// Removes DB and opens a new initialized version
  public func reset(closure: @escaping (Error?)->()) {
    close()
    Database.dbRemove(name: self.name)
    open(closure: closure)
  }
 
  public init(name: String,  model: String, modelURL: URL? = nil) {
    self.modelName = model
    self.modelURL = modelURL
    self.name = name
  }
  
  public func toString() -> String {
    "\(name), model(\(modelName)):\n  \(dbPath)"
  }

  public func save(_ context: NSManagedObjectContext? = nil, errorCallback: ((NSManagedObjectContext, Error) -> ())? = nil) {
    guard let ctx = (context != nil) ? context : self.context else {
      log("Fatal: no Context to save")
      return
    }
    guard ctx.hasChanges else { return }
    do {
      try ctx.save()
    }
    catch let error {
      log("fail to save with error: \(error)")
      errorCallback?(ctx, error)
    }
  }
  
  public func inBackground(_ closure: @escaping (NSManagedObjectContext)->()) {
    let ctx = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    ctx.persistentStoreCoordinator = self.coordinator
    ctx.perform {
      closure(ctx)
      self.save(ctx)
    }
  }
  
} // class Database
