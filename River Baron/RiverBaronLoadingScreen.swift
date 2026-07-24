import SwiftUI

struct RiverBaronLoadingScreen: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            RBTheme.parchment.ignoresSafeArea()
            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(RBTheme.navy)
                        .frame(width: 118, height: 118)
                    Circle()
                        .strokeBorder(RBTheme.goldLine, lineWidth: 3)
                        .frame(width: 100, height: 100)
                    RBMeanderShape()
                        .stroke(RBTheme.goldLine, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 64, height: 64)
                }
                Text("River Baron")
                    .font(.custom("Georgia-Bold", size: 30))
                    .foregroundColor(RBTheme.ink)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(RBTheme.riverMid)
                            .frame(width: 10, height: 10)
                            .opacity(phase == CGFloat(i) ? 1.0 : 0.3)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) {
                phase = 2
            }
        }
    }
}
