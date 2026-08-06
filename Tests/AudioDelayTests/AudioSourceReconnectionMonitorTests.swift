import XCTest
@testable import AudioDelay

final class AudioSourceReconnectionMonitorTests: XCTestCase {
  func testRestartsBufferingOnFirstInputAfterSourceReturns() {
    var monitor = AudioSourceReconnectionMonitor()

    monitor.sourceAvailabilityChanged(isAvailable: false)
    monitor.sourceAvailabilityChanged(isAvailable: true)

    XCTAssertTrue(monitor.isAwaitingInput)
    XCTAssertFalse(monitor.receiveInputActivity(isActive: false))
    XCTAssertTrue(monitor.receiveInputActivity(isActive: true))
    XCTAssertFalse(monitor.isAwaitingInput)
    XCTAssertFalse(monitor.receiveInputActivity(isActive: true))
  }

  func testOrdinaryInputDoesNotRestartBuffering() {
    var monitor = AudioSourceReconnectionMonitor()

    XCTAssertFalse(monitor.receiveInputActivity(isActive: true))
  }
}
