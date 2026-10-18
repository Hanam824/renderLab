// rl_metal_* shim for the Dear ImGui Metal renderer backend (imgui_impl_metal).
//
// Metal objects are passed as opaque pointers so this header stays plain C:
// id<MTLDevice>, MTLRenderPassDescriptor*, id<MTLCommandBuffer>, id<MTLRenderCommandEncoder>.
#pragma once

#include <stdbool.h>

bool rl_metal_init(void* device);
void rl_metal_new_frame(void* pass_descriptor);
void rl_metal_render_draw_data(void* command_buffer, void* encoder);
void rl_metal_shutdown(void);
