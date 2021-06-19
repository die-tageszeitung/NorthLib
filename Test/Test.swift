//
//  Test.swift
//
//  Created by Norbert Thies on 30.08.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import XCTest
extension XCTestCase: DoesLog {}

@testable import NorthLib

class EtcTests: XCTestCase {
  override func setUp() { super.setUp() }  
  override func tearDown() { super.tearDown() }

  func testTmppath() {
    let p1 = tmppath(), p2 = tmppath(), p3 = tmppath()
    print(p1, p2, p3)
    XCTAssertNotEqual(p1, p2)
    XCTAssertNotEqual(p2, p3)
  } 
  
  func testArray() {
    let a1 = [1,2,3,4,5,6,7,8,9,10]
    XCTAssertEqual(a1.rotated(1), [2,3,4,5,6,7,8,9,10,1])
    XCTAssertEqual(a1.rotated(-1), [10,1,2,3,4,5,6,7,8,9])
    XCTAssertEqual(a1.rotated(2), [3,4,5,6,7,8,9,10,1,2])
    XCTAssertEqual(a1.rotated(-2), [9,10,1,2,3,4,5,6,7,8])
  }
  
  func testCodableEnum() {
    enum TestEnum: String, CodableEnum {
      case one = "one(ONE)"
      case two = "two(TWO)"
      case three = "three"
      case unknown = "unknown"
    }
    var te = TestEnum.one
    print("MemoryLayout<TestEnum>.size = \(MemoryLayout<TestEnum>.size)")
    print("MemoryLayout<TestEnum>.stride = \(MemoryLayout<TestEnum>.stride)")
    print("MemoryLayout<TestEnum>.alignment = \(MemoryLayout<TestEnum>.alignment)")
    XCTAssertEqual(te.external, "ONE")
    XCTAssertEqual(te.representation, "one")
    XCTAssertEqual(te.description, "one(ONE)")
    XCTAssertEqual(te.index, 0)
    let jsEncoder = JSONEncoder()
    if let data = try? jsEncoder.encode(te), 
       let s = String(data: data, encoding: .utf8) {
      XCTAssertEqual(s, "[\"ONE\"]")
      let jsDecoder = JSONDecoder()
      if let ret = try? jsDecoder.decode([TestEnum].self, from: data) {
        XCTAssertEqual(ret[0].representation, "one")
      }
    }
    te = TestEnum.two
    XCTAssertEqual(te.external, "TWO")
    XCTAssertEqual(te.representation, "two")
    XCTAssertEqual(te.description, "two(TWO)")
    XCTAssertEqual(te.index, 1)
    te = TestEnum.three
    XCTAssertEqual(te.external, "three")
    XCTAssertEqual(te.representation, "three")
    XCTAssertEqual(te.description, "three")
    XCTAssertEqual(te.index, 2)
    te = TestEnum("one")!
    XCTAssertEqual(te.external, "ONE")
    XCTAssertEqual(te.representation, "one")
    XCTAssertEqual(te.description, "one(ONE)")
    XCTAssertEqual(te.index, 0)    
    te = TestEnum("two")!
    XCTAssertEqual(te.external, "TWO")
    XCTAssertEqual(te.representation, "two")
    XCTAssertEqual(te.description, "two(TWO)")
    XCTAssertEqual(te.index, 1)
    let jsDecoder = JSONDecoder()
    let data = "\"test\"".data(using: .utf8)!
    if let ret = try? jsDecoder.decode(TestEnum.self, from: data) {
      XCTAssertEqual(ret, TestEnum.unknown)
    }
  }
  
} // class EtcTests

class MathTests: XCTestCase {  
  override func setUp() { super.setUp() }  
  override func tearDown() { super.tearDown() }
  
  func testRemainder() {
    XCTAssertFalse(1.000001 =~ 1.000002)
    XCTAssertTrue((3.6 % 0.5) =~ 0.1)
    XCTAssertTrue((3.6 /~ 0.5) =~ 7.0)
  }
  
  func testLog() {
    let a: Double = 4
    XCTAssertTrue(a.log(base: 2) =~ 2.0)
  }
  
  func testGcd() {
    XCTAssertEqual(gcd(2,3), 1)
    XCTAssertEqual(gcd([]), 1)
    XCTAssertEqual(gcd([3]), 3)
    XCTAssertEqual(gcd([2,3]), 1)
    XCTAssertEqual(gcd([2,4,8]), 2)
    XCTAssertEqual(gcd([8,16,4]), 4)
  }
  
} // class MathTests

class StringTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    print("nodename: \(Utsname.nodename)")
    print("sysname:  \(Utsname.sysname)")
    print("release:  \(Utsname.release)")
    print("version:  \(Utsname.version)")
    print("machine:  \(Utsname.machine)")
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testSubscripts() {
    let s = "123456789"
    XCTAssertEqual(s.length, 9)
    XCTAssertEqual(s[0], "1")
    XCTAssertEqual(s[8], "9")
    XCTAssertEqual(s[1...2], "23")
    XCTAssertEqual(s[3..<9], "456789")
  }
  
  func testQuote() {
    var s = "a \"test\"\n and a \\ followed by \r, \t"
    XCTAssertEqual(s.quote(), "\"a \\\"test\\\"\\n and a \\\\ followed by \\r, \\t\"")
    XCTAssertEqual(s,s.quote().dequote())
    s = "number: "
    s += 14
    XCTAssertEqual(s,"number: 14")
  }
  
  func testIndent() {
    let s = "This is a string"
    XCTAssertEqual(s.indent(by:0), s)
    XCTAssertEqual(s.indent(by:1), " This is a string")
    XCTAssertEqual(s.indent(by:2), "  This is a string")    
    XCTAssertEqual(s.indent(by:3), "   This is a string")  
  }
  
  func testGroupMatches() {
    let s = "12:18:22 17:30:45"
    let re = #"(\d+):(\d+):(\d+)"#
    let ret = s.groupMatches(regexp:re)
    XCTAssertEqual(ret[0], ["12:18:22", "12", "18", "22"])
    XCTAssertEqual(ret[1], ["17:30:45", "17", "30", "45"])
    XCTAssertEqual("<123> <456>".groupMatches(regexp: #"<(\d+)>"#), [["<123>", "123"], ["<456>", "456"]])
    XCTAssertEqual("<123>".groupMatches(regexp: #"<(1(\d+))>"#), [["<123>", "123", "23"]])
  }

  func testMultiply() {
    XCTAssertEqual("abc" * 3, "abcabcabc")
    XCTAssertEqual("abc" * 0, "")
    XCTAssertEqual("abc" * 1, "abc")
    XCTAssertEqual(3 * "abc", "abc" * 3)
  }
  
}

class UsTimeTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testIsoConversion() {
    XCTAssertEqual(UsTime(iso: "2019-10-09 13:44:56").toString(), "2019-10-09 13:44:56.000000")
    XCTAssertEqual(UsTime(iso: "2019-10-09 13:44:56.123").toString(), "2019-10-09 13:44:56.123000")
    XCTAssertEqual(UsTime(iso: "2019-10-09 13:44:56.123", tz: "Europe/London").toString(tz: "Europe/London"),
                   "2019-10-09 13:44:56.123000")
    XCTAssertEqual(UsTime(iso: "2019-10-09").toString(), "2019-10-09 12:00:00.000000")
  }
  
}

class ZipTests: XCTestCase {
  
  var zipStream: ZipStream = ZipStream()
  var nerrors: Int = 0
  
  override func setUp() {
    super.setUp()
    Log.minLogLevel = .Debug
    self.zipStream.onFile { (name, data) in
      print( "file \(name!) with \(data!.count) bytes content found" )
      switch name! {
      case "a.txt": 
        if data!.md5 != "3740129b68388b4f41404d93ae27a79c" {
          print( "error: md5 sum doesn't match" )
          self.nerrors += 1
        }
      case "b.txt": 
        if data!.md5 != "abeecdc0f0a02c2cd90a1555622a84a4" {
          print( "error: md5 sum doesn't match" )
          self.nerrors += 1
        }
      default:
        print( "error: unexpected file" )
        self.nerrors += 1
      }
    }    
  }
  
  override func tearDown() {
    super.tearDown()
  }
    
  func testZipStream() {
    let bundle = Bundle( for: type(of: self) )
    guard let testPath = bundle.path(forResource: "test", ofType: "zip")
      else { return }
    guard let fd = FileHandle(forReadingAtPath: testPath)
      else { return }
    var data: Data
    repeat {
      data = fd.readData(ofLength: 10)
      if data.count > 0 {
        self.zipStream.scanData(data)
      }
    } while data.count > 0
    XCTAssertEqual(self.nerrors, 0)
    self.zipStream = ZipStream()
    nerrors = 0
  }
  
} // class ZipTests

class DefaultsTests: XCTestCase {
  
  @Default(key: "testBool")
  var testBool: Bool
  @Default(key: "testString")
  var testString: String
  @Default(key: "testCGFloat")
  var testCGFloat: CGFloat
  @Default(key: "testDouble")
  var testDouble: Double
  @Default(key: "testInt")
  var testInt: Int
  
  override func setUp() {
    super.setUp()
    Log.minLogLevel = .Debug
    Defaults.suiteName = "taz"
    Defaults.Notification.addObserver { (key, val, scope) in
      print("Notification: \(key)=\"\(val ?? "nil")\" in scope \"\(scope ?? "nil")\"")
    }
    let iPhoneDefaults: [String:String] = [
      "key1" : "iPhone-value1",
      "key2" : "iPhone-value2"
    ]
    let iPadDefaults: [String:String] = [
      "key1" : "iPad-value1",
      "key2" : "iPad-value2"
    ]
    Defaults.singleton.setDefaults(values: Defaults.Values(scope: "iPhone", values: iPhoneDefaults))
    Defaults.singleton.setDefaults(values: Defaults.Values(scope: "iPad", values: iPadDefaults))
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testDefaults() {
    let dfl = Defaults.singleton
    dfl[nil,"test"] = "non scoped"
    dfl["iPhone","test"] = "iPhone"
    dfl["iPad","test"]   = "iPad"
    XCTAssertEqual(dfl[nil,"test"], "non scoped")
    Defaults.print()
    if Device.isIphone {
      XCTAssertEqual(dfl["test"], "iPhone")
      XCTAssertEqual(dfl["key1"], "iPhone-value1")
      XCTAssertEqual(dfl["key2"], "iPhone-value2")
    }
    else if Device.isIpad {
      XCTAssertEqual(dfl["test"], "iPad")      
      XCTAssertEqual(dfl["key1"], "iPad-value1")
      XCTAssertEqual(dfl["key2"], "iPad-value2")
    }
  }
  
  func testWrappers() {
    testBool = false
    $testBool.onChange { val in print(val) }
    testBool = true
    XCTAssertEqual(testBool, true)
    testBool = true
    testBool = false
    testString = ""
    $testString.onChange { val in print(val) }
    testString = "test"
    XCTAssertEqual(testString, "test")
    testInt = 0
    $testInt.onChange { val in print(val) }
    testInt = 14
    XCTAssertEqual(testInt, 14)
    testCGFloat = 0
    $testCGFloat.onChange { val in print(val) }
    testCGFloat = 15
    XCTAssertEqual(testCGFloat, 15)
    testDouble = 0
    $testDouble.onChange { val in print(val) }
    testDouble = 16
    XCTAssertEqual(testDouble, 16)
  }

} // class DefaultsTest

// This unit test won't work without app with keychain entitlements added
class KeychainTests: XCTestCase {
  
  @Key("testBool")
  var testBool: Bool
  @Key("testString")
  var testString: String
  @Key("testCGFloat")
  var testCGFloat: CGFloat
  @Key("testDouble")
  var testDouble: Double
  @Key("testInt")
  var testInt: Int

  override func setUp() {
    super.setUp()
    Log.minLogLevel = .Debug
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testKeychain() {
    let kc = Keychain.singleton
    if let pw = kc["geheim"] { print("geheim = \"\(pw)\"") }
    kc["geheim"] = "huhu"
    XCTAssertEqual(kc["geheim"], "huhu")      
    kc["geheim"] = nil
    XCTAssertNil(kc["geheim"])
    kc["geheim"] = "fiffi"
  }
  
  func testWrappers() {
    testBool = false
    $testBool.onChange { val in print(val) }
    testBool = true
    XCTAssertEqual(testBool, true)
    testBool = true
    testBool = false
    testString = ""
    $testString.onChange { val in print(val) }
    testString = "test"
    XCTAssertEqual(testString, "test")
    testInt = 0
    $testInt.onChange { val in print(val) }
    testInt = 14
    XCTAssertEqual(testInt, 14)
    testCGFloat = 0
    $testCGFloat.onChange { val in print(val) }
    testCGFloat = 15
    XCTAssertEqual(testCGFloat, 15)
    testDouble = 0
    $testDouble.onChange { val in print(val) }
    testDouble = 16
    XCTAssertEqual(testDouble, 16)
  }

} // class KeychainTests

class FileTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    Log.minLogLevel = .Debug
    print("homePath:       \(Dir.homePath)")
    print("documentsPath:  \(Dir.documentsPath)")
    print("inboxPath:      \(Dir.inboxPath)")
    print("appSupportPath: \(Dir.appSupportPath)")
    print("cachePath:      \(Dir.cachePath)")
    print("tmpPath:        \(Dir.tmpPath)")
  }
  
  override func tearDown() {
    super.tearDown()
    Dir("\(Dir.tmpPath)/a").remove()
  }
  
  func testFile() {
    let d = Dir("\(Dir.tmpPath)/a")
    let d1 = Dir("\(Dir.tmpPath)/a/b.1")
    let d2 = Dir("\(Dir.tmpPath)/a/c.2")
    d.remove()
    XCTAssert(!d1.exists)
    XCTAssert(!d2.exists)
    d1.create(); d2.create()
    XCTAssert(d1.exists)
    XCTAssert(d1.isDir)
    XCTAssert(!d1.isFile)
    XCTAssert(!d1.isLink)
    let dirs = d.scan(isAbs: false)
    XCTAssert(dirs.count == 2)
    XCTAssert(dirs.contains("b.1"))
    XCTAssert(dirs.contains("c.2"))
    d1.remove()
    XCTAssert(!d1.exists)
    XCTAssert(d1.basename == "b.1")
    XCTAssert(d1.dirname == d.path)
    XCTAssert(d1.progname == "b")
    XCTAssert(d1.extname == "1")
    var f = File("\(d2.path)/test")
    File.open(path: f.path, mode: "a") { file in
      file.writeline("a test")
    }
    File.open(path: f.path, mode: "r") { file in
      let str = file.readline()
      XCTAssert(str == "a test\n")
    }
    let dpath = "\(d1.path)/new"
    let fpath = "\(dpath)/test"
    Dir(dpath).create()
    f.move(to: fpath)
    f = File(fpath)
    XCTAssert(f.exists)
    XCTAssert(f.isFile)
  }
  
} // FileTests

class CallbackTests: XCTestCase {
  
  class Test1 {
    @Callback(notification: "test")
    var whenReady: Callback.Store
  }

  // Visualize concurrent access to local var
  func testConcurrentVar() {
    let semaphore = DispatchSemaphore(value: 0)
    var result = 0
    async {
      async(after: 0.1) {
        result = 1
        semaphore.signal()
      }
    }
    semaphore.wait()
    XCTAssertEqual(result, 1)
  }
  
  private var count = 0
  // Make sure that *onMain* doesn't call the closure itself
  func testMainStack() {
    guard count < 10 else { count = 0; return }
    let tmp = count
    onMain { self.count += 1; self.testMainStack() }
    XCTAssertEqual(count, tmp)
    print(count)
  }
 
  override func setUp() {
    super.setUp()
  }
  
  func testClosures() {    
    let t1 = Test1()
    var str = ""
    Notification.receive("dog") { _ in print("dog received") }
    Notification.receive("test") { notif in
      let sender = notif.sender as? Self
      XCTAssertNotNil(sender)
      XCTAssertEqual(sender, self)
      print(notif.content ?? "nil")
      print("test received")
    }
    t1.whenReady { _ in str += "1" }
    t1.whenReady { _ in str += "2" }
    let idx = t1.$whenReady.store { _ in str += "." }
    XCTAssertEqual(idx, 2)
    t1.whenReady { _ in str += "3" }
    t1.whenReady { _ in str += "4" }
    t1.whenReady { msg in
      if let (content, sender) = msg as? Callback.Arg, let s = sender as? Self {
        XCTAssertEqual(s, self)
        print(content ?? "nil")
      }
    }
    t1.$whenReady.remove(idx)
    t1.$whenReady.notify(sender: self, wait: true)
    XCTAssertEqual(str, "1234")
    t1.$whenReady.notification = "dog"
    t1.$whenReady.notify(sender: self, wait: true)
    XCTAssertEqual(str, "12341234")
  }
  
} // CallbackTests
