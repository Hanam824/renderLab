import Testing
@testable import RenderLabCore

@Suite struct LaunchOptionsTests {
    @Test func defaults() throws {
        let options = try LaunchOptions(arguments: ["RenderLab"])
        #expect(options.backend == .opengl)
        #expect(options.exitAfterFrames == nil)
        #expect(options.logLevel == nil)
        #expect(!options.showHelp)
    }

    @Test(arguments: [["RenderLab", "--frames", "120"], ["RenderLab", "--frames=120"]])
    func parsesFramesInBothForms(arguments: [String]) throws {
        #expect(try LaunchOptions(arguments: arguments).exitAfterFrames == 120)
    }

    @Test func parsesEverythingTogether() throws {
        let options = try LaunchOptions(arguments: ["RenderLab", "--backend=metal", "--frames", "30", "--log=debug"])
        #expect(options.backend == .metal)
        #expect(options.exitAfterFrames == 30)
        #expect(options.logLevel == .debug)
    }

    @Test(arguments: ["abc", "0", "-5", ""])
    func rejectsInvalidFrames(value: String) {
        #expect(throws: LaunchOptions.ParseError.invalidFrames(value)) {
            try LaunchOptions(arguments: ["RenderLab", "--frames=\(value)"])
        }
    }

    @Test func rejectsMissingFramesValue() {
        #expect(throws: LaunchOptions.ParseError.missingFramesValue) {
            try LaunchOptions(arguments: ["RenderLab", "--frames"])
        }
    }

    @Test func rejectsUnknownOption() {
        #expect(throws: LaunchOptions.ParseError.unknownOption("--frame")) {
            try LaunchOptions(arguments: ["RenderLab", "--frame", "120"])
        }
    }

    @Test func ignoresSingleDashArgumentsFromAppKit() throws {
        let options = try LaunchOptions(arguments: ["RenderLab", "-NSDocumentRevisionsDebugMode", "YES"])
        #expect(options.exitAfterFrames == nil)
    }
}
