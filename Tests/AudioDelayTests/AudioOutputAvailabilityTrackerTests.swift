import XCTest
@testable import AudioDelay

final class AudioOutputAvailabilityTrackerTests: XCTestCase {
  func testReportsDisconnectionOnlyOnce() {
    var tracker = AudioOutputAvailabilityTracker(outputUID: "headphones")

    XCTAssertNil(tracker.update(availableUIDs: ["speakers", "headphones"]))
    XCTAssertEqual(tracker.update(availableUIDs: ["speakers"]), false)
    XCTAssertNil(tracker.update(availableUIDs: ["speakers"]))
  }

  func testReportsReconnection() {
    var tracker = AudioOutputAvailabilityTracker(outputUID: "headphones")

    XCTAssertEqual(tracker.update(availableUIDs: ["speakers"]), false)
    XCTAssertEqual(tracker.update(availableUIDs: ["speakers", "headphones"]), true)
  }
}
