import CImGui

/// ImGui windows shared by every backend. Widgets are called straight from Swift
/// through C++ interop: `ImGui.Checkbox(label, &bool)` passes a pointer to the Swift value.
@MainActor
enum Panels {
    /// Gap between the panels and the window edges, and between the two panels.
    private static let margin: Float = 12
    /// Shared width of both panels: the wider of their natural widths, measured last frame.
    private static var panelWidth: Float = 0

    /// Both panels are stacked in the top-right corner: Info first, Settings under it, same width.
    static func draw(for renderer: Renderer) {
        let info = infoWindow(renderer)
        let settingsFitWidth = settingsWindow(renderer, top: info.bottom + margin)
        panelWidth = max(info.fitWidth, settingsFitWidth)
    }

    /// Pins the next window's width to `panelWidth` (min == max); the height still auto-fits.
    private static func useSharedWidth() {
        guard panelWidth > 0 else { return }
        ImGui.SetNextWindowSizeConstraints(ImVec2(panelWidth, 0), ImVec2(panelWidth, .greatestFiniteMagnitude), nil, nil)
    }

    /// The x coordinate of the main viewport's right edge, minus the margin.
    private static var rightEdge: Float {
        let viewport = ImGui.GetMainViewport().pointee
        return viewport.WorkPos.x + viewport.WorkSize.x - margin
    }

    /// Returns the width this panel's content needs.
    private static func settingsWindow(_ renderer: Renderer, top: Float) -> Float {
        // Pivot (1, 0) anchors the window's top-right corner (not its top-left) at the given point.
        // `.Always` re-anchors every frame, so the panel follows resizes and the Info panel's height.
        ImGui.SetNextWindowPos(ImVec2(rightEdge, top), Int32(ImGuiCond_Always.rawValue), ImVec2(1, 0))
        useSharedWidth()
        defer { ImGui.End() }
        let visible = ImGui.Begin("Settings", nil, Int32(ImGuiWindowFlags_AlwaysAutoResize.rawValue))
        let fitWidth = rl_imgui_window_fit_width()
        guard visible else { return fitWidth }

        text("Engine")
        for backend in Backend.available {
            ImGui.SameLine(0, -1)
            if ImGui.RadioButton(backend.displayName, backend == renderer.backend), backend != renderer.backend {
                renderer.onRequestBackend?(backend)
            }
        }
        ImGui.Separator()

        withUnsafeMutablePointer(to: &renderer.settings.clearColor) { color in
            color.withMemoryRebound(to: Float.self, capacity: 4) {
                _ = ImGui.ColorEdit3("Clear color", $0, 0)
            }
        }
        ImGui.Checkbox("Depth test", &renderer.settings.depthTest)
        ImGui.Checkbox("Wireframe", &renderer.settings.wireframe)
        ImGui.Checkbox("Cull faces", &renderer.settings.cullFace)
        if renderer.settings.cullFace {
            for mode in RenderSettings.CullMode.allCases {
                ImGui.SameLine(0, -1)
                if ImGui.RadioButton(mode.label, renderer.settings.cullMode == mode) {
                    renderer.settings.cullMode = mode
                }
            }
        }
        ImGui.Checkbox("VSync", &renderer.settings.vsync)

        ImGui.Separator()
        text("Blue: near, CCW, drawn first")
        text("Red:  far,  CW,  drawn second")

        renderer.drawBackendPanel()
        return fitWidth
    }

    /// Read-only overlay pinned to the top-right corner: no title bar, can't be moved,
    /// semi-transparent. Returns its bottom edge (so Settings can sit underneath) and the width its content needs.
    private static func infoWindow(_ renderer: Renderer) -> (bottom: Float, fitWidth: Float) {
        let top = ImGui.GetMainViewport().pointee.WorkPos.y + margin
        ImGui.SetNextWindowPos(ImVec2(rightEdge, top), Int32(ImGuiCond_Always.rawValue), ImVec2(1, 0))
        ImGui.SetNextWindowBgAlpha(0.35)
        useSharedWidth()
        let flags = ImGuiWindowFlags_NoDecoration.rawValue | ImGuiWindowFlags_AlwaysAutoResize.rawValue
            | ImGuiWindowFlags_NoMove.rawValue | ImGuiWindowFlags_NoSavedSettings.rawValue
            | ImGuiWindowFlags_NoFocusOnAppearing.rawValue | ImGuiWindowFlags_NoNav.rawValue
        defer { ImGui.End() }
        let visible = ImGui.Begin("Info", nil, Int32(flags))
        // Sizes come from last frame's content, so the layout settles one frame after a change.
        let frame = (bottom: ImGui.GetWindowPos().y + ImGui.GetWindowSize().y, fitWidth: rl_imgui_window_fit_width())
        guard visible else { return frame }

        text(String(format: "%.1f FPS (%.2f ms)", renderer.fps, renderer.fps > 0 ? 1000 / renderer.fps : 0))
        let size = renderer.drawableSize
        text("Drawable: \(Int(size.width)) x \(Int(size.height)) px")
        ImGui.Separator()
        for (name, value) in renderer.deviceInfo() {
            text("\(name): \(value)")
        }
        return frame
    }

    /// `ImGui::Text` is variadic (printf-style) and can't be imported, so format in Swift.
    static func text(_ string: String) {
        ImGui.TextUnformatted(string, nil)
    }
}
