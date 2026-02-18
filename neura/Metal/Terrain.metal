#include <metal_stdlib>
using namespace metal;

// Forward declarations from Utilities.metal
float ss(float a, float b, float x);
float hash1(float2 p);
float windSway(float x, float t, float ws, float wstr);

// ─── Hill shape ───────────────────────────────────────────────────────────────

float hillHeight(float x, float layer) {
    float f1 = 1.8 + layer * 0.4;
    float f2 = 3.7 + layer * 0.9;
    float f3 = 6.1 + layer * 1.3;
    float p1 = layer * 1.57;
    float p2 = layer * 2.94;
    float p3 = layer * 4.11;
    return sin(x * f1 + p1) * 0.09
         + sin(x * f2 + p2) * 0.05
         + sin(x * f3 + p3) * 0.03;
}

// ─── Hills ────────────────────────────────────────────────────────────────────

float3 renderHills(float2 uv, float3 col) {
    const float  baseH[4]    = {0.44, 0.36, 0.27, 0.18};
    const float3 hillTop[4]  = {
        float3(0.55, 0.95, 0.60),
        float3(0.35, 0.90, 0.40),
        float3(0.20, 0.82, 0.28),
        float3(0.10, 0.75, 0.22)
    };
    const float3 hillBot[4]  = {
        float3(0.42, 0.82, 0.48),
        float3(0.28, 0.76, 0.35),
        float3(0.16, 0.70, 0.25),
        float3(0.10, 0.65, 0.20)
    };

    for (int layer = 0; layer < 4; layer++) {
        float h = baseH[layer] + hillHeight(uv.x, float(layer));
        if (uv.y < h) {
            float shade = ss(0.0, 0.95, uv.y / max(h, 0.05));
            float3 hcol = mix(hillBot[layer], hillTop[layer], shade);
            float rim   = ss(h - 0.015, h, uv.y) * ss(h, h - 0.003, uv.y);
            hcol = mix(hcol, float3(0.85, 1.00, 0.70), rim * 0.6);
            col  = hcol;
        }
    }
    return col;
}

// ─── Grass ────────────────────────────────────────────────────────────────────

float3 renderGrass(float2 uv, float time, float3 col,
                   float windSpeed, float windStrength) {
    const float baseH   = 0.18;
    const int   gridW   = 70;
    const float spacing = 1.0 / float(gridW);

    for (int i = 0; i < gridW; i++) {
        float cx = (float(i) + 0.5) * spacing;
        if (abs(uv.x - cx) > spacing * 2.5) continue;

        float h = baseH + hillHeight(cx, 3.0);
        if (uv.y < h - 0.03 || uv.y > h + 0.07) continue;

        float r       = hash1(float2(float(i), 0.33));
        float xOff    = (r - 0.5) * spacing * 0.7;
        float groundX = cx + xOff;
        float groundY = h;
        float sway    = windSway(groundX, time, windSpeed, windStrength);
        float tH      = 0.030 + r * 0.020;

        for (int b = -1; b <= 1; b++) {
            float2 base = float2(groundX + float(b) * 0.002, groundY);
            float2 tip  = base + float2(float(b) * 0.004 + sway * tH, tH);
            float2 pv   = uv - base;
            float2 dv   = tip - base;
            float  t2   = clamp(dot(pv, dv) / dot(dv, dv), 0.0, 1.0);
            float  dist = length(pv - dv * t2);
            float  blade = 1.0 - ss(0.0, 0.0025, dist);
            float3 grassCol = mix(float3(0.08, 0.60, 0.12),
                                  float3(0.55, 0.95, 0.25), t2);
            col = mix(col, grassCol, blade * 0.9);
        }
    }
    return col;
}
