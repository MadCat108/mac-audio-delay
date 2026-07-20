import SwiftUI

struct StereoPeakMeter: View {
  let peak: StereoPeak

  var body: some View {
    VStack(spacing: 5) {
      PeakChannel(
        label: "L",
        level: peak.left,
        clipping: peak.leftClipping
      )
      PeakChannel(
        label: "R",
        level: peak.right,
        clipping: peak.rightClipping
      )
    }
    .frame(width: 172)
    .accessibilityElement(children: .contain)
  }
}

private struct PeakChannel: View {
  let label: String
  let level: Double
  let clipping: Bool

  private var clampedLevel: Double {
    min(1, max(0, level))
  }

  var body: some View {
    HStack(spacing: 7) {
      Text(label)
        .font(.caption2.monospaced().weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 10)

      GeometryReader { geometry in
        let filledWidth = geometry.size.width * clampedLevel

        ZStack(alignment: .leading) {
          Capsule()
            .fill(.primary.opacity(0.1))

          LinearGradient(
            stops: [
              .init(color: Color(red: 0.18, green: 0.82, blue: 0.46), location: 0),
              .init(color: Color(red: 0.37, green: 0.85, blue: 0.30), location: 0.76),
              .init(color: Color(red: 0.98, green: 0.68, blue: 0.15), location: 0.88),
              .init(color: Color(red: 0.96, green: 0.22, blue: 0.20), location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
          .frame(width: geometry.size.width)
          .frame(width: filledWidth, alignment: .leading)
          .clipped()
          .clipShape(Capsule())
        }
        .overlay {
          Capsule()
            .stroke(clipping ? Color.red.opacity(0.9) : .white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: clipping ? .red.opacity(0.55) : .clear, radius: 4)
      }
      .frame(height: 7)
    }
    .animation(.linear(duration: 0.12), value: clampedLevel)
    .animation(.easeOut(duration: 0.12), value: clipping)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(label) channel level")
    .accessibilityValue(clipping ? "Clipping" : "\(Int(clampedLevel * 100)) percent")
  }
}
