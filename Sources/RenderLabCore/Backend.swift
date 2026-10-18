/// The graphics API a `Renderer` is built on.
public enum Backend: String, CaseIterable, Sendable {
    case opengl
    case metal

    /// Backends compiled into this build. Both always are: every Mac running macOS 13 has OpenGL and Metal.
    public static var available: [Backend] { allCases }

    public var displayName: String {
        switch self {
        case .opengl: return "OpenGL"
        case .metal: return "Metal"
        }
    }

    public enum ParseError: Error, Equatable, CustomStringConvertible {
        case missingValue
        case unknown(String)

        public var description: String {
            switch self {
            case .missingValue:
                return "--backend needs a value: \(Backend.allCases.map(\.rawValue).joined(separator: "|"))"
            case .unknown(let value):
                return "unknown backend '\(value)', expected \(Backend.allCases.map(\.rawValue).joined(separator: "|"))"
            }
        }
    }

    /// Reads `--backend <name>` or `--backend=<name>` from command-line arguments.
    /// Defaults to OpenGL when the flag is absent.
    public static func parse(arguments: [String]) throws -> Backend {
        var value: String?
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            if argument == "--backend" {
                guard let next = iterator.next() else { throw ParseError.missingValue }
                value = next
            } else if argument.hasPrefix("--backend=") {
                value = String(argument.dropFirst("--backend=".count))
            }
        }

        guard let value else { return .opengl }
        guard let backend = Backend(rawValue: value.lowercased()) else { throw ParseError.unknown(value) }
        return backend
    }
}
