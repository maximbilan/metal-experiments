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
    for (int i = 0; i < 5; i++) {
        v += amp * vnoise(p);
        p = rot(p, 0.6) * 2.03;
        amp *= 0.5;
    }
    return v;
}

// iq cosine palette, tuned neon
static float3 palette(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (t + float3(0.263, 0.416, 0.557)));
}

// ---------- the effect ----------
//
// SwiftUI colorEffect entry point. Everything is procedural:
// a gravitational vortex warps a domain-warped fbm nebula,
// with per-channel chromatic splitting and an event-horizon rim.

[[ stitchable ]] half4 singularity(float2 position, half4 color, float2 size,
                                   float time, float2 touch, float touchActive) {
    float mn = min(size.x, size.y);
    float2 uv = (position - 0.5 * size) / mn;
    float2 c  = (touch    - 0.5 * size) / mn;

    // idle drift when the finger is up, so it never sits still
    c += (1.0 - touchActive) * 0.08 * float2(sin(time * 0.7), cos(time * 0.9));

    float2 d = uv - c;
    float r = length(d);

    // gravitational swirl: tighter radius = faster rotation
    float swirl = 0.35 / (r + 0.08) + 0.6 * touchActive / (r + 0.05);
    float2 p = c + rot(d, swirl - time * 0.4);

    // domain-warped fbm (warp the warp)
    float2 q = float2(fbm(p * 3.0 + time * 0.15),
                      fbm(p * 3.0 + float2(5.2, 1.3) - time * 0.10));
    float2 w = float2(fbm(p * 3.0 + 4.0 * q + float2(1.7, 9.2) + time * 0.2),
                      fbm(p * 3.0 + 4.0 * q + float2(8.3, 2.8)));
    float f = fbm(p * 3.0 + 4.0 * w);

    // chromatic split, stronger while touching
    float split = (0.05 + 0.20 * touchActive) * r;
    float hue = f * 1.2 + r * 1.4 - time * 0.07;
    float3 col;
    col.r = palette(hue + split).r;
    col.g = palette(hue).g;
    col.b = palette(hue - split).b;

    // brightness shaping: hot filaments, dim voids
    float glow = f * f * f + 0.4 * f * f + 0.15 * f;
    col *= 1.6 * glow + 0.05;

    // event horizon: dark core with a pulsing hot rim
    float core = smoothstep(0.02, 0.16, r);
    float rim  = exp(-pow((r - 0.16) * 22.0, 2.0)) * (0.7 + 0.6 * touchActive);
    col = col * core
        + rim * float3(0.85, 0.95, 1.2) * (0.7 + 0.3 * sin(time * 2.0 + f * 12.0));

    // filmic-ish tonemap + vignette
    col = 1.0 - exp(-col * 1.7);
    float2 sv = position / size - 0.5;
    col *= 1.0 - 0.85 * dot(sv, sv);

    return half4(half3(col), 1.0);
}
