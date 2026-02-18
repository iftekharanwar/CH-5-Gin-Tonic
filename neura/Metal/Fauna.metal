#include <metal_stdlib>
using namespace metal;

// Forward declarations from Utilities.metal
float ss(float a, float b, float x);
float sdCircle(float2 p, float r);

// ─── Single cartoon butterfly ─────────────────────────────────────────────────

float3 drawButterfly(float2 uv, float2 center, float scale,
                     float flap, float3 wingCol, float3 col) {
    float2 p      = (uv - center) / scale;
    float  spread = mix(0.5, 1.0, flap);

    for (int side = -1; side <= 1; side += 2) {
        float sx = float(side);

        // Upper wing
        float2 uwCenter = float2(sx * 0.55 * spread, 0.15);
        float2 uwP = p - uwCenter;
        uwP.x -= uwP.y * sx * 0.25 * spread;
        float uwD = length(uwP / float2(0.48 * spread, 0.38)) - 1.0;

        // Lower wing
        float2 lwCenter = float2(sx * 0.40 * spread, -0.35);
        float2 lwP = p - lwCenter;
        lwP.x -= lwP.y * sx * 0.15 * spread;
        float lwD = length(lwP / float2(0.34 * spread, 0.28)) - 1.0;

        float uwMask = 1.0 - ss(-0.02, 0.02, uwD);
        float lwMask = 1.0 - ss(-0.02, 0.02, lwD);

        // Inner shadow
        float2 uwPI = p - uwCenter * 0.65;
        uwPI.x -= uwPI.y * sx * 0.20 * spread;
        float uwInner    = length(uwPI / float2(0.30 * spread, 0.26)) - 1.0;
        float innerMaskU = (1.0 - ss(-0.01, 0.03, uwInner)) * uwMask;

        float2 lwPI = p - lwCenter * 0.65;
        lwPI.x -= lwPI.y * sx * 0.10 * spread;
        float lwInner    = length(lwPI / float2(0.20 * spread, 0.17)) - 1.0;
        float innerMaskL = (1.0 - ss(-0.01, 0.03, lwInner)) * lwMask;

        float3 wingDark = wingCol * 0.68;
        col = mix(col, wingCol,  uwMask);
        col = mix(col, wingCol,  lwMask);
        col = mix(col, wingDark, innerMaskU * 0.75);
        col = mix(col, wingDark, innerMaskL * 0.75);

        // Outlines
        float uwEdge = ss(-0.03, -0.01, uwD) * (1.0 - ss(-0.01, 0.02, uwD));
        float lwEdge = ss(-0.03, -0.01, lwD) * (1.0 - ss(-0.01, 0.02, lwD));
        col = mix(col, float3(0.15, 0.25, 0.50), uwEdge * uwMask * 0.8);
        col = mix(col, float3(0.15, 0.25, 0.50), lwEdge * lwMask * 0.8);

        // Border dots — 4 on upper wing, 3 on lower
        for (int d = 0; d < 4; d++) {
            float dt     = float(d) / 3.0;
            float ang    = mix(-0.6, 0.6, dt) + sx * 0.1;
            float2 dotPos = uwCenter + float2(cos(ang) * 0.41 * spread,
                                              sin(ang) * 0.32) * 0.90;
            float dotD = length(p - dotPos) - 0.04;
            col = mix(col, float3(1.0), (1.0 - ss(-0.005, 0.005, dotD)) * uwMask * 0.90);
        }
        for (int d = 0; d < 3; d++) {
            float dt     = float(d) / 2.0;
            float ang    = mix(-0.5, 0.5, dt);
            float2 dotPos = lwCenter + float2(cos(ang) * 0.28 * spread,
                                              sin(ang) * 0.22) * 0.90;
            float dotD = length(p - dotPos) - 0.030;
            col = mix(col, float3(1.0), (1.0 - ss(-0.004, 0.004, dotD)) * lwMask * 0.90);
        }
    }

    // Body — segmented peach/orange capsule
    float3 bodyCol    = float3(0.96, 0.72, 0.38);
    float3 bodyStripe = float3(0.92, 0.52, 0.18);
    for (int seg = 0; seg < 5; seg++) {
        float  by   = 0.18 - float(seg) * 0.12;
        float  br   = (seg == 0) ? 0.115 : 0.090;
        float  segD = sdCircle(p - float2(0.0, by), br);
        float3 sc   = (seg % 2 == 0) ? bodyCol : bodyStripe;
        col = mix(col, sc, 1.0 - ss(-0.01, 0.01, segD));
    }
    for (int seg = 0; seg < 5; seg++) {
        float by      = 0.18 - float(seg) * 0.12;
        float br      = (seg == 0) ? 0.115 : 0.090;
        float segD    = sdCircle(p - float2(0.0, by), br);
        float outline = ss(-0.025, -0.010, segD) * (1.0 - ss(-0.010, 0.005, segD));
        col = mix(col, float3(0.20, 0.12, 0.05), outline * 0.85);
    }

    // Face
    float2 headC = float2(0.0, 0.18);
    for (int e = -1; e <= 1; e += 2) {
        float2 eyeC = headC + float2(float(e) * 0.048, 0.020);
        col = mix(col, float3(1.0),
                  1.0 - ss(-0.005, 0.005, sdCircle(p - eyeC, 0.030)));
        col = mix(col, float3(0.10, 0.08, 0.08),
                  1.0 - ss(-0.003, 0.003, sdCircle(p - eyeC, 0.016)));
        float shine = 1.0 - ss(0.0, 0.008,
                               length(p - (eyeC + float2(0.008, 0.010))));
        col = mix(col, float3(1.0), shine * 0.90);
        float cheek = 1.0 - ss(0.0, 0.035,
                               length(p - (eyeC + float2(float(e)*0.018, -0.025))));
        col = mix(col, float3(0.98, 0.55, 0.45), cheek * 0.55);
    }
    // Smile arc
    for (int sm = 0; sm < 5; sm++) {
        float  st  = float(sm) / 4.0;
        float  sa  = mix(-0.5, 0.5, st);
        float2 smP = headC + float2(sin(sa) * 0.032, cos(sa) * 0.024 - 0.044);
        col = mix(col, float3(0.25, 0.10, 0.08),
                  1.0 - ss(-0.003, 0.004, length(p - smP) - 0.008));
    }
    // Nose
    float nose  = 1.0 - ss(0.0, 0.009, length(p-(headC+float2(-0.012,-0.005))));
    nose       += 1.0 - ss(0.0, 0.009, length(p-(headC+float2( 0.012,-0.005))));
    col = mix(col, float3(0.70, 0.35, 0.25), clamp(nose, 0.0, 1.0) * 0.6);

    // Antennae
    for (int a = -1; a <= 1; a += 2) {
        float ax = float(a);
        for (int s = 0; s < 10; s++) {
            float  st   = float(s) / 9.0;
            float2 antP = headC + float2(ax * (0.025 + st * 0.12),
                                         0.095 + st * 0.18);
            col = mix(col, float3(0.10, 0.08, 0.06),
                      1.0 - ss(-0.003, 0.004, length(p - antP) - 0.010));
        }
        float2 curlC = headC + float2(ax * 0.145, 0.290);
        for (int c = 0; c < 8; c++) {
            float  ct = float(c) / 7.0;
            float  ca = ct * 6.28 * 1.5;
            float  cr = 0.035 * (1.0 - ct * 0.5);
            float2 cP = curlC + float2(cos(ca) * cr, sin(ca) * cr * 0.7);
            col = mix(col, float3(0.10, 0.08, 0.06),
                      1.0 - ss(-0.003, 0.004, length(p - cP) - 0.011));
        }
    }

    return col;
}

// ─── Butterfly flock ──────────────────────────────────────────────────────────

float3 renderButterflies(float2 uv, float time, float3 col) {
    const float3 wingColors[3] = {
        float3(0.38, 0.62, 0.95),  // cornflower blue
        float3(0.95, 0.38, 0.72),  // hot pink
        float3(0.42, 0.90, 0.55)   // mint green
    };
    const float baseX[3]    = {0.15, 0.70, 0.45};
    const float baseY[3]    = {0.62, 0.55, 0.58};
    const float speed[3]    = {0.022, 0.016, 0.019};
    const float flapFreq[3] = {5.5, 6.2, 4.8};
    const float scale[3]    = {0.042, 0.034, 0.038};

    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float ph = fi * 2.39;
        float tx = time * speed[i];

        // Organic wandering path — incommensurate frequencies on both axes
        float bx = baseX[i]
                 + sin(tx * 1.00 + ph)       * 0.18
                 + sin(tx * 2.71 + ph * 1.3) * 0.07
                 + sin(tx * 5.13 + ph * 0.7) * 0.03;
        bx = fract(bx);

        float by = baseY[i]
                 + cos(tx * 1.31 + ph)       * 0.07
                 + sin(tx * 2.17 + ph * 1.7) * 0.04
                 + cos(tx * 3.89 + ph * 0.5) * 0.02;

        float sc = scale[i];
        if (abs(uv.x - bx) > sc * 3.5 || abs(uv.y - by) > sc * 2.8) continue;

        float flap = 0.5 + 0.5 * sin(time * flapFreq[i] + fi * 1.3);
        col = drawButterfly(uv, float2(bx, by), sc, flap, wingColors[i], col);
    }
    return col;
}
