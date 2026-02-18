#include <metal_stdlib>
using namespace metal;

// Forward declarations from Utilities.metal
float ss(float a, float b, float x);
float sdCircle(float2 p, float r);
float sdSmoothUnion(float d1, float d2, float k);

// ─── Cloud SDF ────────────────────────────────────────────────────────────────

float cloudSDF(float2 uv, float2 center, float scale) {
    float2 p = (uv - center) / scale;
    float d = sdCircle(p, 0.28);
    d = sdSmoothUnion(d, sdCircle(p - float2( 0.26,  0.04), 0.22), 0.14);
    d = sdSmoothUnion(d, sdCircle(p - float2(-0.26,  0.03), 0.20), 0.14);
    d = sdSmoothUnion(d, sdCircle(p - float2( 0.12,  0.18), 0.19), 0.12);
    d = sdSmoothUnion(d, sdCircle(p - float2(-0.12,  0.16), 0.18), 0.12);
    d = sdSmoothUnion(d, sdCircle(p - float2( 0.00,  0.24), 0.16), 0.10);
    return d * scale;
}

// ─── Clouds ───────────────────────────────────────────────────────────────────

float3 renderClouds(float2 uv, float time, float3 sky) {
    const float baseX[7]  = {0.08, 0.38, 0.68, 0.22, 0.54, 0.82, 0.46};
    const float speed[7]  = {0.011, 0.007, 0.014, 0.009, 0.006, 0.012, 0.008};
    const float scale[7]  = {0.09, 0.13, 0.08, 0.11, 0.10, 0.07, 0.12};
    const float height[7] = {0.78, 0.84, 0.74, 0.71, 0.80, 0.76, 0.68};

    float3 col = sky;
    for (int i = 0; i < 7; i++) {
        float  cx     = fract(baseX[i] - time * speed[i]);
        float2 center = float2(cx, height[i]);
        float  d      = cloudSDF(uv, center, scale[i]);
        float  alpha  = 1.0 - ss(-0.001, 0.008, d);
        col = mix(col, float3(1.0, 1.0, 1.0), alpha);
    }
    return col;
}
