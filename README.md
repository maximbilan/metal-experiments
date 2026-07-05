# metal-experiments ⚡️

Small, self-contained visual effects for SwiftUI — each one is a single Metal shader
attached with a single SwiftUI modifier (`colorEffect` / `layerEffect` / `distortionEffect`).
No MTKView, no SpriteKit, no render loops. Copy the `.metal` file into your app and go.

Every effect lives in its own folder with the same layout:

```
<effect>/
├── README.md        # what it is + how to drop it into your app
├── screenshot.jpg   # preview
├── demo.mp4         # short capture
├── project.yml      # xcodegen spec for the standalone demo app
└── Sources/         # one .swift + one .metal — that's the whole effect
```

## Effects

| Preview | Effect | Description |
|---|---|---|
| <a href="singularity/"><img src="singularity/screenshot.jpg" width="160"></a> | [**Singularity**](singularity/) | A procedural black-hole nebula: gravitational swirl + domain-warped fbm noise + event-horizon rim. Drag to bend spacetime. One `colorEffect` shader, iOS 17+. |

## Running a demo

Each folder is a standalone iOS app:

```sh
brew install xcodegen
cd <effect>
xcodegen generate
open *.xcodeproj      # pick a simulator, hit Run
```

## Requirements

- iOS 17+ (SwiftUI Shader API: `colorEffect`, `layerEffect`, `distortionEffect`)
- Xcode 26 (first build may prompt: `xcodebuild -downloadComponent MetalToolchain`)
