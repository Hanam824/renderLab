// Umbrella header for the CImGui module.
//
// Swift sees the full Dear ImGui C++ API (namespace ImGui) through C++ interop,
// plus a small rl_* shim for the backends whose headers use Objective-C types
// or default arguments that are awkward to call from Swift.
#pragma once

#include "../../../ThirdParty/imgui/imgui.h"

// Context lifetime. Creates the ImGui context with the dark style and disables imgui.ini.
void rl_imgui_create(void);
void rl_imgui_destroy(void);

// Per-frame bracket around widget code: ImGui::NewFrame() ... ImGui::Render().
void rl_imgui_begin_frame(void);
void rl_imgui_end_frame(void);

// Width the current window (call between Begin and End) would auto-fit to with no size
// constraints: its widest content plus padding and borders. Uses ImGui internals.
float rl_imgui_window_fit_width(void);

// macOS platform backend (imgui_impl_osx). `nsview` is an NSView* passed as an opaque pointer.
bool rl_osx_init(void* nsview);
void rl_osx_new_frame(void* nsview);
void rl_osx_shutdown(void);

// OpenGL 3 renderer backend (imgui_impl_opengl3), set up for GLSL "#version 410".
bool rl_gl3_init(void);
void rl_gl3_new_frame(void);
void rl_gl3_render_draw_data(void);
void rl_gl3_shutdown(void);

