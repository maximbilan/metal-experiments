# Coca-Cola 🥤

A glass of Coca-Cola filling the space, rendered by **one SwiftUI modifier**
and **one Metal shader**. Dark caramel cola rises from below, streams of
carbonation wobble up through it, and a fizzing tan foam head builds along the
surface. Touch the drink to bulge the surface up and blow a burst of fizz out
under your finger.

![screenshot](screenshot.jpg)

## How it works

- `Sources/CocaCola.metal` — a single `[[stitchable]]` function: a rising fill
  level with a wavy, sloshing surface → the cola body (backlit caramel near the
  top fading to near-black depths, with a bright meniscus) → three parallax
  layers of carbonation rising and popping at the top → a fizzing foam head
  driven by fbm → a touch-driven surface bulge and fizz burst → grain +
  vignette + warm tonemap.
- `Sources/CocaColaApp.swift` — `TimelineView(.animation)` feeds time into
  `.colorEffect(ShaderLibrary.cocaCola(...))`; a `DragGesture` feeds the touch point.

## Drop into your own app

1. Copy `CocaCola.metal` into your target (Xcode compiles it automatically).
2. Use the shader on any view:

```swift
TimelineView(.animation) { tl in
    Rectangle().colorEffect(ShaderLibrary.cocaCola(
        .float2(size), .float(t), .float2(touch), .float(1)
    ))
}
```

Requires iOS 17+ (SwiftUI Shader API).

## Run this demo

```sh
xcodegen generate   # brew install xcodegen
open CocaCola.xcodeproj
```
