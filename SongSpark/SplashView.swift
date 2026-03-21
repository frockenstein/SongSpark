import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0

    private static let quotes = [
        "all we are is dust in the wind",
        "all we are is just another brick in the wall",
        "manic depression is a frustrating mess",
        "life goes on long after the thrill of living is gone",
        "we're still running against the wind",
        "shots, shots, shots, shots, shots, shots",
        "is this the real life? is this just fantasy?",
        "i'm all about that bass, 'bout that bass"
    ]

    // static = picked once per process, stable even if the view is recreated
    private static let sessionQuote = quotes.randomElement()!

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.10, blue: 0.08).ignoresSafeArea()

            VStack(spacing: 30) {
                Text("SONGSPARK")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                    .tracking(8)

                Text(Self.sessionQuote)
                    .font(.system(size: 15, weight: .light, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.5))
                    .tracking(1)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.45)) { opacity = 1 }
            }
        }
    }
}

#Preview { SplashView() }
