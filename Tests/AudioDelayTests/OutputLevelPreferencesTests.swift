import XCTest
@testable import AudioDelay

final class OutputLevelPreferencesTests: XCTestCase {
  private var suiteName: String!
  private var preferences: UserDefaults!

  override func setUp() {
    super.setUp()
    suiteName = "AudioDelayTests.\(UUID().uuidString)"
    preferences = UserDefaults(suiteName: suiteName)
  }

  override func tearDown() {
    preferences.removePersistentDomain(forName: suiteName)
    preferences = nil
    suiteName = nil
    super.tearDown()
  }

  func testDefaultsToFullVolume() {
    XCTAssertEqual(OutputLevelPreferences.loadVolume(from: preferences), 1)
  }

  func testSavesAndClampsVolume() {
    OutputLevelPreferences.saveVolume(0.65, to: preferences)
    XCTAssertEqual(OutputLevelPreferences.loadVolume(from: preferences), 0.65)

    OutputLevelPreferences.saveVolume(2, to: preferences)
    XCTAssertEqual(OutputLevelPreferences.loadVolume(from: preferences), 1)
  }
}
