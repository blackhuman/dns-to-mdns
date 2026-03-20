// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "dns-to-mdns",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "dns-to-mdns",
            targets: ["dns-to-mdns"]
        )
    ],
    dependencies: [
        .package(path: "dnskit"),
        .package(path: "swift-async-dns-resolver"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "dns-to-mdns",
            dependencies: [
                .product(name: "DNSKit", package: "dnskit"),
                .product(name: "AsyncDNSResolver", package: "swift-async-dns-resolver"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/dns-to-mdns"
        ),
        .testTarget(
            name: "dns-to-mdnsTests",
            dependencies: ["dns-to-mdns"],
            path: "Tests"
        )
    ]
)
