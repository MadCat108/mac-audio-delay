import XCTest
@testable import AudioDelay

final class AudioSourceAvailabilityTrackerTests: XCTestCase {
  func testReportsOnlyAvailabilityChanges() {
    var tracker = AudioSourceAvailabilityTracker(isAvailable: true)

    XCTAssertNil(tracker.update(isAvailable: true))
    XCTAssertEqual(tracker.update(isAvailable: false), false)
    XCTAssertNil(tracker.update(isAvailable: false))
    XCTAssertEqual(tracker.update(isAvailable: true), true)
    XCTAssertTrue(tracker.isAvailable)
  }
}
