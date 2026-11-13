// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SchemaCanary",
    products: [
        .executable(name: "schema-canary", targets: ["SchemaCanaryCLI"])
    ],
    targets: [
        .target(name: "SchemaCanaryCore"),
        .executableTarget(name: "SchemaCanaryCLI", dependencies: ["SchemaCanaryCore"]),
        .testTarget(name: "SchemaCanaryCoreTests", dependencies: ["SchemaCanaryCore"])
    ]
)
