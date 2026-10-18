# renderLab

A personal playground for learning **Swift** and **OpenGL** together, using
**Dear ImGui** as a live control panel to toggle OpenGL flags and features and
see their effect immediately.

## Purpose

- Learn Swift by building a small, real rendering app instead of toy examples.
- Understand OpenGL state by flipping it at runtime rather than reading about it.
- Use Dear ImGui to expose each flag/feature as a checkbox, slider or combo box,
  so cause and effect are visible side by side.

## What to experiment with

Each feature gets its own ImGui panel with a short note on what it does.

| Area | Examples |
| --- | --- |
| Depth | `GL_DEPTH_TEST`, `glDepthFunc`, depth mask, near/far planes |
| Culling | `GL_CULL_FACE`, `glCullFace`, `glFrontFace` |
| Blending | `GL_BLEND`, `glBlendFunc`, `glBlendEquation` |
| Stencil | `GL_STENCIL_TEST`, `glStencilFunc`, `glStencilOp` |
| Rasterization | `glPolygonMode` (wireframe), line width, `GL_SCISSOR_TEST` |
| Multisampling | `GL_MULTISAMPLE`, sample counts |
| Textures | min/mag filters, wrap modes, mipmaps |
| Color | `glClearColor`, `GL_FRAMEBUFFER_SRGB`, color mask |
| Shaders | uniforms, hot-reloading GLSL |
| Info | `GL_VERSION`, `GL_RENDERER`, extensions, limits (`glGetIntegerv`) |

## Tech stack

- **Swift** for the app, windowing and render loop
- **OpenGL 4.1 Core Profile**, the highest version macOS supports
- **Dear ImGui** (C++), called from Swift through Swift/C++ interop or a thin C wrapper
- **GLFW** or **AppKit + NSOpenGLView** for the window and GL context

> Note: Apple deprecated OpenGL in macOS 10.14. It still works and is fine for
> learning, but it is capped at 4.1, so newer features such as compute shaders
> and debug output (4.3+) are not available on macOS.

## Requirements

- macOS with Xcode 15 or later (Swift 5.9+ for C++ interop)
- Dear ImGui source (planned as a git submodule or Swift package)

## Getting started

```bash
git clone git@github.com:Hanam824/renderLab.git
cd renderLab
```

Build and run instructions will be added once the project skeleton is in place.

## Roadmap

- [ ] Project skeleton: window, GL 4.1 core context, render loop
- [ ] Integrate Dear ImGui with the OpenGL3 backend
- [ ] Draw a basic scene (triangle, then a textured cube)
- [ ] Add a panel for each feature area in the table above
- [ ] GL info and limits panel
- [ ] Shader hot-reload

## License

TBD
