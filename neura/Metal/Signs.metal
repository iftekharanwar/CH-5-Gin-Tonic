#include <metal_stdlib>
using namespace metal;

// Forward declarations from Utilities.metal
float ss(float a, float b, float x);

// Forward declaration from Terrain.metal
float hillHeight(float x, float layer);

// ─── Rounded rectangle SDF ───────────────────────────────────────────────────

float sdRoundedRect(float2 p, float2 halfSize, float radius) {
    float2 q = abs(p) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// ─── Single waymarker sign ────────────────────────────────────────────────────
// cx, groundY  — base position on hill surface (UV space)
// tilt         — slight rotation angle for character (radians)

float3 drawSign(float2 uv, float cx, float groundY, float tilt, float3 col) {

    // ── Post ─────────────────────────────────────────────────────────
    float postW  = 0.016;
    float postH  = 0.24;
    float2 postCenter = float2(cx, groundY + postH * 0.45);

    // Rotate uv into post local space
    float2 pp = uv - postCenter;
    float  ct = cos(-tilt), st = sin(-tilt);
    float2 ppR = float2(pp.x * ct - pp.y * st, pp.x * st + pp.y * ct);

    float postD = sdRoundedRect(ppR, float2(postW * 0.5, postH * 0.5), 0.004);
    float postM = 1.0 - ss(-0.001, 0.002, postD);

    // Wood grain lines on post
    float grain = 0.0;
    for (int g = 0; g < 6; g++) {
        float gy = -0.09 + float(g) * 0.036;
        grain += (1.0 - ss(0.0, 0.002, abs(ppR.y - gy))) * 0.18;
    }
    float3 postWood = float3(0.62, 0.38, 0.18);
    float3 postDark = float3(0.48, 0.28, 0.12);
    float3 postCol  = mix(postWood, postDark, grain);

    // Post shadow edge (left side slightly darker)
    float shadow = ss(-postW * 0.5, -postW * 0.1, ppR.x) * 0.25;
    postCol = mix(postCol, postDark, shadow);
    col = mix(col, postCol, postM);

    // Post outline
    float postEdge = ss(-0.004, -0.001, postD) * (1.0 - ss(-0.001, 0.002, postD));
    col = mix(col, float3(0.28, 0.15, 0.05), postEdge * 0.7);

    // ── Plank ────────────────────────────────────────────────────────
    float plankW   = 0.26;
    float plankH   = 0.09;
    float plankTilt = tilt * 1.2;   // plank tilts a bit more than post
    float2 plankCenter = float2(cx + tilt * 0.02,
                                groundY + postH * 0.88);

    float2 pk = uv - plankCenter;
    float  cp = cos(-plankTilt), sp = sin(-plankTilt);
    float2 pkR = float2(pk.x * cp - pk.y * sp, pk.x * sp + pk.y * cp);

    float plankD = sdRoundedRect(pkR, float2(plankW * 0.5, plankH * 0.5), 0.012);
    float plankM = 1.0 - ss(-0.001, 0.002, plankD);

    // Plank wood colour — lighter, more honey-toned
    float3 plankWood   = float3(0.82, 0.58, 0.28);
    float3 plankLight  = float3(0.92, 0.72, 0.42);
    float3 plankShadow = float3(0.65, 0.44, 0.20);

    // Horizontal grain lines
    float pg = 0.0;
    for (int g = 0; g < 5; g++) {
        float gy = -0.032 + float(g) * 0.016;
        pg += (1.0 - ss(0.0, 0.002, abs(pkR.y - gy))) * 0.18;
    }
    // Top-to-bottom shading
    float plankShade = ss(-plankH * 0.5, plankH * 0.5, pkR.y);
    float3 plankCol  = mix(plankShadow, plankLight, plankShade);
    plankCol = mix(plankCol, plankShadow, pg);

    col = mix(col, plankCol, plankM);

    // Plank outline — dark brown border
    float plankEdge = ss(-0.005, -0.001, plankD) * (1.0 - ss(-0.001, 0.002, plankD));
    col = mix(col, float3(0.25, 0.13, 0.04), plankEdge * 0.85);

    // Nail dots — two small circles at plank ends where it meets post
    float2 nail1 = plankCenter + float2(-plankW * 0.35, 0.0);
    float2 nail2 = plankCenter + float2( plankW * 0.35, 0.0);
    float nailR  = 0.004;
    float n1 = 1.0 - ss(-0.001, 0.002, sdRoundedRect(uv - nail1,
                         float2(nailR), nailR * 0.5));
    float n2 = 1.0 - ss(-0.001, 0.002, sdRoundedRect(uv - nail2,
                         float2(nailR), nailR * 0.5));
    col = mix(col, float3(0.30, 0.20, 0.10), n1 * plankM);
    col = mix(col, float3(0.30, 0.20, 0.10), n2 * plankM);

    return col;
}

// ─── Two waymarker signs ──────────────────────────────────────────────────────

float3 renderSigns(float2 uv, float3 col) {
    // Sign 1 — "Learn Words" — planted on foreground hill (layer 3)
    float cx1 = 0.28;
    float h1  = 0.18 + hillHeight(cx1, 3.0);
    col = drawSign(uv, cx1, h1, -0.04, col);

    // Sign 2 — "Let's Draw" — groundY fixed to match sign 1's plank height
    // The post embeds into the hill naturally (signs are planted into the ground)
    float cx2 = 0.72;
    float h2  = h1;
    col = drawSign(uv, cx2, h2, 0.05, col);

    return col;
}
