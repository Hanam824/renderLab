import Foundation

/// Loads shader files bundled from `Sources/RenderLabCore/Shaders`.
enum ShaderLibrary {
    enum Stage: String, CaseIterable {
        case vertex = "vert"
        case fragment = "frag"
    }

    enum LoadError: Error, CustomStringConvertible {
        case notFound(String)

        var description: String {
            switch self {
            case .notFound(let path): return "shader not found in bundle: \(path)"
            }
        }
    }

    private static func text(_ name: String, extension ext: String, subdirectory: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory) else {
            throw LoadError.notFound("\(subdirectory)/\(name).\(ext)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// GLSL source text, e.g. `source("triangle", .vertex)` reads `Shaders/opengl/triangle.vert`.
    static func source(_ name: String, _ stage: Stage) throws -> String {
        try text(name, extension: stage.rawValue, subdirectory: "Shaders/opengl")
    }

    /// Metal Shading Language source, e.g. `metalSource("triangle")` reads `Shaders/metal/triangle.metal`.
    /// One file holds both the vertex and the fragment function.
    static func metalSource(_ name: String) throws -> String {
        try text(name, extension: "metal", subdirectory: "Shaders/metal")
    }
}
