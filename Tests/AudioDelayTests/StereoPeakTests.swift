import XCTest
@testable import AudioDelay

final class StereoPeakTests: XCTestCase {
  func testZeroGainProducesSilentMeter() {
    let peak = StereoPeak(
      left: 0.5,
      right: 0.8,
      leftClipping: false,
      rightClipping: true
    )

    XCTAssertEqual(peak.applyingGain(0), .zero)
  }

  func testReducedGainLowersMeterAndClearsClipping() {
    let peak = StereoPeak(
      left: 1,
      right: 0.5,
      leftClipping: true,
      rightClipping: false
    )
    let adjusted = peak.applyingGain(0.5)

    XCTAssertLessThan(adjusted.left, peak.left)
    XCTAssertLessThan(adjusted.right, peak.right)
    XCTAssertFalse(adjusted.leftClipping)
  }
}
