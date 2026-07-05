# Water 💧

A sunlit swimming-pool lane rendered by **one SwiftUI modifier** and **one Metal shader**.
Ambient waves refract the tile floor and the dark lane line, sunlight caustics
dance across them, raindrops ring the surface, and touching it sends ripples
out from your finger.

![screenshot](screenshot.jpg)

## How it works

- `Sources/Water.metal` — a single `[[stitchable]]` function: touch ripple
  displacement → fbm wave refraction → tile floor → depth tint → iterative
  sunlight caustics → tonemap.
- `Sources/WaterApp.swift` — `TimelineView(.animation)` feeds time into
  `.colorEffect(ShaderLibrary.water(...))`; a `DragGesture` feeds the touch point.

## Drop into your own app

1. Copy `Water.metal` into your target (Xcode compiles it automatically).
2. Use the shader on any view:

```swift
TimelineView(.animation) { tl in
    Rectangle().colorEffect(ShaderLibrary.water(
        .float2(size), .float(t), .float2(touch), .float(1)
    ))
}
```

Requires iOS 17+ (SwiftUI Shader API).

## Run this demo

```sh
xcodegen generate   # brew install xcodegen
open Water.xcodeproj
```
