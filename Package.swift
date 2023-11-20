// swift-tools-version:5.5

import PackageDescription

#if os(Linux)
  let pkgConfigXml: String? = "libxml-2.0"
  let pkgConfigZlib: String? = "zlib"
#else
  let pkgConfigXml: String? = nil
  let pkgConfigZlib: String? = nil
#endif

let providerXml: [SystemPackageProvider] = [ .apt(["libxml2-dev"]) ]
let providerZlib: [SystemPackageProvider] = [ .apt(["zlib-dev"]) ]

var linkerSettings: [LinkerSetting] = [.linkedLibrary("z")]

var targets: [Target] = [
  .systemLibrary(
    name: "Clibcpp", 
    path: "src/Clibcpp"
  ),
  .systemLibrary(
    name: "Clibzip", 
    path: "src/Clibzip",
    pkgConfig: pkgConfigZlib,
    providers: providerZlib
  ),
  .systemLibrary(
    name: "Clibxml2", 
    path: "src/Clibxml2",
    pkgConfig: pkgConfigXml,
    providers: providerXml
  ),
  .target(
    name: "NorthLowLevel",
    dependencies: ["Clibcpp", "Clibzip"],
    path: "src/LowLevel",
    exclude: ["doc"]
  ),
  .target(
    name: "NorthBase",
    dependencies: ["NorthLowLevel"],
    path: "src/Base"
  ),
  .target(
    name: "NorthFoundation",
    dependencies: ["NorthBase"],
    path: "src/Foundation"
  ),
  .target(
    name: "NorthUIKit",
    dependencies: ["NorthFoundation"],
    path: "src/UIKit"
  ),
  .target(
    name: "NorthLib",
    dependencies: [
      .target(name: "NorthBase"),
      .target(name: "NorthFoundation", condition:
          .when(platforms: [.iOS,.macOS,.macCatalyst,.tvOS,.watchOS])),
      .target(name: "NorthUIKit", condition:
          .when(platforms: [.iOS,.macCatalyst,.tvOS,.watchOS])),
    ],
    path: "src/NorthLib",
    linkerSettings: linkerSettings
  ),
  .testTarget(
    name: "TestLowlevel",
    dependencies: ["NorthLowLevel"],
    path: "test/LowLevel",
    linkerSettings: linkerSettings
  ),
  .testTarget(
    name: "TestBase",
    dependencies: ["NorthBase"],
    path: "test/Base",
    exclude: ["test.zip"],
    linkerSettings: linkerSettings
  ),
  .testTarget(
    name: "TestFoundation",
    dependencies: [
      .target(name: "NorthFoundation", condition:
          .when(platforms: [.iOS,.macOS,.macCatalyst,.tvOS,.watchOS])),
    ],
    path: "test/Foundation",
    linkerSettings: linkerSettings
  ),
  .testTarget(
    name: "TestUIKit",
    dependencies: [
      .target(name: "NorthUIKit", condition:
          .when(platforms: [.iOS,.macCatalyst,.tvOS,.watchOS])),
    ],
    path: "test/UIKit",
    linkerSettings: linkerSettings
  ),
]

var products: [Product] = [
  .library(
    name: "NorthLib",
    type: .static,
    targets: ["NorthLib"]
  ),
]

var dependencies: [Package.Dependency] = [
]

let package = Package(
  name: "NorthLib",
  defaultLocalization: "en",
  platforms: [.iOS(.v13), .macOS(.v11), .tvOS(.v13), .watchOS(.v6)],
  products: products,
  dependencies: dependencies,
  targets: targets,
  cxxLanguageStandard: .cxx20
)
