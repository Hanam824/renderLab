import Foundation
import QuartzCore

/// Opt-in diagnostic logging. Off by default; turn it on with `--log` (info and up)
/// or `--log=debug` (everything, including FPS twice a second).
///
///     Log.info("drawable size 2560x1600", category: .metal)
///
/// Messages are `@autoclosure`s: while logging is off the string is never built,
/// so a disabled log call costs one comparison. Lines go to stderr:
///
///     [    1.234s] INFO  metal    drawable size 2560x1600
final class Log {
    enum Level: Int, Comparable, CaseIterable, CustomStringConvertible {
        case debug, info, warning, error

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }

        var description: String {
            switch self {
            case .debug: return "debug"
            case .info: return "info"
            case .warning: return "warning"
            case .error: return "error"
            }
        }
    }

    enum Category: String {
        case app, renderer, opengl, metal
    }

    enum ParseError: Error, Equatable, CustomStringConvertible {
        case unknownLevel(String)

        var description: String {
            switch self {
            case .unknownLevel(let value):
                return "unknown log level '\(value)' (use: \(Level.allCases.map(\.description).joined(separator: ", ")))"
            }
        }
    }

    /// Lowest level that gets written; nil means logging is off (the default).
    static var minimumLevel: Level?
    /// Where finished lines go. Tests replace this to capture output.
    static var write: (String) -> Void = { line in
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }

    /// Timestamps count from the first log line.
    private static let startTime = CACurrentMediaTime()

    private init() {}

    /// Reads `--log` / `--log=<level>` from the command line. Returns nil when absent (logging off).
    static func level(from arguments: [String]) throws -> Level? {
        for argument in arguments.dropFirst() {
            if argument == "--log" { return .info }
            if argument.hasPrefix("--log=") {
                let value = String(argument.dropFirst("--log=".count)).lowercased()
                guard let level = Level.allCases.first(where: { $0.description == value }) else {
                    throw ParseError.unknownLevel(value)
                }
                return level
            }
        }
        return nil
    }

    static func isEnabled(_ level: Level) -> Bool {
        guard let minimumLevel else { return false }
        return level >= minimumLevel
    }

    static func debug(_ message: @autoclosure () -> String, category: Category = .app) {
        log(.debug, category, message)
    }

    static func info(_ message: @autoclosure () -> String, category: Category = .app) {
        log(.info, category, message)
    }

    static func warning(_ message: @autoclosure () -> String, category: Category = .app) {
        log(.warning, category, message)
    }

    static func error(_ message: @autoclosure () -> String, category: Category = .app) {
        log(.error, category, message)
    }

    private static func log(_ level: Level, _ category: Category, _ message: () -> String) {
        guard isEnabled(level) else { return }
        let start = startTime // a lazy static: read it first so the first line isn't negative
        let elapsed = String(format: "%9.3fs", CACurrentMediaTime() - start)
        let levelName = level.description.uppercased().padding(toLength: 5, withPad: " ", startingAt: 0)
        let categoryName = category.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)
        write("[\(elapsed)] \(levelName) \(categoryName) \(message())")
    }
}
