// Compiles the Metal ImGui backend and implements the rl_metal_* shim.
// This target is built with ARC (-fobjc-arc): imgui_impl_metal.mm relies on ARC to free the objects
// it allocates every frame. It lives apart from CImGui, which is built without ARC.
#import <Metal/Metal.h>

// Third-party code: don't report its warnings as ours.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullability-completeness"
#include "backends/imgui_impl_metal.mm"
#pragma clang diagnostic pop

#include "include/RenderLabImGuiMetal.h"

// The Metal objects arrive from Swift as unretained opaque pointers; __bridge casts don't change ownership.
bool rl_metal_init(void* device) { return ImGui_ImplMetal_Init((__bridge id<MTLDevice>)device); }

void rl_metal_new_frame(void* pass_descriptor) {
    ImGui_ImplMetal_NewFrame((__bridge MTLRenderPassDescriptor*)pass_descriptor);
}

void rl_metal_render_draw_data(void* command_buffer, void* encoder) {
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), (__bridge id<MTLCommandBuffer>)command_buffer,
                                   (__bridge id<MTLRenderCommandEncoder>)encoder);
}

void rl_metal_shutdown(void) { ImGui_ImplMetal_Shutdown(); }
