#include <metal_stdlib>
using namespace metal;

// ─── Hash / Noise ─────────────────────────────────────────────────────────────

float hash1(float2 p) {
    p = fract(p * float2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

// ─── SDF Primitives ───────────────────────────────────────────────────────────

float sdCircle(float2 p, float r) {
    return length(p) - r;
}

float sdSmoothUnion(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

// ─── Smoothstep alias ─────────────────────────────────────────────────────────

float ss(float a, float b, float x) {
    return smoothstep(a, b, x);
}

// ─── Wind ─────────────────────────────────────────────────────────────────────

float windSway(float x, float t, float ws, float wstr) {
    return wstr * (
        sin(x * 3.7  + t * ws)            +
        sin(x * 7.3  + t * ws * 1.3) * 0.4 +
        sin(x * 13.1 + t * ws * 0.7) * 0.2
    );
}
