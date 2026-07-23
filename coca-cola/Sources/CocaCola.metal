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

// One depth slice of carbonation: a grid scrolling upward where each cell may
// hold a bubble that wobbles sideways as it rises. Neighbours are sampled so
// bubbles cross cell borders cleanly.
static float bubbleLayer(float2 uv, float cells, float speed,
                         float radius, float time, float seed) {
    float2 w = uv * cells;
    w.y += time * speed;                       // scroll upward
    float2 id = floor(w);
    float2 gv = fract(w);
    float acc = 0.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 o = float2(x, y);
            float2 rnd = hash22(id + o + seed);
            float present = step(0.42, rnd.x);          // ~58% of cells fizz
            float2 c = o + rnd;
            c.x += sin(time * (1.0 + rnd.y * 1.6) + rnd.x * 6.2831) * 0.18;
            float r = radius * (0.5 + rnd.y);
            float d = length(gv - c);
            acc = max(acc, smoothstep(r, r * 0.2, d) * present);
        }
    }
    return acc;
}

// ---------- the effect ----------
//
// SwiftUI colorEffect entry point. A glass of Coca-Cola filling the space:
// dark caramel cola rises from below, streams of carbonation wobble up
// through it, and a fizzing tan foam head builds along the surface. Touch
// the drink to bulge the surface and blow up a burst of fizz under your finger.

[[ stitchable ]] half4 cocaCola(float2 position, half4 color, float2 size,
                                float time, float2 touch, float touchActive) {
    float mn = min(size.x, size.y);
    float2 uv = position / mn;                 // aspect-correct
    float2 p  = position / size;               // 0..1 screen space (y down)

    // ---- touch: swirl the carbonation near the finger ----
    float2 tuv = touch / mn;
    float2 dt  = uv - tuv;
    float rt   = length(dt);
    float swirl = touchActive * 1.2 * exp(-rt * 3.5) * (1.0 + 0.25 * sin(time * 5.0));
    float2 buv  = tuv + rot(dt, swirl);        // uv used for the bubble field

    // ---- the drink fills the space from below, easing toward full ----
    float fill = 1.0 - exp(-time * 0.26);
    fill = clamp(fill, 0.0, 0.92);
    float surface = 1.0 - fill;                // screen-y of the liquid top

    // wavy, gently sloshing surface
    surface += 0.010 * sin(uv.x * 7.0 + time * 1.4)
             + 0.006 * sin(uv.x * 15.0 - time * 2.2)
             + 0.008 * (fbm(float2(uv.x * 3.0, time * 0.5)) - 0.5);
    // a touch bulges the drink up toward the finger
    surface -= touchActive * 0.045 * exp(-rt * 4.5);

    float dsurf = p.y - surface;               // <0 above liquid, >0 below

    // ---- empty space above: deep, warm dark with a faint fizz glow ----
    float3 col = mix(float3(0.020, 0.010, 0.008),
                     float3(0.060, 0.022, 0.014), p.y);
    col += float3(0.25, 0.08, 0.03) * exp(-max(0.0, -dsurf) * 6.0) * 0.35;

    // ---- the cola body ----
    float3 shallow = float3(0.42, 0.11, 0.03);         // backlit caramel amber
    float3 deep    = float3(0.085, 0.012, 0.008);      // near-black cola
    float3 cola = mix(shallow, deep, smoothstep(0.0, 0.45, dsurf));

    // slow internal swirl so the body isn't flat
    float body = fbm(uv * 3.0 + float2(0.0, -time * 0.15));
    cola *= 0.85 + 0.30 * body;

    // bright caramel meniscus just under the surface
    float meniscus = smoothstep(0.035, 0.0, dsurf) * step(0.0, dsurf);
    cola += float3(0.60, 0.26, 0.09) * meniscus * 0.6;

    // ---- rising carbonation (three parallax densities) ----
    float bub = bubbleLayer(buv,  9.0, 0.9, 0.10, time,  3.0);
    bub = max(bub, bubbleLayer(buv, 16.0, 1.4, 0.07, time, 21.0) * 0.85);
    bub = max(bub, bubbleLayer(buv, 26.0, 2.1, 0.05, time, 47.0) * 0.65);
    bub *= smoothstep(surface + 0.004, surface + 0.05, p.y);   // pop into foam near top
    float3 bubCol = float3(0.96, 0.72, 0.42);
    cola = mix(cola, bubCol, bub * 0.7);
    cola += bub * bub * float3(0.6, 0.45, 0.30) * 0.5;         // bright specular core

    // extra fizz blown up under the finger
    float fizz = touchActive * exp(-rt * 5.0)
               * (0.4 + 0.6 * fbm(uv * 14.0 - time * 2.5));
    cola += float3(0.98, 0.78, 0.50) * fizz * 0.6;

    // composite the liquid into the space
    float below = smoothstep(surface - 0.002, surface + 0.005, p.y);
    col = mix(col, cola, below);

    // ---- fizzing foam head along the surface ----
    float foamThick = 0.025 + 0.05 * fill;
    float foamTop = smoothstep(-0.020, 0.004, dsurf);
    float foamBot = 1.0 - smoothstep(foamThick, foamThick + 0.03, dsurf);
    float froth   = fbm(float2(uv.x * 12.0, uv.y * 12.0) + float2(0.0, -time * 0.6));
    float frothHi = fbm(float2(uv.x * 28.0 + 5.0, uv.y * 28.0 - time * 1.1));
    float foam = foamTop * foamBot
               * smoothstep(0.35, 0.70, froth * 0.6 + frothHi * 0.5 + 0.15);
    float3 foamCol = mix(float3(0.82, 0.62, 0.40), float3(0.96, 0.86, 0.70), frothHi);
    foamCol += hash21(position * 1.3) * 0.10;                  // crackling sparkle
    col = mix(col, foamCol, clamp(foam, 0.0, 1.0));

    // ---- grain, vignette, warm tonemap ----
    col += (hash21(position + fract(time) * 100.0) - 0.5) * 0.02;
    float2 sv = p - 0.5;
    col *= 1.0 - 0.5 * dot(sv, sv);
    col = 1.0 - exp(-col * 1.9);

    return half4(half3(col), 1.0);
}
