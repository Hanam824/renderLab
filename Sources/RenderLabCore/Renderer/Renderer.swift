import AppKit
import CImGui
import CoreVideo
import os

/// Base class for every graphics backend.
///
/// `drawFrame()` is a template method: the order of a frame is fixed here, and
/// subclasses (`OpenGLRenderer`, `MetalRenderer`) override only the API-specific steps.
/// The base class owns the frame timer, the FPS counter, the ImGui context and the
/// macOS ImGui platform backend; subclasses own their ImGui *renderer* backend.
@MainActor
class Renderer {
    enum SetUpError: Error, CustomStringConvertible {
        case imguiPlatform
        case backend(String)

        var description: String {
            switch self {
            case .imguiPlatform: return "ImGui macOS backend failed to initialize"
            case .backend(let message): return message
            }
        }
    }

    var settings = RenderSettings()
    /// Called when the UI asks for a different backend. `AppController` performs the switch.
    var onRequestBackend: ((Backend) -> Void)?
    /// Called after every completed frame with the total frame count.
    var onFrameRendered: ((Int) -> Void)?

    /// The view the window shows. Subclasses pass an NSOpenGLView or a CAMetalLayer-backed view.
    let view: NSView
    private(set) var fps: Double = 0
    private(set) var framesRendered = 0

    /// Drives frames with VSync off.
    private var timer: Timer?
    /// Drives frames with VSync on: calls back once per display refresh (vblank).
    private var displayLink: CVDisplayLink?
    /// True while a display-link frame is queued on the main thread, so slow frames don't pile up.
    private let displayLinkFramePending = OSAllocatedUnfairLock(initialState: false)
    /// The `settings.vsync` value the current frame source was set up for.
    private var frameSourceVsync = true
    private var fpsFrames = 0
    private var fpsWindowStart = CACurrentMediaTime()
    private var isRunning = false

    init(view: NSView) {
        self.view = view
    }

    // MARK: - Overridden by subclasses

    var backend: Backend { fatalError("\(Self.self) must override backend") }

    /// Create API objects (context/device, buffers, shaders) and the ImGui renderer backend.
    func setUpBackend() throws {}
    /// Destroy everything `setUpBackend()` created, including the ImGui renderer backend.
    /// Also called when `setUpBackend()` throws halfway, so it must cope with partial setup.
    func tearDownBackend() {}
    /// Prepare a frame (make context current / acquire an image) and clear it.
    /// Return false to skip this frame, e.g. while the window is minimized.
    func beginFrame() -> Bool { true }
    /// Draw the test scene with the current `settings`.
    func drawScene() {}
    /// Start a new frame in the ImGui renderer backend.
    func imguiBackendNewFrame() {}
    /// Record ImGui's draw data with the backend's API.
    func renderImGui() {}
    /// Present the frame.
    func endFrame() {}
    /// Name/value rows for the Info panel. Called every frame: return cached values, don't query the GPU.
    func deviceInfo() -> [(String, String)] { [] }
    /// Extra ImGui widgets specific to this backend.
    func drawBackendPanel() {}

    // MARK: - Lifecycle

    func start() throws {
        rl_imgui_create()
        guard rl_osx_init(viewPointer) else {
            rl_imgui_destroy()
            throw SetUpError.imguiPlatform
        }
        do {
            try setUpBackend()
        } catch {
            // Free whatever setUpBackend() created before it failed; tearDownBackend() copes with partial setup.
            tearDownBackend()
            rl_osx_shutdown()
            rl_imgui_destroy()
            throw error
        }
        isRunning = true
        if Log.isEnabled(.info) { // skip the GL/Metal queries entirely when logging is off
            for (name, value) in deviceInfo() {
                Log.info("\(name): \(value)", category: .renderer)
            }
        }
        startFrameSource()

        // Draw the first frame now, in the same run-loop turn that put the view in the window,
        // instead of showing an empty view until the timer first fires (that gap is a visible flicker).
        settleImGuiLayout()
        drawFrame()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        Log.info("stopping \(backend.displayName) after \(framesRendered) frames", category: .renderer)
        stopFrameSource()
        tearDownBackend()
        rl_osx_shutdown()
        rl_imgui_destroy()
    }

    // MARK: - Frame

    /// One frame. The order is the same for every backend.
    final func drawFrame() {
        guard isRunning else { return }
        guard beginFrame() else { return }
        updateFPS() // only frames that are actually drawn count toward FPS

        drawScene()

        imguiBackendNewFrame()
        rl_osx_new_frame(viewPointer)
        rl_imgui_begin_frame()
        Panels.draw(for: self)
        rl_imgui_end_frame()
        renderImGui()

        endFrame()
        framesRendered += 1
        onFrameRendered?(framesRendered)

        if settings.vsync != frameSourceVsync {
            stopFrameSource()
            startFrameSource()
        }
    }

    // MARK: - Frame pacing

    /// What asks for frames sets the *most* frames we get, so it must not cap FPS on its own.
    /// Every frame runs on the main thread, which keeps all AppKit, ImGui and GL calls on one thread.
    ///
    /// - VSync on: a `CVDisplayLink` fires once per display refresh, so frames line up with vblank.
    ///   (A fixed-rate Timer drifts against vblank and misses refreshes, and macOS doesn't reliably
    ///   block in the OpenGL swap, so neither can pace frames on its own.)
    /// - VSync off: a Timer ticks as fast as the run loop allows (Timer treats 0 as 0.1 ms), so FPS is
    ///   limited only by how fast the CPU and GPU produce frames. `.common` mode keeps it firing
    ///   during window resizes and menu tracking.
    private func startFrameSource() {
        frameSourceVsync = settings.vsync
        if settings.vsync, startDisplayLink() {
            Log.info("frame pacing: display link (VSync on)", category: .renderer)
            return
        }
        Log.info("frame pacing: timer, uncapped (VSync \(settings.vsync ? "on, display link unavailable" : "off"))", category: .renderer)

        let timer = Timer(timeInterval: 0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.drawFrame() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopFrameSource() {
        timer?.invalidate()
        timer = nil
        if let displayLink {
            CVDisplayLinkStop(displayLink)
            self.displayLink = nil
        }
    }

    /// Returns false if no display link could be created (the caller falls back to the timer).
    private func startDisplayLink() -> Bool {
        var link: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&link) == kCVReturnSuccess, let link else { return false }
        // Follow the refresh rate of the screen the window is on.
        if let screenNumber = view.window?.screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            CVDisplayLinkSetCurrentCGDisplay(link, screenNumber.uint32Value)
        }
        let pending = displayLinkFramePending
        // Runs on a CoreVideo background thread: hop to the main thread to draw.
        CVDisplayLinkSetOutputHandler(link) { [weak self] _, _, _, _, _ in
            let alreadyQueued = pending.withLock { queued in
                defer { queued = true }
                return queued
            }
            guard !alreadyQueued else { return kCVReturnSuccess }
            DispatchQueue.main.async {
                pending.withLock { $0 = false }
                MainActor.assumeIsolated { self?.drawFrame() }
            }
            return kCVReturnSuccess
        }
        guard CVDisplayLinkStart(link) == kCVReturnSuccess else { return false }
        displayLink = link
        return true
    }

    /// ImGui hides auto-resizing windows on their first frame, and `Panels` sizes its stack from the
    /// previous frame. A few UI-only frames (nothing drawn or presented) let the first visible frame
    /// show the final layout instead of panels jumping into place.
    private func settleImGuiLayout() {
        for _ in 0..<3 {
            imguiBackendNewFrame()
            rl_osx_new_frame(viewPointer)
            rl_imgui_begin_frame()
            Panels.draw(for: self)
            rl_imgui_end_frame()
        }
    }

    /// Size of the view in pixels (points × backing scale on Retina displays).
    var drawableSize: CGSize {
        view.convertToBacking(view.bounds).size
    }

    private var viewPointer: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(view).toOpaque()
    }

    private func updateFPS() {
        fpsFrames += 1
        let now = CACurrentMediaTime()
        let elapsed = now - fpsWindowStart
        if elapsed >= 0.5 {
            fps = Double(fpsFrames) / elapsed
            Log.debug(String(format: "%.1f FPS (%.3f ms)", fps, 1000 / fps), category: .renderer)
            fpsFrames = 0
            fpsWindowStart = now
        }
    }
}
