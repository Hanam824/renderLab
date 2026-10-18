import Testing
@testable import RenderLabCore

@Suite struct ShaderResourceTests {
    @Test(arguments: ShaderLibrary.Stage.allCases)
    func openGLShadersTargetGLSL410(stage: ShaderLibrary.Stage) throws {
        let source = try ShaderLibrary.source("triangle", stage)
        #expect(source.hasPrefix("#version 410 core"))
    }

    @Test func metalShaderHasBothStages() throws {
        let source = try ShaderLibrary.metalSource("triangle")
        #expect(source.contains("vertex VertexOut triangle_vertex("))
        #expect(source.contains("fragment float4 triangle_fragment("))
    }

    @Test func missingShaderThrows() {
        #expect(throws: ShaderLibrary.LoadError.self) {
            try ShaderLibrary.source("does-not-exist", .vertex)
        }
    }

    @Test func sceneHasTwoTriangles() {
        #expect(Scene.vertexCount == 6)
        #expect(Scene.vertices.count % Scene.floatsPerVertex == 0)
    }
}
