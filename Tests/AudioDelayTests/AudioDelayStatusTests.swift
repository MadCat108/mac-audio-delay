import XCTest
@testable import AudioDelay

final class AudioDelayStatusTests: XCTestCase {
  func testConnectionStatusLabelsAreExplicit() {
    XCTAssertEqual(AudioDelayStatus.buffering(12).label, "Buffering — 12 seconds remaining")
    XCTAssertEqual(AudioDelayStatus.playing.label, "Playing")
    XCTAssertEqual(AudioDelayStatus.noAudioDetected.label, "No Audio Detected")
    XCTAssertEqual(AudioDelayStatus.outputDisconnected.label, "Output Disconnected")
    XCTAssertEqual(AudioDelayStatus.permissionRequired.label, "Permission Required")
  }

  func testWaitingStatusNamesTheApplication() {
    XCTAssertEqual(
      AudioDelayStatus.waitingForSource("Example Player").label,
      "Waiting for Example Player to reopen"
    )
  }
}
