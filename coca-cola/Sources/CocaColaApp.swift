import SwiftUI

@main
struct CocaColaApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

/// A glass of Coca-Cola filling the space, rendered entirely by one SwiftUI
/// `colorEffect` shader: dark caramel cola rises from below, streams of
/// carbonation wobble up through it, and a fizzing tan foam head builds along
/// the surface. Touch the drink to bulge the surface and blow up a burst of fizz.
struct ContentView: View {
    @State private var touch: CGPoint?
    @State private var isTouching = false
    private let start = Date()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(start)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.6)
                Rectangle()
                    .colorEffect(ShaderLibrary.cocaCola(
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
