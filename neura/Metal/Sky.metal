#include <metal_stdlib>
using namespace metal;

// Forward declarations from Utilities.metal
float ss(float a, float b, float x);

// ─── Sky gradient + sun ───────────────────────────────────────────────────────

float3 renderSky(float2 uv, float time) {
    float3 top   = float3(0.18, 0.62, 1.00);  // bright cobalt
    float3 mid   = float3(0.40, 0.85, 1.00);  // baby blue
    float3 horiz = float3(0.98, 0.94, 0.60);  // warm lemon at horizon

    float t  = uv.y;
    float3 sky = mix(horiz, mid, ss(0.0, 0.35, t));
    sky = mix(sky, top, ss(0.35, 1.0, t));

    // Big happy sun — upper left
    float2 sunPos  = float2(0.22, 0.80);
    float  sunDist = length(uv - sunPos);

    float pulse  = 1.0 + 0.04 * sin(time * 1.8);
    float corona = exp(-sunDist * 3.5 * pulse) * 0.9;
    sky += float3(1.00, 0.95, 0.30) * corona;

    float halo = exp(-sunDist * 8.0) * 0.5;
    sky += float3(1.00, 0.80, 0.10) * halo;

    float disc  = 1.0 - ss(0.045, 0.055, sunDist);
    sky = mix(sky, float3(1.00, 0.98, 0.70), disc);

    float spark = 1.0 - ss(0.008, 0.013, sunDist);
    sky = mix(sky, float3(1.00, 1.00, 1.00), spark);

    return sky;
}

