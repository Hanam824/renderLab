# renderLab

A personal playground for learning **Swift**, **OpenGL** and **Metal** together, using
**Dear ImGui** as a live control panel to toggle graphics flags and features and
see their effect immediately.

## Purpose

- Learn Swift by building a small, real rendering app instead of toy examples.
- Understand graphics state by flipping it at runtime rather than reading about it.
- Render the same scene with **OpenGL and Metal** side by side and compare how each API
  expresses the same feature (global state machine vs. state objects and command encoders).
- Use Dear ImGui to expose each flag/feature as a checkbox, slider or combo box,
  so cause and effect are visible right next to each other.

## Requirements

| | Minimum | Notes |
| --- | --- | --- |
| macOS | **13 Ventura** | Intel or Apple Silicon |
| Swift | **6.0** | Xcode 16+ or the Command Line Tools |
| Xcode | 16+ (for tests) | `swift test` needs Xcode's toolchain; see [Testing](#testing) |
| GPU | OpenGL 4.1 / Metal | Every Mac that runs macOS 13 has both |
| git | any | ImGui is a git submodule |

No other installs are needed: OpenGL and Metal ship with macOS, and Metal shaders are compiled at runtime.

Check your machine before building:

```bash
./scripts/doctor.sh
```

It checks macOS, Swift, Xcode, the ImGui submodule, OpenGL and Metal.
For each problem it prints a fix, and it exits non-zero if a required check fails.

## Getting started

```bash
git clone git@github.com:Hanam824/renderLab.git
cd renderLab
./run.sh            # OpenGL (default)
./run.sh metal      # Metal
./run.sh test       # unit tests
```

`run.sh` does the following:
1. Fetches the ImGui submodule if it's missing.
2. Runs `scripts/doctor.sh --quick` and stops if a required check fails.
3. Builds the app in release mode and runs it. For a debug build, add `--config debug` (for example `./run.sh metal --config debug`).

Extra arguments go to the app, for example `./run.sh metal --frames 120`.
Add `--log` to print diagnostic logs (renderer start/stop, shader and state-object builds) to stderr, or `--log=debug` to also print FPS twice a second. Logging is off by default.
For tests, it uses Xcode's toolchain automatically when only the Command Line Tools are selected.

Running the steps by hand:

```bash
git submodule update --init
./scripts/doctor.sh
swift run RenderLab                    # OpenGL (default)
swift run RenderLab --backend metal    # Metal
```

You can switch backends at runtime from the **Engine** menu (⌘1 / ⌘2) or the Engine radio buttons
in the Settings panel. To work in Xcode, run `open Package.swift`.

`swift run RenderLab --frames 120` renders 120 frames, prints the GPU and API version and quits.
Use it as a quick smoke test.

## Testing

Tests use [Swift Testing](https://developer.apple.com/xcode/swift-testing/) (`import Testing`, `@Test`, `#expect`).

```bash
swift test                              # all tests
swift test --filter BackendTests        # one suite
swift test --filter "parsesMetal"       # one test
```

GPU tests (tag `gpu`) create a headless OpenGL 4.1 context and a Metal device, compile the
shaders and build the Metal pipeline. They skip themselves when no GPU is available.

> `swift test` needs Xcode's toolchain. With only the Command Line Tools selected it can fail with
> `no such module 'Testing'`. Fix it once with `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`,
> or per command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`.

## What to experiment with

The test scene is two overlapping triangles, set up so each toggle has a visible effect:

- **Blue** is nearer but drawn first, and wound counter-clockwise (a front face).
- **Red** is farther but drawn second, and wound clockwise (a back face).

| Toggle | What you see | OpenGL | Metal |
| --- | --- | --- | --- |
| Depth test | Off: red paints over blue | `glEnable(GL_DEPTH_TEST)` (global state) | `MTLDepthStencilState` object, built once per variant and cached |
| Cull faces | Back: red disappears; Front: blue disappears | `glCullFace` | `setCullMode` on the encoder, every frame |
| Wireframe | Triangle edges only | `glPolygonMode(GL_LINE)` | `setTriangleFillMode(.lines)` on the encoder, every frame |
| VSync | FPS capped at the display rate or not | swap interval | `CAMetalLayer.displaySyncEnabled` |
| Clear color | Background | `glClearColor` | render pass descriptor `clearColor` |

Metal bakes only the shaders, vertex layout and pixel formats into its `MTLRenderPipelineState`, so the
scene needs a single pipeline state plus two depth-stencil states. OpenGL has no state objects at all:
every toggle is a global switch.

Planned feature areas:

| Area | Examples |
| --- | --- |
| Blending | `GL_BLEND`, `glBlendFunc`, `glBlendEquation` |
| Stencil | `GL_STENCIL_TEST`, `glStencilFunc`, `glStencilOp` |
| Rasterization | line width, `GL_SCISSOR_TEST` |
| Multisampling | `GL_MULTISAMPLE`, sample counts |
| Textures | min/mag filters, wrap modes, mipmaps |
| Color | `GL_FRAMEBUFFER_SRGB`, color mask |
| Shaders | uniforms, hot-reloading |

## Architecture

```
Sources/
  CImGui/          Dear ImGui core + macOS and OpenGL3 backends (C++/ObjC++), rl_* C shim
  ImGuiMetal/      Dear ImGui Metal backend + rl_metal_* shim (built with ARC)
  RenderLabCore/   All Swift code: renderers (OpenGL/, Metal/), settings, UI panels, logging, shaders
  RenderLab/       Executable entry point (main.swift)
Tests/RenderLabCoreTests/
ThirdParty/imgui/  Dear ImGui git submodule
scripts/           doctor.sh
run.sh             one-step setup + run / test
```

- **Native Swift + AppKit.** There's no GLFW. OpenGL renders into an `NSOpenGLView`, and Metal renders into a
  `CAMetalLayer`-backed `NSView`.
- **One base class, two renderers.** `Renderer` owns the frame loop, ImGui and the shared
  `RenderSettings`. Its `drawFrame()` fixes the order of a frame
  (begin → scene → ImGui → end), and `OpenGLRenderer` and `MetalRenderer` override each step.
- **ImGui from Swift.** Widgets are called directly through Swift/C++ interop
  (`ImGui.Checkbox("Wireframe", &settings.wireframe)`). A small C shim wraps the
  backend functions, whose headers use Objective-C types.

### Tech stack

- **Swift 6** (Swift 5 language mode), Swift Package Manager
- **OpenGL 4.1 Core Profile**, the highest version macOS supports (GLSL `#version 410 core`)
- **Metal**, called directly from Swift; shaders are Metal Shading Language compiled at runtime
  (`device.makeLibrary(source:)`), so the Command Line Tools are enough
- **Dear ImGui** v1.93.0 as a git submodule

> Apple deprecated OpenGL in macOS 10.14. It still works and is fine for learning, but it is
> capped at 4.1, so compute shaders and debug output (4.3+) are not available. Those are
> good things to try on the Metal side instead.

> **Why not Vulkan?** renderLab was first prototyped with a Vulkan engine. On macOS, Vulkan runs through
> [MoltenVK](https://github.com/KhronosGroup/MoltenVK), which translates every call into Metal, and it
> needed extra Homebrew packages and SPIR-V precompilation. Measured on this project, it was no faster
> than plain Metal, so renderLab talks to Metal directly.

## Roadmap

- [x] Project skeleton: window, GL 4.1 core context, render loop
- [x] Integrate Dear ImGui with the OpenGL3 backend
- [x] Metal backend with the same scene and toggles
- [x] Draw a basic scene (two triangles for depth and culling)
- [x] GL/Metal info panel
- [ ] Textured cube with a camera
- [ ] Add a panel for each planned feature area above
- [ ] Shader hot-reload

## License

[MIT](LICENSE)
