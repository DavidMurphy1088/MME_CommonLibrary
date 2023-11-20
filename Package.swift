// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonLibrary",
    platforms: [
                .iOS(.v15) // Set minimum iOS version to 13.0
            ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CommonLibrary",
            targets: ["CommonLibrary"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/Kitura/Swift-JWT.git", from: "3.6.1"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.8.1")),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "CommonLibrary",
            dependencies: [
                .product(name: "SwiftJWT", package: "Swift-JWT"),
                                .product(name: "Alamofire", package: "Alamofire"),
                                .product(name: "SwiftSoup", package: "SwiftSoup")
            ]),
        .testTarget(
            name: "CommonLibraryTests",
            dependencies: ["CommonLibrary"]),
    ]
)
