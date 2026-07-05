#include <metal_stdlib>
using namespace metal;

// ---------- helpers ----------

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
    for (int i = 0; i < 4; i++) {
        v += amp * vnoise(p);
        p = p * 2.03 + 17.1;
        amp *= 0.5;
    }
    return v;
}

// classic iterative sunlight caustics
static float caustic(float2 uv, float time) {
    float2 p = fmod(uv * 6.28318, 6.28318) - 250.0;
    float2 i = p;
    float c = 1.0;
    float inten = 0.005;
    for (int n = 0; n < 5; n++) {
        float t = time * (1.0 - (3.5 / float(n + 1)));
        i = p + float2(cos(t - i.x) + sin(t + i.y),
                       sin(t - i.y) + cos(t + i.x));
        c += 1.0 / length(float2(p.x / (sin(i.x + t) / inten),
                                 p.y / (cos(i.y + t) / inten)));
    }
    c /= 5.0;
    c = 1.17 - pow(c, 1.4);
    return pow(abs(c), 8.0);
}

// ---------- the effect ----------
//
// SwiftUI colorEffect entry point. A sunlit pool from above:
// ambient waves refract a tile floor, two layers of caustics dance
// on top, raindrops ring the surface, and touching it sends ripples
// out from your finger.

[[ stitchable ]] half4 water(float2 position, half4 color, float2 size,
                             float time, float2 touch, float touchActive) {
    float mn = min(size.x, size.y);
    float2 uv = position / mn;
    float2 ext = size / mn;
    float glint = 0.0;

    // touch ripples: expanding rings that displace the surface
    {
        float2 d = uv - touch / mn;
        float r = length(d);
        float ring = sin(80.0 * r - time * 12.0) * exp(-r * 5.0);
        float amp = 0.2 + 0.8 * touchActive;
        uv += (d / (r + 1e-3)) * ring * 0.014 * amp;
        glint += abs(ring) * touchActive * 0.5;
    }

    // ambient raindrops: expanding wavefronts at random spots
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        float cycle = floor(time / 2.4 + fk * 0.37);
        float age   = fract(time / 2.4 + fk * 0.37);
        float2 dp = float2(hash21(float2(cycle, fk * 13.7)),
                           hash21(float2(fk * 7.3, cycle + 4.1))) * ext;
        float2 d = uv - dp;
        float rd = length(d);
        float front = age * 0.7;
        float w = sin((rd - front) * 70.0)
                * exp(-pow((rd - front) * 9.0, 2.0))
                * (1.0 - age);
        uv += (d / (rd + 1e-3)) * w * 0.02;
        glint += abs(w) * 0.35;
    }

    // ambient waves refract everything below the surface
    float2 wave = float2(fbm(uv * 3.0 + float2(0.0, time * 0.40)),
                         fbm(uv * 3.0 + float2(5.2, -time * 0.35)));
    float2 ruv = uv + (wave - 0.5) * 0.10;

    // pool tile floor, with per-tile shade variation
    float2 g = fract(ruv * 5.0);
    float2 lw = smoothstep(0.0, 0.06, g) * (1.0 - smoothstep(0.94, 1.0, g));
    float tile = lw.x * lw.y;
    float shade = 0.88 + 0.24 * hash21(floor(ruv * 5.0));
    float3 col = mix(float3(0.10, 0.35, 0.45),
                     float3(0.45, 0.80, 0.88) * shade, tile);

    // swim-lane marking: dark tile stripe down the middle of the floor
    float lx = abs(ruv.x - ext.x * 0.5);
    float lane = 1.0 - smoothstep(0.055, 0.075, lx);
    float3 laneCol = mix(float3(0.02, 0.09, 0.22),
                         float3(0.07, 0.16, 0.34) * shade, tile);
    col = mix(col, laneCol, lane);

    // deeper water is darker and bluer; the top catches warm sun
    float depth = position.y / size.y;
    col = mix(col, float3(0.02, 0.16, 0.32), depth * 0.65);
    col += float3(0.05, 0.045, 0.02) * (1.0 - depth);

    // two layers of sunlight caustics: broad + fine sparkle
    float ca = 0.85 * caustic(ruv * 0.8, time * 0.6)
             + 0.45 * caustic(ruv * 1.9 + 3.0, time * 0.8);
    col += ca * float3(0.60, 0.95, 0.85);

    // glints along ripple and raindrop crests
    col += float3(0.85, 1.0, 1.0) * glint;

    // vignette + soft tonemap
    float2 sv = position / size - 0.5;
    col *= 1.0 - 0.45 * dot(sv, sv);
    col = 1.0 - exp(-col * 2.0);

    return half4(half3(col), 1.0);
}
