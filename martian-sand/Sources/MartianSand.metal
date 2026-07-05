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
    for (int i = 0; i < 4; i++) {
        v += amp * vnoise(p);
        p = p * 2.03 + 17.1;
        amp *= 0.5;
    }
    return v;
}

// wind blows along this direction everywhere
constant float2 WIND = float2(0.943, -0.333);

// dune field heightfield: broad dunes + wind ripples whose direction
// meanders with the gusts instead of staying parallel
static float duneHeight(float2 p, float time) {
    float dunes = fbm(p * 0.55 + float2(time * 0.012, 0.0));
    float2 wperp = float2(-WIND.y, WIND.x);
    float phase = dot(p, wperp) * 22.0
                + 15.0 * fbm(p * 1.1 + time * 0.03)
                - time * 0.2;
    float ripple = pow(abs(sin(phase)), 1.3);
    return dunes * 1.6 + ripple * 0.05 * (0.3 + dunes);
}

// ---------- the effect ----------
//
// SwiftUI colorEffect entry point. A Martian dune field from above:
// low sun rakes across wind-rippled sand, dust streams along the wind,
// and touching the ground spins up a dust devil under your finger.

[[ stitchable ]] half4 martianSand(float2 position, half4 color, float2 size,
                                   float time, float2 touch, float touchActive) {
    float mn = min(size.x, size.y);
    float2 uv = position / mn;
    float2 tuv = touch / mn;

    // dust devil: swirl the ground around the finger
    float2 dt = uv - tuv;
    float rt = length(dt);
    float swirl = touchActive * (1.4 + 0.3 * sin(time * 3.0)) * exp(-rt * 3.0);
    uv = tuv + rot(dt, swirl);

    // shade the dunes with a low raking sun
    float e = 0.004;
    float h  = duneHeight(uv, time);
    float hx = duneHeight(uv + float2(e, 0.0), time);
    float hy = duneHeight(uv + float2(0.0, e), time);
    float3 n = normalize(float3(-(hx - h) / e * 0.35, -(hy - h) / e * 0.35, 1.0));
    float3 sun = normalize(float3(-0.55, -0.42, 0.45));
    float diff = pow(clamp(dot(n, sun), 0.0, 1.0), 1.5);

    // rust shadows to dusty butterscotch sand, soft glints on crests
    float3 col = mix(float3(0.20, 0.05, 0.025), float3(0.82, 0.42, 0.17), diff);
    col += float3(0.95, 0.70, 0.42) * pow(diff, 7.0) * 0.30;

    // dune-scale light and shade
    float dunes = fbm(uv * 0.55 + float2(time * 0.012, 0.0));
    col *= 0.55 + 0.75 * dunes;

    // gusty dust: the streak direction itself wanders over space and time
    float gust = (fbm(uv * 0.6 + time * 0.07) - 0.5) * 2.6;
    float2 wd = rot(WIND, gust);
    float2 wuv = float2(dot(uv, wd), dot(uv, float2(-wd.y, wd.x)));
    float dust1 = fbm(float2(wuv.x * 1.5 - time * 0.60, wuv.y * 12.0));
    float dust2 = fbm(float2(wuv.x * 2.5 - time * 1.25 + 7.0, wuv.y * 20.0));
    float dust = smoothstep(0.50, 0.80, dust1) * 0.6
               + smoothstep(0.55, 0.85, dust2) * 0.4;
    col = mix(col, float3(0.85, 0.58, 0.36), dust * 0.45);

    // gentle desaturation so it reads dusty rather than neon
    col = mix(col, float3(dot(col, float3(0.299, 0.587, 0.114))), 0.07);

    // sand kicked up by the dust devil
    float kick = touchActive * exp(-rt * 2.5)
               * (0.30 + 0.45 * fbm(uv * 7.0 + time * 1.5));
    col = mix(col, float3(0.95, 0.68, 0.42), kick);

    // fine grain so it never looks flat
    col += (hash21(position + fract(time) * 100.0) - 0.5) * 0.03;

    // warm haze in the sun corner, vignette, tonemap
    float2 sv = position / size - 0.5;
    col += float3(0.20, 0.10, 0.04) * exp(-length(sv - float2(-0.45, -0.45)) * 3.0);
    col *= 1.0 - 0.40 * dot(sv, sv);
    col = 1.0 - exp(-col * 1.9);

    return half4(half3(col), 1.0);
}
