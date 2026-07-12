import SwiftUI

@main
struct SnowApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

/// A winter night rendered entirely by one SwiftUI `colorEffect` shader:
/// a moon in a cold sky, parallax layers of drifting snow, a snow bank
/// below, and a flurry that swirls up wherever you touch.
struct ContentView: View {
    @State private var touch: CGPoint?
    @State private var isTouching = false
    private let start = Date()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(start)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.4)
                Rectangle()
                    .colorEffect(ShaderLibrary.snowfall(
                        .float2(geo.size),
                        .float(Float(t)),
                        .float2(touch ?? center),
                        .float(isTouching ? 1 : 0)
                    ))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { touch = $0.location; isTouching = true }
                    .onEnded { _ in isTouching = false }
            )
        }
        .ignoresSafeArea()
        .background(.black)
        .statusBarHidden()
    }
}
