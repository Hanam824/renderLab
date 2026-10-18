// swift-tools-version: 6.0
import PackageDescription

// Settings shared by every Swift target that imports RenderLabCore.
let swiftSettings: [SwiftSetting] = [
    .interoperabilityMode(.Cxx),
    // OpenGL headers check this macro to suppress "deprecated in macOS 10.14" warnings.
    .unsafeFlags(["-Xcc", "-DGL_SILENCE_DEPRECATION"]),
]

let package = Package(
    name: "RenderLab",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "RenderLab", targets: ["RenderLab"]),
    ],
    targets: [
        // Dear ImGui core + macOS platform backend + OpenGL3 renderer backend.
        // Sources live in the ThirdParty/imgui submodule; the wrapper files here #include them.
        .target(
            name: "CImGui",
            cxxSettings: [
                .define("GL_SILENCE_DEPRECATION"),
                .headerSearchPath("../../ThirdParty/imgui"),
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("OpenGL"),
                .linkedFramework("GameController"),
            ]
        ),
        // Dear ImGui Metal renderer backend. Its own target because imgui_impl_metal.mm needs ARC,
        // and SwiftPM compiles Objective-C++ without ARC unless asked.
        .target(
            name: "ImGuiMetal",
            dependencies: ["CImGui"],
            cxxSettings: [
                .headerSearchPath("../../ThirdParty/imgui"),
                .unsafeFlags(["-fobjc-arc"]),
            ],
            linkerSettings: [
                .linkedFramework("Metal"),
                .linkedFramework("QuartzCore"),
            ]
        ),
        .target(
            name: "RenderLabCore",
            dependencies: ["CImGui", "ImGuiMetal"],
            resources: [.copy("Shaders")],
            swiftSettings: swiftSettings,
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("OpenGL"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("Metal"),
            ]
        ),
        .executableTarget(
            name: "RenderLab",
            dependencies: ["RenderLabCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "RenderLabCoreTests",
            dependencies: ["RenderLabCore"],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx17
)
