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
    for (int i = 0; i < 5; i++) {
        v += amp * vnoise(p);
        p = p * 2.03 + 17.1;
        amp *= 0.5;
    }
    return v;
}

// A cyclic nebula palette curated to gorgeous deep-space hues — magenta →
// violet → blue → cyan and back — deliberately skipping green/yellow.
static float3 nebPalette(float t) {
    t = fract(t);
    const float3 A = float3(0.92, 0.20, 0.62);   // magenta / rose
    const float3 B = float3(0.46, 0.20, 0.86);   // violet
    const float3 C = float3(0.16, 0.42, 0.96);   // blue
    const float3 D = float3(0.16, 0.82, 0.92);   // cyan
    float s = t * 4.0;
    int i = int(floor(s));
    float f = fract(s);
    f = f * f * (3.0 - 2.0 * f);
    float3 c0 = A, c1 = B;
    if (i == 1)      { c0 = B; c1 = C; }
    else if (i == 2) { c0 = C; c1 = D; }
    else if (i >= 3) { c0 = D; c1 = A; }
    return mix(c0, c1, f);
}

// Multi-hue nebula: domain-warped fbm gives the wispy gas, the curated palette
// paints it magenta / violet / blue / cyan with warm gold in the densest cores,
// dark dust lanes carve it, and a tilted band concentrates the brightest clouds
// along the Milky Way.
static float3 nebula(float2 uv, float2 res, float time, float2 g, float band) {
    float2 q = (uv - res * 0.5) * 1.3;
    float2 w = float2(fbm(q * 0.8 + 1.0), fbm(q * 0.8 + 7.3));
    float density = fbm(q * 1.2 + w * 1.8 + float2(time * 0.008, 0.0));
    float detail  = fbm(q * 3.0 + w * 2.0 - 2.0);
    float dust    = smoothstep(0.34, 0.74, fbm(q * 2.2 + 9.0));

    float amt = (0.26 + 1.05 * band) * density * dust;
    amt = pow(max(amt, 0.0), 1.35) * 2.3;

    // broad low-frequency term so magenta, violet, blue and cyan regions coexist
    float hue = 0.45 * fbm(q * 0.35 + 20.0) + 0.32 * detail
              + 0.22 * density + 0.12 * g.x + 0.015 * time;
    float3 c = nebPalette(hue);
    c += float3(1.0, 0.72, 0.32) * smoothstep(0.70, 0.95, density) * 0.6;  // gold cores
    c = mix(float3(dot(c, float3(0.299, 0.587, 0.114))), c, 1.5);          // vivid saturation
    return max(c, 0.0) * amt;
}

// One depth slice of stars: a grid where each cell holds one star at a random
// spot, with a power-biased brightness (many faint, few brilliant), a slow
// twinkle, a colourful tint, and a faint diffraction glint on the brightest.
static float3 starField(float2 uv, float time, float cells, float gain) {
    float2 st = uv * cells;
    float2 id = floor(st);
    float2 gv = fract(st);
    float3 acc = float3(0.0);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 o = float2(x, y);
            float2 rp = hash22(id + o + 11.3);
            float b  = hash21(id + o + 3.71);
            float c  = hash21(id + o + 91.3);
            float bright = pow(b, 4.0) * gain;
            float2 center = o + rp;
            float2 dv = gv - center;
            float d = length(dv);
            float twinkle = 0.6 + 0.4 * sin(time * (1.0 + 2.0 * c) + b * 100.0);
            float star = bright * twinkle
                       * (smoothstep(0.05, 0.0, d) + 0.4 * exp(-d * 22.0));
            // diffraction glint on the brightest stars
            float glint = smoothstep(0.85, 1.0, b) * bright * twinkle * 0.5
                * (exp(-abs(dv.x) * 55.0 - abs(dv.y) * 5.0)
                 + exp(-abs(dv.y) * 55.0 - abs(dv.x) * 5.0));
            // colourful star: cool↔warm with the odd rose one, kept mostly-white
            float3 tint = mix(float3(0.68, 0.82, 1.0), float3(1.0, 0.82, 0.60), c);
            tint = mix(tint, float3(1.0, 0.65, 0.85), smoothstep(0.92, 1.0, c) * 0.6);
            tint = mix(float3(1.0), tint, 0.5);
            acc += tint * (star + glint);
        }
    }
    return acc;
}

// A shooting star: every `period` seconds a streak crosses the sky in a short
// window, with a bright head and a fading tail, easing in and out.
static float3 meteor(float2 uv, float2 res, float time, float seed) {
    float period = 5.0;
    float lt = time / period + seed;
    float id = floor(lt);
    float f = fract(lt);
    float win = 0.16;                       // fraction of the period it's visible
    float active = step(f, win);
    float prog = clamp(f / win, 0.0, 1.0);
    float2 rnd = hash22(float2(id * 1.7 + seed, id * 0.31 + 5.0));
    float2 start = float2(rnd.x * res.x, 0.04 + rnd.y * res.y * 0.35);
    float2 dir = normalize(float2(mix(-1.0, 1.0, rnd.y) * 0.7, 1.0));
    float span = (res.x + res.y) * 0.85;
    float2 head = start + dir * prog * span;
    float2 d = uv - head;
    float along = dot(d, -dir);             // distance behind the head, along the tail
    float perp = length(d + dir * along);   // perpendicular distance to the path
    float body = smoothstep(0.004, 0.0, perp)
               * smoothstep(0.35, 0.0, max(along, 0.0))
               * step(-0.002, along);
    float headGlow = exp(-length(d) * 42.0);
    float life = sin(prog * 3.14159);
    float3 col = mix(float3(0.6, 0.8, 1.0), float3(1.0, 0.9, 0.75), headGlow);
    return col * (body + headGlow) * life * active;
}

// ---------- the effect ----------
//
// SwiftUI colorEffect entry point. A deep, colourful night sky: a tilted
// Milky Way band of multi-hue nebula with dark dust lanes, three parallax
// layers of twinkling stars, the odd shooting star, and a wish-upon-a-star
// glow where you touch.

[[ stitchable ]] half4 nightSky(float2 position, half4 color, float2 size,
                                float time, float2 touch, float touchActive) {
    float mn = min(size.x, size.y);
    float2 uv = position / mn;
    float2 res = size / mn;
    float2 p = position / size;             // 0..1 screen space

    // ---- sky gradient with faint coloured airglow top and bottom ----
    float3 col = mix(float3(0.010, 0.015, 0.05),
                     float3(0.05, 0.05, 0.13), pow(p.y, 1.5));
    col += float3(0.02, 0.05, 0.08) * pow(p.y, 4.0);          // teal near horizon
    col += float3(0.06, 0.02, 0.07) * pow(1.0 - p.y, 4.0);    // magenta up high

    // ---- multi-hue Milky Way nebula ----
    float2 g = rot(uv - res * 0.5, -0.6);
    float band = exp(-pow(g.y * 1.7, 2.0));
    col += nebula(uv, res, time, g, band);

    // ---- three parallax star layers, plus a fine band-dense sprinkle ----
    col += starField(uv, time, 8.0,  1.0);
    col += starField(uv, time, 14.0, 0.8);
    col += starField(uv, time, 22.0, 0.6);
    col += starField(uv, time, 38.0, 0.5) * (0.25 + 1.2 * band);

    // ---- shooting stars ----
    col += meteor(uv, res, time, 0.0);
    col += meteor(uv, res, time, 2.37);

    // ---- wish upon a star: glow, glint and sparkle under the finger ----
    float2 tuv = touch / mn;
    float2 td = uv - tuv;
    float rt = length(td);
    float3 tcol = float3(0.85, 0.92, 1.0);
    col += tcol * touchActive * exp(-rt * 26.0) * 1.6;                 // core
    col += tcol * touchActive * 0.6
         * (exp(-abs(td.x) * 65.0 - abs(td.y) * 4.0)
          + exp(-abs(td.y) * 65.0 - abs(td.x) * 4.0));                 // glint
    col += tcol * touchActive * exp(-rt * 6.0) * 0.16;                 // halo
    float spk = smoothstep(0.65, 1.0, hash21(floor(uv * 46.0) + floor(time * 12.0)));
    col += tcol * touchActive * exp(-rt * 8.0) * spk * 0.5;            // sparkle

    // ---- saturation boost, grain, gentle vignette, filmic tonemap ----
    float lum = dot(col, float3(0.299, 0.587, 0.114));
    col = mix(float3(lum), col, 1.34);
    col += (hash21(position + fract(time) * 100.0) - 0.5) * 0.015;
    float2 sv = p - 0.5;
    col *= 1.0 - 0.22 * dot(sv, sv);
    col = 1.0 - exp(-col * 2.2);

    return half4(half3(col), 1.0);
}
