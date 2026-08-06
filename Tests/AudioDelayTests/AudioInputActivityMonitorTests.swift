import XCTest
@testable import AudioDelay

final class AudioInputActivityMonitorTests: XCTestCase {
  func testWarnsAfterSustainedSilence() {
    let start = Date(timeIntervalSinceReferenceDate: 100)
    var monitor = AudioInputActivityMonitor(warningDelay: 5, startedAt: start)

    XCTAssertFalse(monitor.update(peak: .zero, at: start.addingTimeInterval(4.9)))
    XCTAssertTrue(monitor.update(peak: .zero, at: start.addingTimeInterval(5)))
  }

  func testInputActivityClearsWarningForRestOfSession() {
    let start = Date(timeIntervalSinceReferenceDate: 100)
    var monitor = AudioInputActivityMonitor(warningDelay: 5, startedAt: start)
    let activePeak = StereoPeak(
      left: 0.4,
      right: 0.2,
      leftClipping: false,
      rightClipping: false
    )

    XCTAssertTrue(monitor.update(peak: .zero, at: start.addingTimeInterval(5)))
    XCTAssertFalse(monitor.update(peak: activePeak, at: start.addingTimeInterval(6)))
    XCTAssertFalse(monitor.update(peak: .zero, at: start.addingTimeInterval(60)))
  }
}