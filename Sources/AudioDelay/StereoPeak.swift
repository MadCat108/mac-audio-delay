import Foundation

struct StereoPeak: Equatable {
  let left: Double
  let right: Double
  let leftClipping: Bool
  let rightClipping: Bool

  static let zero = StereoPeak(
    left: 0,
    right: 0,
    leftClipping: false,
    rightClipping: false
  )

  func applyingGain(_ gain: Double) -> StereoPeak {
    guard gain > 0 else { return .zero }
    let clampedGain = min(1, gain)
    let meterAdjustment = 20 * log10(clampedGain) / 60
    return StereoPeak(
      left: max(0, left + meterAdjustment),
      right: max(0, right + meterAdjustment),
      leftClipping: leftClipping && clampedGain == 1,
      rightClipping: rightClipping && clampedGain == 1
    )
  }
}
