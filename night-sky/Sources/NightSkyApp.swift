import SwiftUI

@main
struct NightSkyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

/// A deep night sky rendered entirely by one SwiftUI `colorEffect` shader:
/// a tilted Milky Way with nebula and dust lanes, parallax layers of
/// twinkling stars, the odd shooting star, and a wish-upon-a-star glow
/// wherever you touch.
struct ContentView: View {
    @State private var touch: CGPoint?
    @State private var isTouching = false
    private let start = Date()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(start)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.5)
                Rectangle()
                    .colorEffect(ShaderLibrary.nightSky(
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
