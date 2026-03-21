import SwiftUI

struct SplashView: View {
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.10, blue: 0.08).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("SONGSPARK")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                    .tracking(8)

                Text("all we are is dust in the wind")
                    .font(.system(size: 12, weight: .light, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.3))
                    .tracking(1)
            }
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.35)) { opacity = 1 }
            }
        }
    }
}

#Preview { SplashView() }
