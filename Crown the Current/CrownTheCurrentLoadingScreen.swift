import SwiftUI

struct CrownTheCurrentLoadingScreen: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            CTCTheme.parchment.ignoresSafeArea()
            VStack(spacing: 26) {
                ZStack {
                    Circle()
                        .fill(CTCTheme.navy)
                        .frame(width: 118, height: 118)
                    Circle()
                        .strokeBorder(CTCTheme.goldLine, lineWidth: 3)
                        .frame(width: 100, height: 100)
                    CTCMeanderShape()
                        .stroke(CTCTheme.goldLine, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 64, height: 64)
                }
                Text("Crown the Current")
                    .font(.custom("Georgia-Bold", size: 30))
                    .foregroundColor(CTCTheme.ink)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(CTCTheme.riverMid)
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
