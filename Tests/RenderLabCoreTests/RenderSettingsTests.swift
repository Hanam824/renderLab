import Testing
@testable import RenderLabCore

@Suite struct RenderSettingsTests {
    @Test func defaults() {
        let settings = RenderSettings()
        #expect(settings.depthTest)
        #expect(!settings.wireframe)
        #expect(!settings.cullFace)
        #expect(settings.cullMode == .back)
        #expect(settings.vsync)
    }
}
