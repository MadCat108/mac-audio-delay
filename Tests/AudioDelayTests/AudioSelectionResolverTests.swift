import XCTest

@testable import AudioDelay

final class AudioSelectionResolverTests: XCTestCase {
  private let speakers = AudioDevice(
    id: 1,
    name: "Speakers",
    uid: "speakers.uid",
    inputChannels: 0,
    outputChannels: 2
  )
  private let headphones = AudioDevice(
    id: 2,
    name: "Headphones",
    uid: "headphones.uid",
    inputChannels: 0,
    outputChannels: 2
  )

  func testRestoresSavedOutputWhenPresent() {
    XCTAssertEqual(
      AudioSelectionResolver.outputID(
        savedUID: headphones.uid,
        devices: [speakers, headphones],
        defaultID: speakers.id
      ),
      headphones.id
    )
  }

  func testMissingSavedOutputFallsBackToSystemDefault() {
    XCTAssertEqual(
      AudioSelectionResolver.outputID(
        savedUID: "missing.uid",
        devices: [speakers, headphones],
        defaultID: speakers.id
      ),
      speakers.id
    )
  }

  func testRestoresRunningApplication() {
    let application = AudioApplication(
      bundleIdentifier: "com.example.browser",
      name: "Browser",
      bundleURL: nil
    )

    XCTAssertEqual(
      AudioSelectionResolver.source(
        savedBundleIdentifier: application.bundleIdentifier,
        applications: [application]
      ),
      .application(application.bundleIdentifier)
    )
  }

  func testMissingApplicationFallsBackToAllMacAudio() {
    XCTAssertEqual(
      AudioSelectionResolver.source(
        savedBundleIdentifier: "com.example.missing",
        applications: []
      ),
      .allMacAudio
    )
  }
}
