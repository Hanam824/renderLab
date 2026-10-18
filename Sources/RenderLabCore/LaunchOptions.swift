/// RenderLab's command-line options, parsed up front so a typo fails fast instead of being ignored.
///
///     RenderLab [--backend opengl|metal] [--frames N] [--log[=LEVEL]] [--help]
///
/// Every option also accepts the `--name=value` form.
struct LaunchOptions: Equatable {
    var backend: Backend = .opengl
    /// Smoke-test mode: render this many frames, print a status line and quit.
    var exitAfterFrames: Int?
    /// nil means logging is off (the default).
    var logLevel: Log.Level?
    var showHelp = false

    enum ParseError: Error, Equatable, CustomStringConvertible {
        case missingFramesValue
        case invalidFrames(String)
        case unknownOption(String)

        var description: String {
            switch self {
            case .missingFramesValue: return "--frames needs a value: a whole number of frames, at least 1"
            case .invalidFrames(let value): return "--frames needs a whole number of frames, at least 1 (got '\(value)')"
            case .unknownOption(let option): return "unknown option '\(option)' (see --help)"
            }
        }
    }

    static let usage = """
        usage: RenderLab [--backend \(Backend.available.map(\.rawValue).joined(separator: "|"))] [--frames N] [--log[=LEVEL]]

          --backend  graphics API to start with (default: opengl)
          --frames   render N frames, print a status line and quit (smoke test)
          --log      write diagnostic logs to stderr (default: off). LEVEL: \(Log.Level.allCases.map(\.description).joined(separator: "|")), default info
        """

    init(arguments: [String]) throws {
        showHelp = arguments.contains("--help") || arguments.contains("-h")
        backend = try Backend.parse(arguments: arguments)
        logLevel = try Log.level(from: arguments)

        // Second pass: --frames, plus rejecting options nobody handles.
        var iterator = arguments.dropFirst().makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--backend":
                _ = iterator.next() // its value was read by Backend.parse
            case "--frames":
                guard let value = iterator.next() else { throw ParseError.missingFramesValue }
                exitAfterFrames = try Self.frameCount(value)
            case _ where argument.hasPrefix("--frames="):
                exitAfterFrames = try Self.frameCount(String(argument.dropFirst("--frames=".count)))
            case "--log", "--help", "-h":
                break
            case _ where argument.hasPrefix("--backend=") || argument.hasPrefix("--log="):
                break
            case _ where argument.hasPrefix("--"):
                throw ParseError.unknownOption(argument)
            default:
                break // single-dash arguments AppKit or Xcode may add, e.g. -NSDocumentRevisionsDebugMode YES
            }
        }
    }

    private static func frameCount(_ value: String) throws -> Int {
        guard let frames = Int(value), frames > 0 else { throw ParseError.invalidFrames(value) }
        return frames
    }
}
