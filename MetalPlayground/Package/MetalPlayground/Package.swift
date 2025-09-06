// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MetalPlayground",
  platforms: [.macOS(.v26), .iOS(.v26),],
  products: [
    .library(
      name: "MetalPlayground",
      targets: ["PlaygroundViews", "Shared"]
    )
  ],
  targets: [
    .target(
      name: "PlaygroundViews",
      dependencies: [
        "HEVCPlayer",
        "HEVCPlayerMetal4",
        "HEVCPlayerMetal4Performance",
        "Shared"
      ]
    ),
    .target(
      name: "HEVCPlayer",
      dependencies: ["Shared"],
      resources: [.process("Shader")]
    ),
    .target(
      name: "HEVCPlayerMetal4",
      dependencies: ["Shared"],
      resources: [.process("Shader")]
    ),
    .target(
      name: "HEVCPlayerMetal4Performance",
      dependencies: ["Shared"],
      resources: [.process("Shader")]
    ),
    .target(
      name: "Shared",
      resources: [.process("Shader")]
    )
  ]
)
