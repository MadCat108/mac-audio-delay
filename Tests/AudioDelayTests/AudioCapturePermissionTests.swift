import CoreAudio
import Foundation
import XCTest

@testable import AudioDelay

final class AudioCapturePermissionTests: XCTestCase {
  func testRecognizesOnlyCoreAudioPermissionError() {
    XCTAssertTrue(
      NativeAudioDelayError.isAudioCapturePermissionError(kAudioDevicePermissionsError)
    )
    XCTAssertFalse(
      NativeAudioDelayError.isAudioCapturePermissionError(kAudioHardwareIllegalOperationError)
    )
  }

  func testInfoPlistRequestsOnlySystemAudioCapture() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let plistURL = projectRoot.appendingPathComponent("Resources/Info.plist")
    let data = try Data(contentsOf: plistURL)
    let plist = try XCTUnwrap(
      PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    )

    XCTAssertNotNil(plist["NSAudioCaptureUsageDescription"])
    XCTAssertNil(plist["NSScreenCaptureUsageDescription"])
    XCTAssertNil(plist["NSMicrophoneUsageDescription"])
    XCTAssertNil(plist["NSCameraUsageDescription"])
  }
}