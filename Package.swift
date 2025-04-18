// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "Queried",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v17), .visionOS(.v1)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Queried",
            targets: ["Queried"]
        ),
        .executable(
            name: "QueriedClient",
            targets: ["QueriedClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", "600.0.0"..<"699.99.99"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "QueriedMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(name: "Queried", dependencies: ["QueriedMacros"]),

        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(name: "QueriedClient", dependencies: ["Queried"]),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "QueriedTests",
            dependencies: [
                "QueriedMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ]
        ),
    ]
)
