import AppKit

/// Entry point used by `Sources/RenderLab/main.swift`.
public enum RenderLabApp {
    @MainActor
    public static func run(arguments: [String]) {
        if arguments.contains("--help") || arguments.contains("-h") {
            print(LaunchOptions.usage)
            return
        }

        let options: LaunchOptions
        do {
            options = try LaunchOptions(arguments: arguments)
        } catch {
            FileHandle.standardError.write(Data("RenderLab: \(error)\n".utf8))
            exit(2)
        }
        Log.minimumLevel = options.logLevel
        let backend = options.backend
        let exitAfterFrames = options.exitAfterFrames

        let app = NSApplication.shared
        // A plain executable (not a .app bundle) must opt in to a Dock icon and menu bar.
        app.setActivationPolicy(.regular)
        Log.info("starting with \(backend.displayName)" + (exitAfterFrames.map { ", smoke test of \($0) frames" } ?? ""))
        let controller = AppController(initialBackend: backend, exitAfterFrames: exitAfterFrames)
        app.delegate = controller
        app.run()
    }
}

/// Owns the window and the current `Renderer`. Switching backend tears the old
/// renderer down completely and builds a new one in the same window.
@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let initialBackend: Backend
    private let exitAfterFrames: Int?
    private var window: NSWindow!
    private var renderer: Renderer?
    private var backendMenuItems: [Backend: NSMenuItem] = [:]

    init(initialBackend: Backend, exitAfterFrames: Int? = nil) {
        self.initialBackend = initialBackend
        self.exitAfterFrames = exitAfterFrames
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.mainMenu = makeMainMenu()
        NSApp.activate(ignoringOtherApps: true)

        switchTo(initialBackend)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        renderer?.stop()
    }

    // MARK: - Backend switching

    /// `settings` is only passed by the fallback after a failed start, when `renderer` is already gone.
    func switchTo(_ backend: Backend, settings carriedSettings: RenderSettings? = nil) {
        // Keep the user's toggles (clear color, depth, cull...) across the switch.
        let settings = carriedSettings ?? renderer?.settings ?? RenderSettings()
        if let current = renderer?.backend {
            Log.info("switching \(current.displayName) -> \(backend.displayName)")
        }
        let switchStart = CACurrentMediaTime()
        renderer?.stop()
        renderer = nil

        // Shown wherever the new view hasn't drawn yet; matching the clear color hides that gap.
        let c = settings.clearColor
        window.backgroundColor = NSColor(srgbRed: CGFloat(c.x), green: CGFloat(c.y), blue: CGFloat(c.z), alpha: 1)

        do {
            let newRenderer = try makeRenderer(backend)
            newRenderer.settings = settings
            window.contentView = newRenderer.view
            window.makeFirstResponder(newRenderer.view)
            // Set the callbacks before start(): start() already draws the first frame.
            newRenderer.onRequestBackend = { [weak self] backend in
                // Never tear down a renderer from inside its own frame: switch on the next run-loop turn.
                DispatchQueue.main.async { self?.switchTo(backend) }
            }
            if let exitAfterFrames {
                newRenderer.onFrameRendered = { [weak newRenderer] frames in
                    guard frames >= exitAfterFrames, let newRenderer else { return }
                    newRenderer.onFrameRendered = nil // report once, even if another frame runs before quitting
                    let info = newRenderer.deviceInfo().prefix(2).map { "\($0.0)=\($0.1)" }.joined(separator: ", ")
                    print("RenderLab: rendered \(frames) frames with \(backend.displayName) (\(info))")
                    // Like a backend switch, quit on the next run-loop turn, not from inside this frame.
                    DispatchQueue.main.async { NSApp.terminate(nil) }
                }
            }
            try newRenderer.start()
            renderer = newRenderer
            Log.info(String(format: "%@ ready in %.1f ms", backend.displayName, (CACurrentMediaTime() - switchStart) * 1000))
            window.title = "renderLab — \(backend.displayName)"
        } catch {
            Log.error("\(backend.displayName) failed to start: \(error)")
            if exitAfterFrames != nil {
                FileHandle.standardError.write(Data("RenderLab: \(backend.displayName) failed: \(error)\n".utf8))
                exit(1)
            }
            let alert = NSAlert()
            alert.messageText = "\(backend.displayName) renderer failed to start"
            alert.informativeText = "\(error)"
            alert.runModal()
            if backend != .opengl {
                switchTo(.opengl, settings: settings)
                return
            }
            NSApp.terminate(nil)
        }

        for (item, menuItem) in backendMenuItems {
            menuItem.state = item == renderer?.backend ? .on : .off
        }
    }

    private func makeRenderer(_ backend: Backend) throws -> Renderer {
        switch backend {
        case .opengl:
            return try OpenGLRenderer()
        case .metal:
            return try MetalRenderer()
        }
    }

    // MARK: - Menu

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit renderLab", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(submenu(appMenu, title: "renderLab"))

        let backendMenu = NSMenu(title: "Engine")
        for (index, backend) in Backend.available.enumerated() {
            let item = NSMenuItem(title: backend.displayName, action: #selector(selectBackend(_:)), keyEquivalent: "\(index + 1)")
            item.target = self
            item.representedObject = backend.rawValue
            backendMenu.addItem(item)
            backendMenuItems[backend] = item
        }
        mainMenu.addItem(submenu(backendMenu, title: "Engine"))

        return mainMenu
    }

    private func submenu(_ menu: NSMenu, title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    @objc private func selectBackend(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let backend = Backend(rawValue: raw),
              backend != renderer?.backend else { return }
        switchTo(backend)
    }
}
