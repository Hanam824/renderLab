// Compiles the macOS and OpenGL3 ImGui backends and implements the rl_* shim.
// The Metal backend is in the separate ImGuiMetal target, which is built with ARC.
#import <AppKit/AppKit.h>

// Third-party code: don't report its warnings as ours.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability-completeness"
#include "backends/imgui_impl_osx.mm"
#include "backends/imgui_impl_opengl3.cpp"
#pragma clang diagnostic pop

#include "imgui_internal.h"
#include "include/RenderLabImGui.h"

void rl_imgui_create(void) {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGui::GetIO().IniFilename = nullptr; // don't write imgui.ini into the working directory
    ImGui::StyleColorsDark();
}

void rl_imgui_destroy(void) { ImGui::DestroyContext(); }

void rl_imgui_begin_frame(void) { ImGui::NewFrame(); }
void rl_imgui_end_frame(void) { ImGui::Render(); }

float rl_imgui_window_fit_width(void) {
    // Same sum as ImGui's auto-fit, minus the constraints. ContentSizeIdeal is measured from the
    // previous frame's widgets; in AlwaysAutoResize windows it doesn't depend on the window width.
    ImGuiWindow* window = ImGui::GetCurrentWindow();
    return window->ContentSizeIdeal.x + window->WindowPadding.x * 2.0f
        + window->DecoOuterSizeX1 + window->DecoOuterSizeX2 - window->ScrollbarSizes.x;
}

bool rl_osx_init(void* nsview) { return ImGui_ImplOSX_Init((__bridge NSView*)nsview); }
void rl_osx_new_frame(void* nsview) { ImGui_ImplOSX_NewFrame((__bridge NSView*)nsview); }
void rl_osx_shutdown(void) { ImGui_ImplOSX_Shutdown(); }

bool rl_gl3_init(void) { return ImGui_ImplOpenGL3_Init("#version 410"); }
void rl_gl3_new_frame(void) { ImGui_ImplOpenGL3_NewFrame(); }
void rl_gl3_render_draw_data(void) { ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData()); }
void rl_gl3_shutdown(void) { ImGui_ImplOpenGL3_Shutdown(); }

