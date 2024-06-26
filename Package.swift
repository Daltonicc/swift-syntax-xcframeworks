// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SwiftSyntaxWrapper",
    products: [
        .library(name: "SwiftSyntaxWrapper", targets: ["SwiftSyntaxWrapper"]),
    ],
    targets: [
        .binaryTarget(
            name: "SwiftSyntaxWrapper",
            url: "https://github.com/Daltonicc/swift-syntax-xcframeworks/releases/download/510.0.1/SwiftSyntaxWrapper.xcframework.zip",
            checksum: "997a15a81b02cb6696eb19ea6540efb93a4f8c05b80dd9b69732e055fd4712d3"
        ),
    ]
)
