import XCTest

@testable import AudioDelay

final class AudioSelectionPreferencesTests: XCTestCase {
  private var suiteName: String!
  private var preferences: UserDefaults!

  override func setUp() {
    super.setUp()
    suiteName = "AudioSelectionPreferencesTests.\(UUID().uuidString)"
    preferences = UserDefaults(suiteName: suiteName)
  }

  override func tearDown() {
    preferences.removePersistentDomain(forName: suiteName)
    preferences = nil
    suiteName = nil
    super.tearDown()
  }

  func testPersistsOutputUID() {
    XCTAssertNil(AudioSelectionPreferences.outputUID(from: preferences))

    AudioSelectionPreferences.saveOutputUID("speaker.uid", to: preferences)

    XCTAssertEqual(AudioSelectionPreferences.outputUID(from: preferences), "speaker.uid")
  }

  func testPersistsAndClearsSourceBundleIdentifier() {
    XCTAssertNil(AudioSelectionPreferences.sourceBundleIdentifier(from: preferences))

    AudioSelectionPreferences.saveSourceBundleIdentifier("com.example.browser", to: preferences)
    XCTAssertEqual(
      AudioSelectionPreferences.sourceBundleIdentifier(from: preferences),
      "com.example.browser"
    )

    AudioSelectionPreferences.saveSourceBundleIdentifier(nil, to: preferences)
    XCTAssertNil(AudioSelectionPreferences.sourceBundleIdentifier(from: preferences))
  }
}
