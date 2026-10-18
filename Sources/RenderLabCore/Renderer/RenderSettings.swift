/// Render state shared by every backend and edited from the ImGui "Settings" panel.
///
/// OpenGL applies these as global state each frame (glEnable, glPolygonMode, ...).
/// Metal keeps the depth test in an `MTLDepthStencilState` object (built once per variant)
/// and sets cull and fill mode on the command encoder each frame. Comparing the two is part of the lesson.
struct RenderSettings: Equatable {
    enum CullMode: Int32, CaseIterable {
        case back = 0
        case front = 1

        var label: String { self == .back ? "Back" : "Front" }
    }

    var clearColor: SIMD4<Float> = [0.10, 0.11, 0.14, 1.0]
    var depthTest = true
    var wireframe = false
    var cullFace = false
    var cullMode: CullMode = .back
    var vsync = true
}
