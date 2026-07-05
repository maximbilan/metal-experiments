import SwiftUI

@main
struct SingularityApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

/// A procedural "black hole nebula" rendered entirely by one SwiftUI
/// `colorEffect` shader. Drag anywhere to bend spacetime.
struct ContentView: View {
    @State private var touch: CGPoint?
    @State private var isTouching = false
    private let start = Date()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSince(start)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.42)
                Rectangle()
                    .colorEffect(ShaderLibrary.singularity(
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
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                Text("SINGULARITY")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .kerning(6)
                Text("drag to bend spacetime")
                    .font(.system(.footnote, design: .monospaced))
                    .opacity(0.6)
            }
            .foregroundStyle(.white)
            .blendMode(.plusLighter)
            .padding(.bottom, 48)
            .allowsHitTesting(false)
        }
        .statusBarHidden()
    }
}
