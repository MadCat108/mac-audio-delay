import XCTest

@testable import AudioDelay

final class AppVersionTests: XCTestCase {
  func testParsesAndComparesVersions() throws {
    XCTAssertLessThan(try XCTUnwrap(AppVersion("0.1.9")), try XCTUnwrap(AppVersion("0.2.0")))
    XCTAssertLessThan(try XCTUnwrap(AppVersion("1.9")), try XCTUnwrap(AppVersion("1.10")))
  }

  func testMissingComponentsCompareAsZero() throws {
    XCTAssertEqual(try XCTUnwrap(AppVersion("1.2")), try XCTUnwrap(AppVersion("1.2.0")))
  }

  func testRejectsInvalidVersions() {
    XCTAssertNil(AppVersion(""))
    XCTAssertNil(AppVersion("1..2"))
    XCTAssertNil(AppVersion("v1.2.3"))
  }
}
