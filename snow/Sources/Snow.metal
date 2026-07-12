#include <metal_stdlib>
using namespace metal;

// ---------- helpers ----------

static float2 rot(float2 p, float a) {
    float c = cos(a), s = sin(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

static float hash21(float2 p) {
    p = fract(p * float2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

static float2 hash22(float2 p) {
    return float2(hash21(p), hash21(p + 19.19));
}

static float vnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1));
    float d = hash21(i + float2(1, 1));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static float fbm(float2 p) {
    float v = 0.0, amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * vnoise(p);
        p = p * 2.03 + 17.1;
        amp *= 0.5;
    }
    return v;
}

// One depth slice of snow: a scrolling grid where each cell holds a drifting,
// twinkling flake. Neighbours are sampled so flakes cross cell borders cleanly.
static float snowLayer(float2 uv, float2 offset, float cells,
                       float radius, float sway, float time, float seed) {
    float2 w = (uv + offset) * cells;
    float2 id = floor(w);
    float2 gv = fract(w);
    float acc = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 o = float2(x, y);
            float2 rnd = hash22(id + o + seed);
            // flake sits at a random spot in the cell and wobbles sideways
            float2 c = o + rnd;
            c.x += sin(time * (0.6 + rnd.x * 0.9) + rnd.y * 6.2831) * sway;
            float d = length(gv - c);
            float flake = smoothstep(radius, radius * 0.15, d);
            float twinkle = 0.7 + 0.3 * sin(time * 3.0 + rnd.x * 40.0);
            acc = max(acc, flake * (0.55 + 0.45 * rnd.y) * twinkle);
        }
    }
    return acc;
}

// ---------- the effect ----------
//
// SwiftUI colorEffect entry point. A winter night: a moon hangs in a cold
// sky while parallax layers of snow drift down on a gusting wind and settle
// into a bank at the bottom. Touching the sky spins up a flurry of snow.

[[ stitchable ]] half4 snowfall(float2 position, half4 color, float2 size,
                                float time, float2 touch, float touchActive) {
    float mn = min(size.x, size.y);
    float2 uv = position / mn;
    float2 res = size / mn;
    float2 p = position / size;                 // 0..1 screen space

    // ---- flurry: swirl + push the snow away from a touch ----
    float2 tuv = touch / mn;
    float2 dt = uv - tuv;
    float rt = length(dt);
    float swirl = touchActive * 1.3 * exp(-rt * 3.5) * (1.0 + 0.3 * sin(time * 4.0));
    uv = tuv + rot(dt, swirl);
    uv += normalize(dt + 1e-4) * touchActive * 0.06 * exp(-rt * 4.5);

    // ---- cold night sky with a soft moon ----
    float3 col = mix(float3(0.02, 0.04, 0.10), float3(0.10, 0.14, 0.24),
                     pow(p.y, 0.7));
    float2 moon = float2(res.x * 0.72, 0.26);
    float mdist = length(uv - moon);
    col += float3(0.55, 0.62, 0.78) * exp(-mdist * 3.0) * 0.55;   // halo
    col += float3(0.95, 0.97, 1.0) * smoothstep(0.10, 0.085, mdist); // disk

    // ---- gusting wind shared by every layer ----
    float gust = fbm(float2(time * 0.12, 4.0));
    float swayAmt = 0.10 + 0.35 * gust;
    float3 snowCol = float3(0.92, 0.96, 1.0);

    // ---- five parallax layers, far (sharp/slow) to near (big/soft/fast) ----
    const int LAYERS = 5;
    for (int i = 0; i < LAYERS; i++) {
        float f = float(i) / float(LAYERS - 1);
        float cells  = mix(26.0, 8.0,  f);
        float radius = mix(0.05, 0.15, f);
        float fall   = mix(0.10, 0.28, f);
        float drift  = 0.16 * sin(time * 0.13 + f * 2.0)
                     + 0.05 * time * (0.3 + f * 0.6);
        float2 off   = float2(drift, -fall * time);
        float sway   = swayAmt * mix(0.4, 1.2, f);
        float a = snowLayer(uv, off, cells, radius, sway, time, f * 53.1 + 7.0);
        col = mix(col, snowCol, a * mix(0.55, 1.0, f));
    }

    // ---- snow bank at the bottom ----
    float bankTop = 0.86 + 0.02 * vnoise(float2(uv.x * 3.0, 1.0)) - 0.02;
    float bank = smoothstep(bankTop - 0.015, bankTop + 0.03, p.y);
    float3 bankCol = mix(float3(0.62, 0.70, 0.86), float3(0.90, 0.94, 1.0),
                         smoothstep(0.0, 0.12, p.y - bankTop));
    bankCol += hash21(position) * 0.05;                 // crystalline sparkle
    col = mix(col, bankCol, bank);

    // ---- snow kicked up under the finger ----
    float kick = touchActive * exp(-rt * 5.0)
               * (0.35 + 0.5 * fbm(uv * 8.0 + time * 2.0));
    col = mix(col, snowCol, kick * 0.6);

    // ---- grain, vignette, cool tonemap ----
    col += (hash21(position + fract(time) * 100.0) - 0.5) * 0.025;
    float2 sv = p - 0.5;
    col *= 1.0 - 0.45 * dot(sv, sv);
    col = 1.0 - exp(-col * 1.9);

    return half4(half3(col), 1.0);
}
