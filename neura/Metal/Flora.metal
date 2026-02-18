#include <metal_stdlib>
using namespace metal;

// Forward declarations from Utilities.metal
float ss(float a, float b, float x);
float hash1(float2 p);
float sdCircle(float2 p, float r);
float windSway(float x, float t, float ws, float wstr);

// Forward declaration from Terrain.metal
float hillHeight(float x, float layer);

// ─── Petal colours ────────────────────────────────────────────────────────────

float3 flowerPetalColor(int variant) {
    const float3 colors[8] = {
        float3(1.00, 0.25, 0.60),  // hot pink
        float3(1.00, 0.88, 0.00),  // bright yellow
        float3(0.72, 0.20, 1.00),  // vivid purple
        float3(0.10, 0.70, 1.00),  // sky blue
        float3(1.00, 0.45, 0.10),  // vibrant orange
        float3(0.95, 0.40, 0.85),  // magenta
        float3(0.30, 1.00, 0.60),  // spring green
        float3(1.00, 0.60, 0.80)   // bubblegum
    };
    return colors[variant % 8];
}

// ─── Single flower ────────────────────────────────────────────────────────────

float3 drawFlower(float2 uv, float2 root, float stemH, float petalR,
                  float sway, float3 pCol, int nPetals, float3 col) {
    float2 stemT = float2(root.x + sway * stemH * 1.8, root.y + stemH);

    // Stem — start slightly below the hill surface so it visibly emerges from ground
    // Draw from underground base to flower head
    float2 stemBase = float2(root.x, root.y - 0.008);  // buried slightly
    {
        float2 pv   = uv - stemBase;
        float2 dv   = stemT - stemBase;
        float  t2   = clamp(dot(pv, dv) / dot(dv, dv), 0.0, 1.0);
        float  dist = length(pv - dv * t2);
        // Thin, muted — blends naturally with hill without dominating
        float stemW = 0.0028 + petalR * 0.08;
        float stem  = 1.0 - ss(0.0, stemW, dist);
        // Muted olive-green, not saturated
        float3 stemCol = mix(float3(0.18, 0.40, 0.14), float3(0.28, 0.55, 0.18), t2);
        col = mix(col, stemCol, stem * 0.80);
    }

    // Petals
    float pDist  = petalR * 1.75;
    float pAngle = sway * 5.0;
    for (int p = 0; p < nPetals; p++) {
        float  angle   = (float(p) / float(nPetals)) * 6.2832 + pAngle;
        float2 pc      = stemT + float2(cos(angle), sin(angle)) * pDist;
        float  d       = sdCircle(uv - pc, petalR);
        float  petal   = 1.0 - ss(-0.002, 0.003, d);
        float  shimmer = 1.0 - ss(0.0, petalR * 0.5, length(uv - pc));
        col = mix(col, mix(pCol, float3(1.0), shimmer * 0.40), petal);
    }

    // Center disc
    int    variant   = nPetals % 2;
    float3 centerCol = (variant == 0) ? float3(1.00, 0.92, 0.10)
                                      : float3(1.00, 0.40, 0.20);
    float dc    = sdCircle(uv - stemT, petalR * 0.80);
    col = mix(col, centerCol, 1.0 - ss(-0.001, 0.002, dc));
    float spark = 1.0 - ss(0.0, petalR * 0.30, length(uv - stemT));
    col = mix(col, float3(1.0), spark * 0.65);

    return col;
}

// ─── Flowers across all hill layers ──────────────────────────────────────────

float3 renderFlowers(float2 uv, float time, float3 col,
                     float windSpeed, float windStrength) {
    const float baseH[4]         = {0.44, 0.36, 0.27, 0.18};
    const int   countPerLayer[4] = {4, 6, 8, 10};   // 28 total — spacious
    const float sizeScale[4]     = {0.55, 0.70, 0.85, 1.00};
    int seed = 0;

    for (int layer = 0; layer < 4; layer++) {
        int   cnt = countPerLayer[layer];
        float sc  = sizeScale[layer];
        for (int i = 0; i < cnt; i++) {
            float fi = float(seed);
            float r1 = hash1(float2(fi, 1.77));
            float r2 = hash1(float2(fi, 2.31));
            float r3 = hash1(float2(fi, 3.59));
            float r4 = hash1(float2(fi, 5.13));
            seed++;

            float cx = (float(i) + 0.5 + (r1 - 0.5) * 0.6) / float(cnt);
            float h  = baseH[layer] + hillHeight(cx, float(layer));

            float stemH  = (0.025 + r2 * 0.020) * sc;
            float petalR = (0.010 + r4 * 0.005) * sc;
            float cullR  = petalR * 3.5 + stemH;

            if (abs(uv.x - cx) > cullR * 2.5) continue;
            if (uv.y < h - 0.012 || uv.y > h + stemH + petalR * 2.5) continue;

            float  sway    = windSway(cx, time, windSpeed, windStrength) * sc;
            int    variant = int(r3 * 8.0) % 8;
            float3 pCol    = flowerPetalColor(variant);
            int    nPetals = 5 + (variant % 3);

            col = drawFlower(uv, float2(cx, h), stemH, petalR,
                             sway, pCol, nPetals, col);
        }
    }
    return col;
}
