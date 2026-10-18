import Testing
@testable import RenderLabCore

// Serialized: the tests change Log's global state.
@Suite(.serialized) @MainActor struct LogTests {
    @Test func offByDefault() throws {
        #expect(try Log.level(from: ["RenderLab"]) == nil)
        #expect(try Log.level(from: ["RenderLab", "--backend", "metal"]) == nil)
    }

    @Test func parsesFlagAndLevel() throws {
        #expect(try Log.level(from: ["RenderLab", "--log"]) == .info)
        #expect(try Log.level(from: ["RenderLab", "--log=debug"]) == .debug)
        #expect(try Log.level(from: ["RenderLab", "--log=ERROR"]) == .error)
    }

    @Test func rejectsUnknownLevel() {
        #expect(throws: Log.ParseError.unknownLevel("loud")) {
            try Log.level(from: ["RenderLab", "--log=loud"])
        }
    }

    @Test func writesOnlyEnabledLevels() {
        let savedLevel = Log.minimumLevel
        let savedWrite = Log.write
        defer { Log.minimumLevel = savedLevel; Log.write = savedWrite }

        var lines: [String] = []
        Log.write = { lines.append($0) }

        Log.minimumLevel = nil
        Log.error("hidden")
        #expect(lines.isEmpty)

        Log.minimumLevel = .info
        Log.debug("too detailed", category: .metal)
        Log.info("drawable ready", category: .metal)
        #expect(lines.count == 1)
        #expect(lines.first?.contains("INFO  metal    drawable ready") == true)
    }

    @Test func skipsBuildingMessageWhenOff() {
        let savedLevel = Log.minimumLevel
        defer { Log.minimumLevel = savedLevel }
        Log.minimumLevel = nil

        var built = false
        Log.info({ built = true; return "expensive" }())
        #expect(!built)
    }
}
