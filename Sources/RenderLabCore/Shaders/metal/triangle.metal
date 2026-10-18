// Metal Shading Language (C++14-based). Compiled at runtime by MetalRenderer
// (device.makeLibrary(source:)), so no `metal` command-line tool is needed.
#include <metal_stdlib>
using namespace metal;

// Matches the MTLVertexDescriptor in MetalRenderer: attribute(n) is like GLSL's layout(location = n).
struct VertexIn {
    float3 position [[attribute(0)]];
    float3 color    [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]]; // clip-space position, like gl_Position
    float3 color;                 // interpolated across the triangle, like a GLSL `out`
};

// Metal clip space has Y up like OpenGL, so positions pass straight through.
vertex VertexOut triangle_vertex(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 1.0);
    out.color = in.color;
    return out;
}

fragment float4 triangle_fragment(VertexOut in [[stage_in]]) {
    return float4(in.color, 1.0);
}
