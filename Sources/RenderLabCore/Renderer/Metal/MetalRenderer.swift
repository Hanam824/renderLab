import AppKit
import CImGui
import ImGuiMetal
import Metal
import QuartzCore

/// Renders the scene with Metal, Apple's native GPU API, into a `CAMetalLayer`.
///
/// OpenGL keeps everything in one global state machine. Metal splits state in two:
/// - Objects built up front and reused: `MTLRenderPipelineState` (shaders, vertex layout,
///   pixel formats) and `MTLDepthStencilState` (depth test), cached per variant.
/// - State set on the command encoder every frame: cull mode, front-face winding, fill mode (wireframe).
///
/// A frame records commands into an `MTLCommandBuffer` through an `MTLRenderCommandEncoder`,
/// then presents a drawable from the layer and commits the buffer to the GPU.
final class MetalRenderer: Renderer {
    enum BuildError: Error, CustomStringConvertible {
        case noDevice
        case shader(String)
        case pipeline(String)

        var description: String {
            switch self {
            case .noDevice: return "No Metal device found"
            case .shader(let log): return "triangle.metal failed to compile:\n\(log)"
            case .pipeline(let log): return "render pipeline state failed to build:\n\(log)"
            }
        }
    }

    static let colorFormat: MTLPixelFormat = .bgra8Unorm
    static let depthFormat: MTLPixelFormat = .depth32Float

    private let metalView: MetalHostView
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var depthTexture: MTLTexture?
    /// One depth-stencil state per "depth test on/off", built the first time each is needed.
    private var depthStates: [Bool: MTLDepthStencilState] = [:]
    /// True once rl_metal_init() succeeded, so teardown after a failed setup doesn't shut down what never started.
    private var imguiBackendReady = false
    /// Device facts that never change, computed once in setUpBackend().
    private var cachedDeviceInfo: [(String, String)] = []
    /// The last committed command buffer, so teardown can wait for the GPU to finish with it.
    private var lastCommandBuffer: MTLCommandBuffer?

    // Per-frame objects, valid from beginFrame() to endFrame().
    private var drawable: CAMetalDrawable?
    private var passDescriptor: MTLRenderPassDescriptor?
    private var commandBuffer: MTLCommandBuffer?
    private var encoder: MTLRenderCommandEncoder?

    override var backend: Backend { .metal }

    init() throws {
        metalView = MetalHostView(frame: .zero)
        super.init(view: metalView)
    }

    // MARK: - Setup

    override func setUpBackend() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw BuildError.noDevice }
        self.device = device
        // The queue hands command buffers to the GPU in the order they are committed.
        commandQueue = device.makeCommandQueue()

        let layer = metalView.metalLayer
        layer.device = device
        layer.pixelFormat = Self.colorFormat
        layer.framebufferOnly = true   // drawables are only rendered to, never sampled: lets Metal optimize
        layer.maximumDrawableCount = 3 // triple buffering (2 is the minimum)

        pipelineState = try Self.makePipelineState(device: device)
        Log.info("compiled triangle.metal and built the render pipeline state", category: .metal)

        // .storageModeShared: CPU and GPU see the same memory, so no explicit upload is needed.
        vertexBuffer = Scene.vertices.withUnsafeBytes { bytes in
            device.makeBuffer(bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared)
        }

        guard rl_metal_init(Self.opaque(device)) else {
            throw SetUpError.backend("ImGui Metal backend failed to initialize")
        }
        imguiBackendReady = true
        cachedDeviceInfo = Self.queryDeviceInfo(device)
    }

    override func tearDownBackend() {
        lastCommandBuffer?.waitUntilCompleted()
        if imguiBackendReady {
            rl_metal_shutdown()
            imguiBackendReady = false
        }
        lastCommandBuffer = nil
        depthStates = [:]
        cachedDeviceInfo = []
        depthTexture = nil
        vertexBuffer = nil
        pipelineState = nil
        commandQueue = nil
        device = nil
    }

    /// Compiles `Shaders/metal/triangle.metal` and builds the pipeline state for the scene.
    /// Static so the tests can build it without a window.
    static func makePipelineState(device: MTLDevice) throws -> MTLRenderPipelineState {
        let source = try ShaderLibrary.metalSource("triangle")
        let library: MTLLibrary
        do {
            // Runtime compilation, like glCompileShader: works without Xcode's `metal` tool.
            library = try device.makeLibrary(source: source, options: nil)
        } catch {
            throw BuildError.shader(error.localizedDescription)
        }
        guard let vertexFunction = library.makeFunction(name: "triangle_vertex"),
              let fragmentFunction = library.makeFunction(name: "triangle_fragment")
        else {
            throw BuildError.shader("missing triangle_vertex or triangle_fragment")
        }

        // How the interleaved vertex buffer maps to [[attribute(n)]] in the shader:
        // the Metal version of glVertexAttribPointer, but baked into the pipeline.
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3 // position
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float3 // color
        vertexDescriptor.attributes[1].offset = Scene.colorOffset
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = Scene.vertexStride

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "triangle"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.vertexDescriptor = vertexDescriptor
        descriptor.colorAttachments[0].pixelFormat = colorFormat
        descriptor.depthAttachmentPixelFormat = depthFormat
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            throw BuildError.pipeline(error.localizedDescription)
        }
    }

    // MARK: - Frame

    override func beginFrame() -> Bool {
        guard let device, let commandQueue, metalView.window != nil else { return false }
        let size = drawableSize
        guard size.width > 0, size.height > 0 else { return false } // minimized

        let layer = metalView.metalLayer
        if layer.drawableSize != size {
            layer.drawableSize = size
            Log.info("drawable size \(Int(size.width))x\(Int(size.height))", category: .metal)
        }
        // VSync: with display sync on, a presented drawable waits for the display's vertical blank.
        layer.displaySyncEnabled = settings.vsync

        // Waits until the window server hands back a free drawable (at most maximumDrawableCount exist).
        guard let drawable = layer.nextDrawable() else { return false }

        if depthTexture?.width != Int(size.width) || depthTexture?.height != Int(size.height) {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: Self.depthFormat, width: Int(size.width), height: Int(size.height), mipmapped: false
            )
            descriptor.usage = .renderTarget
            descriptor.storageMode = .private // GPU-only memory
            depthTexture = device.makeTexture(descriptor: descriptor)
        }

        // The render pass: which textures to draw into and what to do with them at the start
        // (loadAction .clear = glClear) and at the end (storeAction).
        let pass = MTLRenderPassDescriptor()
        let c = settings.clearColor
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: Double(c.x), green: Double(c.y), blue: Double(c.z), alpha: Double(c.w))
        pass.depthAttachment.texture = depthTexture
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare // depth isn't needed after the frame
        pass.depthAttachment.clearDepth = 1

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)
        else { return false }

        self.drawable = drawable
        self.passDescriptor = pass
        self.commandBuffer = commandBuffer
        self.encoder = encoder
        return true
    }

    override func drawScene() {
        guard let encoder, let pipelineState, let vertexBuffer else { return }
        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState(testEnabled: settings.depthTest))
        // Metal's default front face is clockwise; make counter-clockwise the front, as in OpenGL.
        encoder.setFrontFacing(.counterClockwise)
        encoder.setCullMode(settings.cullFace ? (settings.cullMode == .back ? .back : .front) : .none)
        encoder.setTriangleFillMode(settings.wireframe ? .lines : .fill)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: Scene.vertexCount)
        // ImGui's Metal backend resets cull mode but not fill mode: don't draw the UI in wireframe.
        encoder.setTriangleFillMode(.fill)
    }

    override func imguiBackendNewFrame() {
        // Nil only during Renderer's UI-only warm-up frames, before the first real frame.
        guard let passDescriptor else { return }
        rl_metal_new_frame(Self.opaque(passDescriptor))
    }

    override func renderImGui() {
        guard let commandBuffer, let encoder else { return }
        rl_metal_render_draw_data(Self.opaque(commandBuffer), Self.opaque(encoder))
    }

    override func endFrame() {
        guard let encoder, let commandBuffer, let drawable else { return }
        encoder.endEncoding()
        // Show the drawable once the GPU has finished rendering into it.
        commandBuffer.present(drawable)
        commandBuffer.commit()
        lastCommandBuffer = commandBuffer

        self.encoder = nil
        self.commandBuffer = nil
        self.drawable = nil
        self.passDescriptor = nil
    }

    /// Depth test on: keep the nearest fragment and write its depth. Off: always pass, write nothing
    /// (what OpenGL does when GL_DEPTH_TEST is disabled).
    private func depthState(testEnabled: Bool) -> MTLDepthStencilState? {
        if let state = depthStates[testEnabled] { return state }
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = testEnabled ? .less : .always
        descriptor.isDepthWriteEnabled = testEnabled
        let state = device?.makeDepthStencilState(descriptor: descriptor)
        depthStates[testEnabled] = state
        Log.info("built depth-stencil state: depth test \(testEnabled ? "on" : "off")", category: .metal)
        return state
    }

    /// Objective-C objects cross the C shim as unretained opaque pointers.
    private static func opaque(_ object: AnyObject) -> UnsafeMutableRawPointer {
        Unmanaged.passUnretained(object).toOpaque()
    }

    // MARK: - UI

    override func deviceInfo() -> [(String, String)] {
        guard device != nil else { return [] }
        let layer = metalView.metalLayer
        // The two layer rows are plain property reads, so they stay live.
        return cachedDeviceInfo + [
            ("Drawables", "\(layer.maximumDrawableCount)"),
            ("Display sync", layer.displaySyncEnabled ? "on (VSync)" : "off"),
        ]
    }

    private static func queryDeviceInfo(_ device: MTLDevice) -> [(String, String)] {
        let bytes = { (count: UInt64) in ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .memory) }
        return [
            ("Device", device.name),
            ("GPU families", gpuFamilies(device)),
            ("Low power", device.isLowPower ? "yes" : "no"),
            ("Unified memory", device.hasUnifiedMemory ? "yes" : "no"),
            ("Working set", bytes(device.recommendedMaxWorkingSetSize)),
            ("Max buffer", bytes(UInt64(device.maxBufferLength))),
        ]
    }

    override func drawBackendPanel() {
        ImGui.Separator()
        Panels.text("Depth-stencil states built: \(depthStates.count) of 2")
        Panels.text("Depth test lives in an MTLDepthStencilState;")
        Panels.text("cull and fill mode are set on the encoder")
        Panels.text("every frame.")
    }

    private static func gpuFamilies(_ device: MTLDevice) -> String {
        let families: [(MTLGPUFamily, String)] = [
            (.metal3, "Metal 3"), (.mac2, "Mac 2"), (.apple8, "Apple 8"), (.apple7, "Apple 7"),
        ]
        let supported = families.filter { device.supportsFamily($0.0) }.map(\.1)
        return supported.isEmpty ? "unknown" : supported.joined(separator: ", ")
    }
}

/// NSView backed by a CAMetalLayer, which `MetalRenderer` draws into.
final class MetalHostView: NSView {
    var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func makeBackingLayer() -> CALayer { CAMetalLayer() }

    override var acceptsFirstResponder: Bool { true }

    /// Keep the layer at full Retina resolution when the window moves between displays.
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layer?.contentsScale = window?.backingScaleFactor ?? 1
    }
}
