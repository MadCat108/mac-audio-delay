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
}
