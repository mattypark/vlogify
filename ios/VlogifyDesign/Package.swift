// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VlogifyDesign",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "VlogifyDesign", targets: ["VlogifyDesign"]),
        .library(name: "VlogifyEngine", targets: ["VlogifyEngine"]),
        .library(name: "VlogifyContract", targets: ["VlogifyContract"]),
    ],
    targets: [
        // Tokens and the art slots. Depends on the engine so a room type can be drawn
        // without the app translating between the two.
        .target(name: "VlogifyDesign", dependencies: ["VlogifyEngine"]),
        // Pure logic, no UIKit and no SwiftUI, so it compiles and tests on macOS.
        // That is the point: the 4 AM day boundary, the deterministic ping minute, and
        // the split-screen layout math can be verified in a second from the command
        // line rather than only in a simulator -- and those three are exactly the
        // things that would be embarrassing to get wrong.
        .target(name: "VlogifyEngine"),
        // The frozen boundary between this app and whatever serves it: the shapes that
        // cross the wire, the protocols every backend must satisfy, and a mock that
        // satisfies them on-device so the whole app runs with no server at all. The
        // backend session implements these; it does not change them.
        .target(name: "VlogifyContract", dependencies: ["VlogifyEngine"]),
        // Dev-only. Renders the 1024 app icon from the same shapes the app draws, so
        // the icon cannot drift from the product: `swift run IconSheet out.png`.
        .executableTarget(name: "IconSheet", dependencies: ["VlogifyDesign"], path: "Tools/IconSheet"),
        .testTarget(name: "VlogifyDesignTests", dependencies: ["VlogifyDesign"]),
        .testTarget(name: "VlogifyEngineTests", dependencies: ["VlogifyEngine"]),
        .testTarget(name: "VlogifyContractTests", dependencies: ["VlogifyContract"]),
    ]
)
