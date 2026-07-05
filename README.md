# metal-experiments ⚡️

Small, self-contained visual experiments for iOS. Every effect lives in its own folder:

```
<effect>/
├── README.md        # what it is + how to drop it into your app
├── screenshot.jpg   # preview
├── demo.mp4         # short capture
├── project.yml      # xcodegen spec for the standalone demo app
└── Sources/         # the effect code
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
