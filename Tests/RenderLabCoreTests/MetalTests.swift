import Metal
import Testing
@testable import RenderLabCore

/// Needs a Metal device but no window: pipeline objects can be built headless.
@Suite(.tags(.gpu), .enabled(if: MTLCreateSystemDefaultDevice() != nil, "no Metal device available"))
struct MetalTests {
    let device = MTLCreateSystemDefaultDevice()!

    @Test func deviceHasAName() {
        #expect(!device.name.isEmpty)
    }

    @Test func triangleShaderCompilesWithBothFunctions() throws {
        let library = try device.makeLibrary(source: ShaderLibrary.metalSource("triangle"), options: nil)
        #expect(library.functionNames.contains("triangle_vertex"))
        #expect(library.functionNames.contains("triangle_fragment"))
    }

    @Test func invalidShaderReportsCompilerLog() {
        #expect(throws: (any Error).self) {
            try device.makeLibrary(source: "vertex float4 broken( {", options: nil)
        }
    }

    @Test @MainActor func pipelineStateBuildsForTheScene() throws {
        let pipeline = try MetalRenderer.makePipelineState(device: device)
        #expect(pipeline.label == "triangle")
    }
}
