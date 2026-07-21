import XCTest

@testable import AudioDelay

final class DelayPreferencesTests: XCTestCase {
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

  func testUsesDefaultWhenNoDelayIsSaved() {
    XCTAssertEqual(DelayPreferences.load(from: preferences), "90")
  }

  func testSavesAndRestoresValidDelay() {
    DelayPreferences.saveIfValid("0", to: preferences)
    XCTAssertEqual(DelayPreferences.load(from: preferences), "0")
  }

  func testInvalidEditDoesNotReplaceLastValidDelay() {
    DelayPreferences.saveIfValid("120", to: preferences)
    DelayPreferences.saveIfValid("", to: preferences)
    XCTAssertEqual(DelayPreferences.load(from: preferences), "120")
  }
}
