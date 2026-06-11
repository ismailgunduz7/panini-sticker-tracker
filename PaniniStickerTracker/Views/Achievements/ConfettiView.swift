import SwiftUI

/// A lightweight, dependency-free confetti burst. Each instance plays once on
/// appear, so present it with a unique `.id(...)` to replay.
struct ConfettiView: View {
    var pieceCount = 90

    private let pieces: [Piece]

    init(pieceCount: Int = 90) {
        self.pieceCount = pieceCount
        pieces = (0..<pieceCount).map { _ in Piece.random() }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    ConfettiPieceView(piece: piece, size: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }

    struct Piece: Identifiable {
        let id = UUID()
        let xFraction: CGFloat
        let color: Color
        let size: CGFloat
        let delay: Double
        let duration: Double
        let spin: Double
        let drift: CGFloat
        let isCircle: Bool

        static func random() -> Piece {
            let palette: [Color] = [.red, .orange, .yellow, .green, .mint, .blue, .indigo, .purple, .pink]
            return Piece(
                xFraction: .random(in: 0...1),
                color: palette.randomElement()!,
                size: .random(in: 6...11),
                delay: .random(in: 0...0.35),
                duration: .random(in: 1.8...2.8),
                spin: .random(in: 1.5...4) * (Bool.random() ? 1 : -1),
                drift: .random(in: -40...40),
                isCircle: Bool.random()
            )
        }
    }
}

private struct ConfettiPieceView: View {
    let piece: ConfettiView.Piece
    let size: CGSize

    @State private var fall = false

    var body: some View {
        Group {
            if piece.isCircle {
                Circle().fill(piece.color)
            } else {
                RoundedRectangle(cornerRadius: 1.5).fill(piece.color)
            }
        }
        .frame(width: piece.size, height: piece.size * (piece.isCircle ? 1 : 1.6))
        .rotationEffect(.radians(fall ? piece.spin * .pi * 2 : 0))
        .position(
            x: piece.xFraction * size.width + (fall ? piece.drift : 0),
            y: fall ? size.height + 40 : -40
        )
        .opacity(fall ? 0 : 1)
        .onAppear {
            withAnimation(.easeIn(duration: piece.duration).delay(piece.delay)) {
                fall = true
            }
        }
    }
}

#Preview {
    ConfettiView()
        .background(Color.black.opacity(0.05))
}
