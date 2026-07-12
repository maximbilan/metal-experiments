# Snow ❄️

A winter night rendered by **one SwiftUI modifier** and **one Metal shader**.
A moon hangs in a cold sky while parallax layers of snow drift down on a
gusting wind and settle into a bank below. Touch the sky and a flurry swirls
up under your finger.

![screenshot](screenshot.jpg)

## How it works

- `Sources/Snow.metal` — a single `[[stitchable]]` function: cold-sky
  gradient + moon glow → five parallax snow layers (each a scrolling grid of
  drifting, twinkling flakes) → snow bank → a touch-driven flurry → grain +
  vignette + tonemap.
- `Sources/SnowApp.swift` — `TimelineView(.animation)` feeds time into
  `.colorEffect(ShaderLibrary.snowfall(...))`; a `DragGesture` feeds the touch point.

## Drop into your own app

1. Copy `Snow.metal` into your target (Xcode compiles it automatically).
2. Use the shader on any view:

```swift
TimelineView(.animation) { tl in
    Rectangle().colorEffect(ShaderLibrary.snowfall(
        .float2(size), .float(t), .float2(touch), .float(1)
    ))
}
```

Requires iOS 17+ (SwiftUI Shader API).

## Run this demo

```sh
xcodegen generate   # brew install xcodegen
open Snow.xcodeproj
```
