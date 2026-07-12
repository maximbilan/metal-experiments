# Night Sky 🌌

A deep night sky rendered by **one SwiftUI modifier** and **one Metal shader**.
A tilted Milky Way arcs across the sky with nebula colour and dark dust lanes,
parallax layers of stars twinkle in warm and cool hues, shooting stars streak
past now and then, and touching the sky lights a wish-upon-a-star glow under
your finger.

![screenshot](screenshot.jpg)

## How it works

- `Sources/NightSky.metal` — a single `[[stitchable]]` function: sky gradient +
  horizon airglow → tilted Milky Way (fbm nebula carved by dust lanes) → three
  parallax star layers with power-biased brightness, twinkle and diffraction
  glints, plus a band-dense sprinkle → periodic shooting stars → a touch glow →
  grain + vignette + tonemap.
- `Sources/NightSkyApp.swift` — `TimelineView(.animation)` feeds time into
  `.colorEffect(ShaderLibrary.nightSky(...))`; a `DragGesture` feeds the touch point.

## Drop into your own app

1. Copy `NightSky.metal` into your target (Xcode compiles it automatically).
2. Use the shader on any view:

```swift
TimelineView(.animation) { tl in
    Rectangle().colorEffect(ShaderLibrary.nightSky(
        .float2(size), .float(t), .float2(touch), .float(1)
    ))
}
```

Requires iOS 17+ (SwiftUI Shader API).

## Run this demo

```sh
xcodegen generate   # brew install xcodegen
open NightSky.xcodeproj
```
