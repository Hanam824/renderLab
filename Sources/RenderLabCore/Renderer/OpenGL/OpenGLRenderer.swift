import AppKit
import CImGui
import OpenGL.GL3

/// OpenGL 4.1 Core Profile backend, the newest OpenGL macOS provides.
///
/// OpenGL is a state machine: every setting is applied as global context state
/// right before drawing (glEnable/glDisable, glPolygonMode, glCullFace, ...).
final class OpenGLRenderer: Renderer {
    private let glView: GLHostView
    private var program: GLProgram?
    private var vao: GLuint = 0
    private var vbo: GLuint = 0

    override var backend: Backend { .opengl }

    init() throws {
        let attributes: [NSOpenGLPixelFormatAttribute] = [
            UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion4_1Core),
            UInt32(NSOpenGLPFAColorSize), 24,
            UInt32(NSOpenGLPFAAlphaSize), 8,
            UInt32(NSOpenGLPFADepthSize), 24,
            UInt32(NSOpenGLPFAStencilSize), 8,
            UInt32(NSOpenGLPFADoubleBuffer),
            UInt32(NSOpenGLPFAAccelerated),
            UInt32(NSOpenGLPFAMultisample),
            UInt32(NSOpenGLPFASampleBuffers), 1,
            UInt32(NSOpenGLPFASamples), 4,
            0,
        ]
        guard let format = NSOpenGLPixelFormat(attributes: attributes),
              let view = GLHostView(frame: .zero, pixelFormat: format)
        else {
            throw SetUpError.backend("No OpenGL 4.1 Core pixel format available")
        }
        // Render at full Retina resolution instead of being upscaled from points.
        view.wantsBestResolutionOpenGLSurface = true
        glView = view
        super.init(view: view)
        // Live window resizes call draw(_:); render a frame there to avoid stretching.
        view.onDraw = { [weak self] in self?.drawFrame() }
    }

    private var context: NSOpenGLContext? { glView.openGLContext }
    /// True once rl_gl3_init() succeeded, so teardown after a failed setup doesn't shut down what never started.
    private var imguiBackendReady = false
    /// The swap interval last set on the context; -1 forces the first frame to set it.
    private var appliedSwapInterval: GLint = -1
    /// GL_VERSION and friends never change for a context, so they're queried once in setUpBackend().
    private var cachedDeviceInfo: [(String, String)] = []

    override func setUpBackend() throws {
        context?.makeCurrentContext()

        program = try GLProgram(named: "triangle")
        Log.info("compiled and linked triangle shaders", category: .opengl)

        // A vertex array object (VAO) records how vertex buffers map to shader inputs.
        glGenVertexArrays(1, &vao)
        glBindVertexArray(vao)

        glGenBuffers(1, &vbo)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        Scene.vertices.withUnsafeBytes { bytes in
            glBufferData(GLenum(GL_ARRAY_BUFFER), bytes.count, bytes.baseAddress, GLenum(GL_STATIC_DRAW))
        }

        // location 0: vec3 position, location 1: vec3 color (see triangle.vert)
        let stride = GLsizei(Scene.vertexStride)
        glEnableVertexAttribArray(0)
        glVertexAttribPointer(0, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride, nil)
        glEnableVertexAttribArray(1)
        glVertexAttribPointer(1, 3, GLenum(GL_FLOAT), GLboolean(GL_FALSE), stride,
                              UnsafeRawPointer(bitPattern: Scene.colorOffset))
        glBindVertexArray(0)

        guard rl_gl3_init() else { throw SetUpError.backend("ImGui OpenGL3 backend failed to initialize") }
        imguiBackendReady = true
        appliedSwapInterval = -1
        cachedDeviceInfo = queryDeviceInfo()
    }

    override func tearDownBackend() {
        context?.makeCurrentContext()
        if imguiBackendReady {
            rl_gl3_shutdown()
            imguiBackendReady = false
        }
        glDeleteBuffers(1, &vbo)
        glDeleteVertexArrays(1, &vao)
        program?.delete()
        program = nil
        NSOpenGLContext.clearCurrentContext()
    }

    override func beginFrame() -> Bool {
        guard let context, glView.window != nil else { return false }
        context.makeCurrentContext()

        // 1 = wait for the display's vertical blank when swapping, 0 = swap immediately.
        var interval: GLint = settings.vsync ? 1 : 0
        if interval != appliedSwapInterval { // a CGL call: only make it when VSync changes
            context.setValues(&interval, for: .swapInterval)
            appliedSwapInterval = interval
        }

        let size = drawableSize
        glViewport(0, 0, GLsizei(size.width), GLsizei(size.height))

        let c = settings.clearColor
        glClearColor(c.x, c.y, c.z, c.w)
        glClearDepth(1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        return true
    }

    override func drawScene() {
        guard let program else { return }

        // Depth test: keep a fragment only if it is nearer than what is already there.
        setEnabled(GL_DEPTH_TEST, settings.depthTest)
        glDepthFunc(GLenum(GL_LESS))

        // Face culling: counter-clockwise triangles are front faces (GL default).
        setEnabled(GL_CULL_FACE, settings.cullFace)
        glFrontFace(GLenum(GL_CCW))
        glCullFace(GLenum(settings.cullMode == .back ? GL_BACK : GL_FRONT))

        glPolygonMode(GLenum(GL_FRONT_AND_BACK), GLenum(settings.wireframe ? GL_LINE : GL_FILL))

        glUseProgram(program.id)
        glBindVertexArray(vao)
        glDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(Scene.vertexCount))
        glBindVertexArray(0)

        // ImGui's backend saves and restores GL state, but reset the mode so nothing else draws as lines.
        glPolygonMode(GLenum(GL_FRONT_AND_BACK), GLenum(GL_FILL))
    }

    override func imguiBackendNewFrame() {
        rl_gl3_new_frame()
    }

    override func renderImGui() {
        rl_gl3_render_draw_data()
    }

    override func endFrame() {
        // Swap the back buffer to the screen (double buffering).
        context?.flushBuffer()
    }

    override func deviceInfo() -> [(String, String)] { cachedDeviceInfo }

    private func queryDeviceInfo() -> [(String, String)] {
        context?.makeCurrentContext()
        var samples: GLint = 0
        glGetIntegerv(GLenum(GL_SAMPLES), &samples)
        var maxTexture: GLint = 0
        glGetIntegerv(GLenum(GL_MAX_TEXTURE_SIZE), &maxTexture)
        return [
            ("GL_VERSION", glString(GL_VERSION)),
            ("GL_RENDERER", glString(GL_RENDERER)),
            ("GL_VENDOR", glString(GL_VENDOR)),
            ("GLSL", glString(GL_SHADING_LANGUAGE_VERSION)),
            ("MSAA samples", "\(samples)"),
            ("Max texture size", "\(maxTexture)"),
        ]
    }

    override func drawBackendPanel() {
        ImGui.Separator()
        Panels.text("Live GL state (glIsEnabled):")
        for (name, cap) in [("GL_DEPTH_TEST", GL_DEPTH_TEST), ("GL_CULL_FACE", GL_CULL_FACE), ("GL_MULTISAMPLE", GL_MULTISAMPLE)] {
            Panels.text("  \(name) = \(glIsEnabled(GLenum(cap)) == GLboolean(GL_TRUE) ? "ON" : "off")")
        }
    }

    private func setEnabled(_ capability: Int32, _ enabled: Bool) {
        if enabled { glEnable(GLenum(capability)) } else { glDisable(GLenum(capability)) }
    }
}

/// NSOpenGLView that accepts keyboard focus (for ImGui) and forwards AppKit redraws.
final class GLHostView: NSOpenGLView {
    var onDraw: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        onDraw?()
    }
}
