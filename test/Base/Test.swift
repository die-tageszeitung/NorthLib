//
//  Test.swift
//
//  Created by Norbert Thies on 30.08.19.
//  Copyright © 2019 Norbert Thies. All rights reserved.
//

import XCTest

@testable import NorthBase

class StringTests: XCTestCase {
  
  override static func setUp() {
    super.setUp()
  }
  
  override static func tearDown() {
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
  
  func testMultiply() {
    XCTAssertEqual("abc" * 3, "abcabcabc")
    XCTAssertEqual("abc" * 0, "")
    XCTAssertEqual("abc" * 1, "abc")
    XCTAssertEqual(3 * "abc", "abc" * 3)
  }
  
  func testCStringArrays() {
    let array = ["one", "two", "three", "four"]
    let a = try! array.withCStrings { Array<String>($0) }
    for i in 0..<array.count {
      XCTAssertEqual(array[i], a[i])
    }
  }
  
  func testXmlEscape() {
    var tmp = "<>&'\""
    var escaped = tmp.xmlEscaped()
    XCTAssertEqual(escaped, "&lt;&gt;&amp;'\"")
    escaped = tmp.xmlEscaped(isAttribute: true)
    XCTAssertEqual(escaped, "&lt;&gt;&amp;&apos;&quot;")
    tmp = "<abc>def'ghi\"jkl&mno"
    escaped = tmp.xmlEscaped()
    XCTAssertEqual(escaped, "&lt;abc&gt;def'ghi\"jkl&amp;mno")
    escaped = tmp.xmlEscaped(isAttribute: true)
    XCTAssertEqual(escaped, "&lt;abc&gt;def&apos;ghi&quot;jkl&amp;mno")
  }
  
  func testTrim() {
    XCTAssertEqual(" abc def ".trim, "abc def")
    XCTAssertEqual("abc def ".trim, "abc def")
    XCTAssertEqual("abc def".trim, "abc def")
    XCTAssertEqual(" abc ".trim, "abc")
    XCTAssertEqual(" abc".trim, "abc")
    XCTAssertEqual("abc".trim, "abc")
    XCTAssertEqual("".trim, "")
    XCTAssertEqual(" a ".trim, "a")
    XCTAssertEqual(" a".trim, "a")
    XCTAssertEqual("a".trim, "a")
    XCTAssertEqual(" a \n b ".trim, "a \n b")
    XCTAssertEqual(" a \n".trim, "a")
  }
  
} // StringTests

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

class EtcTests: XCTestCase {
  
  override static func setUp() {
    print("nodename: \(Utsname.nodename)")
    print("sysname:  \(Utsname.sysname)")
    print("release:  \(Utsname.release)")
    print("version:  \(Utsname.version)")
    print("machine:  \(Utsname.machine)")
    super.setUp()
  }
  
  override static func tearDown() {
    super.tearDown()
  }
  
  func testArray() {
    let a1 = [1,2,3,4,5,6,7,8,9,10]
    XCTAssertEqual(a1.rotated(1), [2,3,4,5,6,7,8,9,10,1])
    XCTAssertEqual(a1.rotated(-1), [10,1,2,3,4,5,6,7,8,9])
    XCTAssertEqual(a1.rotated(2), [3,4,5,6,7,8,9,10,1,2])
    XCTAssertEqual(a1.rotated(-2), [9,10,1,2,3,4,5,6,7,8])
    var a2 = [1]
    XCTAssertEqual(a2 += 2, [1,2])
    XCTAssertEqual(a2 += [3,4], [1,2,3,4])
    XCTAssertEqual(a2.pop(), 1)
    XCTAssertEqual(a2, [2,3,4])
    XCTAssertEqual(a2.push(5), [2,3,4,5])
    try XCTAssertEqual(a2.value(at:1), 3)
    XCTAssertThrowsError(try a2.value(at:4))
    var a3 = ["1", "2", "3"]
    let a4 = try! a3.deepcopy()
    XCTAssertEqual(a3,a4)
    a3 += "4"
    XCTAssertNotEqual(a3,a4)
  }

} // EtcTests

class FileTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    Log.minLogLevel = .Debug
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
    XCTAssert(File.extname("test") == nil)
    XCTAssert(File.prefname("test") == "test")
    XCTAssert(File.basename("test") == "test")
    XCTAssert(File.extname("test.txt") == "txt")
    XCTAssert(File.prefname("test.txt") == "test")
    XCTAssert(File.progname("test.txt") == "test")
    var f = File("\(d2.path)/test")
    File.open(path: f.path, mode: "a") { file in
      file.writeline("a test")
    }
    File.open(path: f.path, mode: "r") { file in
      let str = file.readline()
      XCTAssert(str == "a test")
    }
    let dpath = "\(d1.path)/new"
    let fpath = "\(dpath)/test"
    Dir(dpath).create()
    f.move(to: fpath)
    f = File(fpath)
    XCTAssert(f.exists)
    XCTAssert(f.isFile)
    var fn = "\(d2.path)/test.empty"
    var fn2 = "\(d2.path)/test2.empty"
    XCTAssertFalse(File(fn).exists)
    File.touch(path: fn)
    XCTAssertTrue(File(fn).exists)
    XCTAssertEqual(File(fn).size, 0)
    XCTAssertEqual(File(fn).move(to: fn2), 0)
    XCTAssertFalse(File(fn).exists)
    XCTAssertTrue(File(fn2).exists)
    XCTAssertEqual(File(fn2).size, 0)
    fn = "\(d2.path)/lower"
    fn2 = "\(d2.path)/LOWER"
    File.touch(path: fn)
    XCTAssertTrue(File(fn).exists)
    File(fn).move(to: fn2)
    XCTAssertTrue(File(fn2).exists)
    print(d.list())
    print(d1.list())
    print(d2.list())
  }
  
} // FileTests

class LogTests: XCTestCase, DoesLog {
  
  static override func setUp() {
    super.setUp()
    Log.append(logger: Log.Logger(), Log.FileLogger(nil))
    Log.minLogLevel = .Debug
  }
  
  static override func tearDown() {
    super.tearDown()
    File(Log.FileLogger.tmpLogfile).remove()
  }
  
  func testFileLogger() async {
    let logfn = Log.FileLogger.tmpLogfile
    debug("Logging to: \(logfn)")
    log("log test")
    debug("debug test")
    error("error test")
    /// sleep 1ms to give logging tasks time to log
    try! await Task.sleep(nanoseconds: 1_000_000)
    Log.queue { [self] in
      if let str = File(logfn).mem?.string {
        print("\nlog file content: \n\(str)")
      }
      else { error("Can't read log file: \(logfn)")}
    }
  }
  
}

class ZipTests: XCTestCase, DoesLog {
  
  var testPath: String!
  var testDir: String!
  var nerrors: Int = 0
  var md5: [String:String] = [:]
    
  override func setUp() {
    super.setUp()
    Log.minLogLevel = .Debug
    debug("cwd: \(Dir.current.path), file: \(#file)")
    self.testDir = File.dirname(#file)
    self.testPath = "\(self.testDir!)/test.zip"
    self.md5 = [
      "a.txt": "3740129b68388b4f41404d93ae27a79c",
      "b.txt": "abeecdc0f0a02c2cd90a1555622a84a4"
    ]
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func checkContent(name: String, data: Memory) {
    if let checksum = md5[name] {
      let computed = data.md5
      XCTAssertEqual(checksum, computed)
      if checksum != computed {
        error( "error(\(name): md5 sum doesn't match" )
        self.nerrors += 1
      }
    }
    else {
      error( "error: unexpected file" )
      self.nerrors += 1
    }
  }
    
  func testZipStream() {
    self.nerrors = 0
    let zipStream = ZipStream()
    zipStream.onFile { (name, data) in
      self.debug( "file \(name) with \(data.count) bytes content found" )
      self.checkContent(name: name, data: data)
    }
    File(self.testPath).open { file in
      let data = Memory(length: 10)
      var nbytes: Int
      repeat {
        nbytes = file.read(mem: data)
        if nbytes > 0 { try! zipStream.scanData(mem: data, length: nbytes) }
      } while nbytes > 0
    }
    XCTAssertEqual(self.nerrors, 0)
  }
  
  func testZipFile() {
    let zfile = ZipFile(path: testPath)
    let destTop = "\(testDir!)/unpacked"
    let dest = "\(destTop)/zipfile"
    try! zfile.unpack(toDir: dest)
    for fn in ["a.txt", "b.txt"] {
      if let data = File("\(dest)/\(fn)").mem {
        debug( "file \(fn) with \(data.count) bytes content unpacked")
        checkContent(name: fn, data: data)
      }
      else { XCTFail("Can't read \(fn)") }
    }
    XCTAssertEqual(self.nerrors, 0)
    debug("Files found: \(Dir(dest).contents().joined(separator: " "))")
    Dir(destTop).remove()
  }
  
} // class ZipTests

class RegexprTests: XCTestCase, DoesLog {
  
  func testPreliminary() {
    if try! Regexpr("@a@a").matches("öä") {
      print("*** Regexpr matches UTF-8 in :alpha: ***")
    }
    else {
      print("*** Regexpr does *NOT* match UTF-8 in :alpha: ***")
    }
    if try! Regexpr("ä+").matches("ää") {
      print("*** Regexpr(\"ä+\") matches \"ää\" ***")
    }
    else {
      print("*** Regexpr(\"ä+\") does *NOT* match \"ää\" ***")
    }
    let re = try! Regexpr("@a+")
    XCTAssertEqual(re.pattern, "[[:alpha:]]+")
    XCTAssertEqual(re.match(" 12ab34")![0], "ab")
    re.pattern = "aBcäö"
    re.ignoreCase = true
    XCTAssertEqual(re.match(" AbCÄÖ ")![0], "AbCÄÖ")
    re.pattern = "@d+"
    XCTAssertEqual(re.pattern, "[[:digit:]]+")
    XCTAssertEqual(re.match(" 12ab34")![0], "12")
    re.pattern = "^@d+$"
    XCTAssertNil(re.match("\n34"))
    re.newlineSensitive = true
    XCTAssertTrue(re.newlineSensitive)
    XCTAssertEqual(re.match("\n34")![0], "34")
  }
  
  func testMatch() {
    var re = try! Regexpr("(@d+)@s+(@d+)")
    var matched = re.match("abc123  456def")
    XCTAssertNotNil(matched)
    if let m = matched {
      XCTAssertEqual(m.count, 3)
      XCTAssertEqual(m[0], "123  456")
      XCTAssertEqual(m[1], "123")
      XCTAssertEqual(m[2], "456")
    }
    XCTAssertTrue(re.matches("abc123  456def"))
    matched = re.match("abc123  def")
    XCTAssertNil(matched)
    XCTAssertFalse(re.matches("abc123  def"))
    re = try! Regexpr("c((@d+)@s+(@d+))")
    matched = re.match("abc123  456def")
    XCTAssertNotNil(matched)
    if let m = matched {
      XCTAssertEqual(m.count, 4)
      XCTAssertEqual(m[0], "c123  456")
      XCTAssertEqual(m[1], "123  456")
      XCTAssertEqual(m[2], "123")
      XCTAssertEqual(m[3], "456")
    }
    re = try! Regexpr("([0-9]+)-([0-9]+)")
    matched = re.match("abc 123-456 def")
    XCTAssertNotNil(matched)
    if let m = matched {
      XCTAssertEqual(m.count, 3)
      XCTAssertEqual(m[0], "123-456")
      XCTAssertEqual(m[1], "123")
      XCTAssertEqual(m[2], "456")
    }
  }
  
  func testGmatch() {
    let re = try! Regexpr("(\\d+)-(\\d+)")
    let matched = re.gmatch("abc 12-13  def 14-15")
    XCTAssertNotNil(matched)
    if let m = matched {
      XCTAssertEqual(matched?.count, 2)
      XCTAssertEqual(m[0].count, 3)
      XCTAssertEqual(m[0][0], "12-13")
      XCTAssertEqual(m[0][1], "12")
      XCTAssertEqual(m[0][2], "13")
      XCTAssertEqual(m[1].count, 3)
      XCTAssertEqual(m[1][0], "14-15")
      XCTAssertEqual(m[1][1], "14")
      XCTAssertEqual(m[1][2], "15")
    }
    XCTAssertNil(re.gmatch("123"))
  }
  
  func testSubst() {
    var re = try! Regexpr("@a+")
    var subst = re.subst("huhu gaga", with: ">&<")
    XCTAssertNotNil(subst)
    if let s = subst {
      XCTAssertEqual(s, ">huhu< gaga")
    }
    XCTAssertNil(re.subst("123", with: ""))
    re = try! Regexpr("\\d+")
    subst = re.subst("ab12", with: "(&) - #", num: 15)
    XCTAssertNotNil(subst)
    if let s = subst {
      XCTAssertEqual(s, "ab(12) - 15")
    }
    subst = re.subst("ab12", with: "(&) - #", num: 1, ndig: 3)
    XCTAssertNotNil(subst)
    if let s = subst {
      XCTAssertEqual(s, "ab(12) - 001")
    }
    re = try! Regexpr("@s+(@d+)")
    subst = re.subst("abc 14def", with: "(&1)")
    XCTAssertNotNil(subst)
    if let s = subst {
      XCTAssertEqual(s, "abc(14)def")
    }
    subst = re.subst("abc 14def", with: "\\n(&1)\\n")
    XCTAssertNotNil(subst)
    if let s = subst {
      XCTAssertEqual(s, "abc\n(14)\ndef")
    }
    subst = re.subst("abc 14def", with: "\n(\\1)\n")
    XCTAssertNotNil(subst)
    if let s = subst {
      XCTAssertEqual(s, "abc\n(14)\ndef")
    }
  }
  
  func testGsubst() {
    var re = try! Regexpr("@a+")
    var subst = re.gsubst("huhu gaga", with: ">&<")
    XCTAssertNotNil(subst)
    if let s = subst {
      XCTAssertEqual(s, ">huhu< >gaga<")
    }
    XCTAssertNil(re.gsubst("123", with: ""))
    re = try! Regexpr("\\d+")
    subst = re.gsubst("ab12 34", with: "(&) - #", num: 15)
    XCTAssertNotNil(subst)
    if let s = subst {
      XCTAssertEqual(s, "ab(12) - 15 (34) - 15")
    }
    re = try! Regexpr("@s+(@d+)")
    subst = re.gsubst("abc 14def 15ghi", with: "(&1)")
    XCTAssertNotNil(subst)
    if let s = subst {
      XCTAssertEqual(s, "abc(14)def(15)ghi")
    }
  }
  
  func testSedSubst() {
    XCTAssertTrue(Regexpr.isValidSubst(spec: "/@d+/<&>/"))
    XCTAssertFalse(Regexpr.isValidSubst(spec: "/@d+/<&>"))
    var ret = Regexpr.subst("abc123def456ghi", by: "/@d+/<&>/")
    XCTAssertNotNil(ret)
    if let ret = ret {
      XCTAssertEqual(ret, "abc<123>def456ghi")
    }
    ret = Regexpr.subst("abc123def456ghi", by: "/@d+/<&>/g")
    XCTAssertNotNil(ret)
    if let ret = ret {
      XCTAssertEqual(ret, "abc<123>def<456>ghi")
    }
    ret = Regexpr.subst("abc123def456ghi", by: "/@d+/\n&/g")
    XCTAssertNotNil(ret)
    if let ret = ret {
      XCTAssertEqual(ret, "abc\n123def\n456ghi")
    }
    ret = Regexpr.subst("abc123def456ghi", by: "/@d+/\\n&/g")
    XCTAssertNotNil(ret)
    if let ret = ret {
      XCTAssertEqual(ret, "abc\n123def\n456ghi")
    }
    ret = Regexpr.subst("abc123def456ghi", by: ",@d+,\\n&,g")
    XCTAssertNotNil(ret)
    if let ret = ret {
      XCTAssertEqual(ret, "abc\n123def\n456ghi")
    }
    ret = Regexpr.subst("abc123def456ghi", by: ",@d+,\\n&\\,,g")
    XCTAssertNotNil(ret)
    if let ret = ret {
      XCTAssertEqual(ret, "abc\n123,def\n456,ghi")
    }
  }
  
  func testSubstexpr() throws {
    XCTAssertThrowsError(try Substexpr("gaga"))
    var se = try Substexpr("/@d+/<&> #/")
    se.count = 50
    XCTAssertEqual(se.subst("123"), "<123> 01")
    XCTAssertEqual(se.subst("456"), "<456> 02")
    XCTAssertEqual(se.subst("789"), "<789> 03")
    XCTAssertEqual(se.subst("abc"), nil)
    XCTAssertEqual(se.subst("012"), "<012> 04")
    se = try Substexpr("/@d+/<&> #/g")
    se.count = 5
    XCTAssertEqual(se.subst("123 456"), "<123> 1 <456> 1")
    se = try Substexpr("/(@d+) (@d+)/<&1> <&2> #/g")
    se.count = 5
    XCTAssertEqual(se.subst("123 456"), "<123> <456> 1")
    se = try Substexpr(#"/^(.*) (\(Num.*\))$/\2 \1/"#)
    XCTAssertEqual(se.subst("abc (Num 255)"), "(Num 255) abc")
    XCTAssertEqual(se.subst("def (Num 256)"), "(Num 256) def")
    se = try Substexpr("/@d+/<&> (###)/")
    se.index = 11
    XCTAssertEqual(se.subst("123 456"), "<123> (011) 456")
  }
  
  func testStringExtensions() {
    XCTAssertTrue("ab12cd" =~ "@d+")
    XCTAssertFalse("abcd" =~ "@d+")
    let m = "ab123cd".match("@d+")
    XCTAssertNotNil(m)
    if let m = m {
      XCTAssertEqual(m.count, 1)
      XCTAssertEqual(m[0], "123")
    }
    let gm = "abä123cdö".gmatch("@a+")
    XCTAssertNotNil(gm)
    if let gm = gm {
      XCTAssertEqual(gm.count, 2)
      XCTAssertEqual(gm[0][0], "abä")
      XCTAssertEqual(gm[1][0], "cdö")
    }
    var s = "abä123cdö"
    XCTAssertEqual(s.subst("/@a+/<&>/g"), "<abä>123<cdö>")
    s = "abc"
    XCTAssertEqual(s.subst("/.*/<&> #/g", num:1, ndig:3), "<abc> 001")
  }

} // class RegexprTests

class VersionTests: XCTestCase {
  
  func testVersion() {
    let a = Version("1.2")
    let b = Version("2.0")
    XCTAssertTrue(a < b)
    XCTAssertFalse(a == b)
    XCTAssertFalse(a.isCompatible(ver: b))
    XCTAssertFalse(a > b)
    XCTAssertEqual(a[2], 0)
    a[3] = 4
    XCTAssertEqual(a.toString(), "1.2.0.4")
    a[2] = 16
    XCTAssertEqual(a.major, 1)
    XCTAssertEqual(a.minor, 2)
    XCTAssertEqual(a.patch, 16)
    a[0] = 2
    XCTAssertTrue(a.isCompatible(ver: b))
  }
  
}

class UsTimeTests: XCTestCase {
  
  static override func setUp() {
    super.setUp()
    let now = UsTime.now
    print("Current local time: \(now) \(UsTime.tz)", terminator: " ")
    print("\(now.isDst ? "daylight saving time" : "standard time")")
    print("  offsets: \(UsTime.tzOffset)s standard, \(UsTime.tzDstOffset)s daylight")
  }
  
  func testConversion() {
    var t: UsTime?
    t = UsTime.parse(iso: "2019-10-09 13:44:56")
    XCTAssertNotNil(t)
    if let t = t { XCTAssertEqual(t.toString(), "2019-10-09 13:44:56") }
    t = UsTime.parse(iso: "2019-10-09 13:45:56.123")
    XCTAssertNotNil(t)
    if let t = t { 
      XCTAssertEqual(t.toString(), "2019-10-09 13:45:56") 
      XCTAssertEqual(t.usecond, 123000)
    }
    t = UsTime.parse(iso: "2019-10-09")
    XCTAssertNotNil(t)
    if let t = t { XCTAssertEqual(t.toString(), "2019-10-09 12:00:00") }
    t = UsTime.parse(iso: "2019-13-09")
    XCTAssertNil(t)
    t = UsTime.parse(iso: "2019-10-09")
    if let t = t {
      XCTAssertEqual(t.sec, 1570615200)
      let t2 = UsTime("1570615200")
      XCTAssertEqual(t.sec, t2.sec)
    }
  }
  
  func testOperators() {
    let t1 = UsTime.parse(iso: "2022-01-10, 14:00:00")
    XCTAssertNotNil(t1)
    if let t = t1 {
      t += 3600
      XCTAssertEqual(t.toString(), "2022-01-10 15:00:00") 
    }
    let t2 = UsTime.parse(iso: "2022-01-10, 14:00:00")
    XCTAssert(t1! != t2!)
    XCTAssert(t1! > t2!)
    XCTAssert(t2! < t1!)
    t1! -= 3600
    XCTAssert(t1! == t2!)
    t1!.usec = 100
    XCTAssert(t1! > t2!)
    t1! -= 1
    XCTAssert(t1! < t2!)
  }
  
}

//class ConsoleTests: XCTestCase {
//  
//  func testIO() async {
//    let con = Console()
//    con.puts("login: ")
//    if let s = await con.gets() { con.putsln(s) }
//    con.puts("password: ")
//    if let s = await con.negets() { con.putsln(s) }
//  }
//  
//}
