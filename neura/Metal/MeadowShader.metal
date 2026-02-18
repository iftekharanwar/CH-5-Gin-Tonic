#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.h"

// ─── Forward declarations ─────────────────────────────────────────────────────
// Each function is defined in its own .metal file.
// Metal compiles all .metal files in the target into one library,
// so these are resolved automatically at link time.

// Sky.metal
float3 renderSky(float2 uv, float time);

// Clouds.metal
float3 renderClouds(float2 uv, float time, float3 sky);

// Terrain.metal
float3 renderHills(float2 uv, float3 col);
float3 renderGrass(float2 uv, float time, float3 col,
                   float windSpeed, float windStrength);

// Flora.metal
float3 renderFlowers(float2 uv, float time, float3 col,
                     float windSpeed, float windStrength);

// Fauna.metal
float3 renderButterflies(float2 uv, float time, float3 col);

// Signs.metal
float3 renderSigns(float2 uv, float3 col);

// ─── Vertex Shader ────────────────────────────────────────────────────────────

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut meadowVertex(uint vertexID [[vertex_id]]) {
    const float2 positions[3] = {
        float2(-1.0, -3.0),
        float2( 3.0,  1.0),
        float2(-1.0,  1.0)
    };
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv       = positions[vertexID] * 0.5 + 0.5;
    return out;
}

// ─── Fragment Shader ──────────────────────────────────────────────────────────

fragment float4 meadowFragment(VertexOut in [[stage_in]],
                                constant MeadowUniforms &u [[buffer(0)]])
{
    float2 uv = in.uv;  // y=1 top, y=0 bottom

    float3 col = renderSky(uv, u.time);
    col = renderClouds(uv, u.time, col);
    col = renderHills(uv, col);
    col = renderGrass(uv, u.time, col, u.windSpeed, u.windStrength);
    col = renderFlowers(uv, u.time, col, u.windSpeed, u.windStrength);
    col = renderButterflies(uv, u.time, col);
    col = renderSigns(uv, col);

    // Gentle vignette
    float2 vc   = uv - 0.5;
    float  vign = 1.0 - dot(vc, vc) * 0.35;
    col *= vign;

    // Gamma lift + clamp
    col = pow(col, float3(0.88));
    col = clamp(col, 0.0, 1.0);

    return float4(col, 1.0);
}
