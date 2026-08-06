import XCTest
@testable import AudioDelay

final class DiagnosticsReportTests: XCTestCase {
  func testIncludesSupportInformationWithoutPersonalPaths() {
    let report = DiagnosticsReport(
      appVersion: "1.2.3",
      macOSVersion: "macOS 26.5",
      permission: "Available when last checked",
      status: "Playing",
      delay: "90 seconds",
      source: "Example Player",
      output: "Headphones",
      sampleRate: "48000 Hz",
      outputVolume: "80%",
      lastError: "Failed at /Users/example/Secret/file.txt"
    ).text

    XCTAssertTrue(report.contains("App version: 1.2.3"))
    XCTAssertTrue(report.contains("Source: Example Player"))
    XCTAssertTrue(report.contains("[redacted path]"))
    XCTAssertFalse(report.contains("/Users/example"))
  }
}
