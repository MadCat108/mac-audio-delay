import XCTest

@testable import AudioDelay

final class PeakMeterParserTests: XCTestCase {
  func testParsesSilence() {
    XCTAssertEqual(PeakMeterParser.parseLast(in: "[      |      ]"), .zero)
  }

  func testParsesStereoLevels() throws {
    let peak = try XCTUnwrap(PeakMeterParser.parseLast(in: "status [  -===|===-  ] rest"))

    XCTAssertEqual(peak.left, 7.0 / 13.0, accuracy: 0.0001)
    XCTAssertEqual(peak.right, 7.0 / 13.0, accuracy: 0.0001)
    XCTAssertFalse(peak.leftClipping)
    XCTAssertFalse(peak.rightClipping)
  }

  func testParsesClipping() throws {
    let peak = try XCTUnwrap(PeakMeterParser.parseLast(in: "[!=====|=====!]"))

    XCTAssertEqual(peak.left, 1)
    XCTAssertEqual(peak.right, 1)
    XCTAssertTrue(peak.leftClipping)
    XCTAssertTrue(peak.rightClipping)
  }

  func testUsesLastValidMeterAndIgnoresOtherBrackets() throws {
    let text = "[  -===|===-  ] details [not a meter] [ =====|===== ]"
    let peak = try XCTUnwrap(PeakMeterParser.parseLast(in: text))

    XCTAssertEqual(peak.left, 10.0 / 13.0, accuracy: 0.0001)
    XCTAssertEqual(peak.right, 10.0 / 13.0, accuracy: 0.0001)
  }
}
