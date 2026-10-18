# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

renderLab is a learning playground for **Swift**, **OpenGL** and **Metal**. Dear ImGui provides live controls that toggle graphics state at runtime. The same scene renders with either API, so the two can be compared. The feature areas and roadmap are in `README.md`.

The user is learning Swift and both graphics APIs. Favor clear, explanatory code over clever abstractions. Short comments saying what a GL/Metal call does are welcome.

## Commands

```bash
./run.sh [opengl|metal|test] [args...]    # submodule init + doctor + swift run -c release / swift test
./run.sh metal --config debug            # --config release|debug; app defaults to release, tests to debug
./run.sh metal --log                     # diagnostic logs to stderr (off by default); --log=debug adds FPS
./scripts/doctor.sh                       # check the machine (macOS, Swift, submodule, OpenGL, Metal); run.sh uses --quick
swift build
swift run RenderLab [--backend opengl|metal]
swift run RenderLab --backend metal --frames 120   # smoke test: render N frames, print GPU info, exit (1 on failure)
swift test                                # Swift Testing; needs Xcode's toolchain (see below)
swift test --filter BackendTests          # one suite; --filter "parsesMetal" for one test
git submodule update --init               # ThirdParty/imgui
```

On this machine `xcode-select` points to the Command Line Tools, and `swift test` fails there with `no such module 'Testing'`. Run tests as `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`. `swift build` and `swift run` work with either toolchain.

Verify rendering with `--frames N` on both backends. Screen capture isn't available to the agent.

## Architecture

- **SwiftPM only, no .xcodeproj.** Both engines are always built; no external dependencies besides the ImGui submodule.
- **`Renderer` base class** (`Sources/RenderLabCore/Renderer/Renderer.swift`) is a template method. `drawFrame()` fixes the order: `beginFrame` → `drawScene` → ImGui (`imguiBackendNewFrame`, platform new frame, `Panels.draw`) → `renderImGui` → `endFrame`. `OpenGLRenderer` and `MetalRenderer` override the steps. The base class owns frame pacing on the main thread (a `CVDisplayLink` with VSync on, an uncapped `Timer` with it off), the FPS counter, the ImGui context and the macOS ImGui platform backend. Subclasses own their ImGui *renderer* backend.
- **`RenderSettings`** is shared state edited by `UI/Panels.swift`. OpenGL applies it as global state each frame. Metal keeps the depth test in cached `MTLDepthStencilState` objects and sets cull, winding and fill mode on the encoder each frame; its single `MTLRenderPipelineState` only bakes shaders, vertex layout and pixel formats. Keep that contrast when adding settings: say in a comment which side (state object or encoder state) a new Metal setting lives on.
- **`AppController`** owns the window and switches backends by fully stopping one renderer and starting another. UI-triggered switches are deferred with `DispatchQueue.main.async`, never done mid-frame.
- **ImGui integration.** The submodule lives at `ThirdParty/imgui`, outside `Sources/`. The C/C++ targets compile it through wrapper files that `#include` the submodule sources (`Sources/CImGui/ImGuiCore.cpp`, `ImGuiPlatform.mm` for the macOS + OpenGL3 backends, `Sources/ImGuiMetal/ImGuiMetal.mm` for the Metal backend). Swift calls widgets directly via C++ interop (`ImGui.Checkbox(label, &bool)`). Backend calls go through the `rl_*` shims, because their headers use ObjC types.
  - The target is named `CImGui` so its name doesn't clash with the C++ `ImGui` namespace.
  - `ImGui::Text` is variadic and can't be imported. Use `Panels.text(_:)`, which wraps `TextUnformatted`.
  - The `rl_metal_*` shim takes Metal objects as `void*` (`Unmanaged.passUnretained(x).toOpaque()` on the Swift side, `__bridge` casts in `ImGuiMetal.mm`).
  - The Metal backend is its own target, `ImGuiMetal`, built with `-fobjc-arc`: `imgui_impl_metal.mm` relies on ARC to free objects it allocates every frame (its manual `release` calls only apply to the metal-cpp build). Without ARC it leaks every frame. CImGui stays non-ARC. The two also can't share one file, because `imgui_impl_osx.mm` and `imgui_impl_metal.mm` both define a static `GetMachAbsoluteTimeInSeconds`.
- **`LaunchOptions`** (`Sources/RenderLabCore/LaunchOptions.swift`) parses the command line. Every option accepts `--name value` and `--name=value`; unknown `--` options exit 2 instead of being ignored.
- **`Log`** (`Sources/RenderLabCore/Log.swift`) is opt-in logging to stderr, off unless `--log[=level]` is passed. Messages are `@autoclosure`s, so disabled calls cost one check. Use it instead of `print` for diagnostics; keep `print` for the `--frames` status line and fatal errors.
- **Shaders** are bundle resources (`resources: [.copy("Shaders")]`), loaded via `ShaderLibrary`.

## Technical constraints

- **macOS 13+**, Swift 6.0 tools, Swift 5 language mode.
- **OpenGL 4.1 Core max.** Don't use 4.3+ features (compute shaders, `glDebugMessageCallback`, SSBOs). GLSL is `#version 410 core`. Deprecation warnings are silenced with `GL_SILENCE_DEPRECATION`: a C define for C targets, `-Xcc -D` for Swift.
- **Metal.** Shaders are Metal Shading Language in `Shaders/metal/*.metal`, compiled at runtime with `device.makeLibrary(source:)`: the Command Line Tools have no `metal` compiler, so don't add build-time `.metal` compilation. Clip space has Y up like OpenGL (no flip); depth range is 0..1. Metal's default front face is clockwise, so `MetalRenderer` sets `.counterClockwise` to keep CCW = front in both engines. ImGui's Metal backend doesn't reset the triangle fill mode, so reset it to `.fill` after the scene.
- No Vulkan: it ran through MoltenVK (a translation layer to Metal) and was no faster than Metal on this project, so it was removed.
- Commit `Package.resolved` if one appears. It is deliberately not in `.gitignore`.

## Repo

- Remote `git@github.com:Hanam824/renderLab.git` (public), default branch `main`.
- Commits use the `create-commit-message` skill (Conventional Commits, `# Summary` bullet body, no co-author line). Branches use `create-commit-branch`.
