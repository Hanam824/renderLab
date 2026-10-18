# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project status

The repo has no source code yet, only `README.md` and `.gitignore`. There are no build, lint or test commands. Add them here once the project skeleton exists.

## Purpose

renderLab is a learning playground for **Swift** and **OpenGL**. Dear ImGui provides live UI controls (checkboxes, sliders, combo boxes) that toggle OpenGL state and features at runtime, so the effect of each flag is visible right away. The feature areas to cover and the roadmap are in `README.md`.

The user is learning both Swift and OpenGL. Favor clear, explanatory code over clever abstractions. A short comment saying what a GL call does is welcome here.

## Technical constraints

- **macOS only, OpenGL 4.1 Core Profile max.** Apple deprecated OpenGL in 10.14 and caps it at 4.1. Don't use 4.3+ features (compute shaders, `glDebugMessageCallback`, SSBOs). Write GLSL as `#version 410 core`. Expect deprecation warnings; silence them with `GL_SILENCE_DEPRECATION` rather than treating them as errors.
- **Dear ImGui is C++.** It is called from Swift through Swift/C++ interop (Swift 5.9+, Xcode 15+) or a thin C wrapper. Use the `imgui_impl_opengl3` renderer backend.
- **Not decided yet:** GLFW or AppKit/`NSOpenGLView` for the window and GL context, and whether ImGui is vendored as a git submodule or a Swift package. Ask the user before picking.
- Commit `Package.resolved`. It is deliberately not in `.gitignore`.

## Repo

- Remote: `git@github.com:Hanam824/renderLab.git` (SSH). As of the initial commit, this repository had not been created on GitHub yet.
- Default branch: `main`.
