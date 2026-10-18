import Testing
@testable import RenderLabCore

@Suite struct BackendTests {
    @Test func defaultsToOpenGL() throws {
        #expect(try Backend.parse(arguments: ["RenderLab"]) == .opengl)
    }

    @Test(arguments: [["RenderLab", "--backend", "opengl"], ["RenderLab", "--backend=OpenGL"]])
    func parsesOpenGL(arguments: [String]) throws {
        #expect(try Backend.parse(arguments: arguments) == .opengl)
    }

    @Test func parsesMetal() throws {
        #expect(try Backend.parse(arguments: ["RenderLab", "--backend", "metal"]) == .metal)
        #expect(try Backend.parse(arguments: ["RenderLab", "--backend=Metal"]) == .metal)
    }

    @Test func rejectsUnknownBackend() {
        #expect(throws: Backend.ParseError.unknown("vulkan")) {
            try Backend.parse(arguments: ["RenderLab", "--backend", "vulkan"])
        }
    }

    @Test func rejectsMissingValue() {
        #expect(throws: Backend.ParseError.missingValue) {
            try Backend.parse(arguments: ["RenderLab", "--backend"])
        }
    }

    @Test func bothEnginesAreAlwaysAvailable() {
        #expect(Backend.available == [.opengl, .metal])
    }
}
