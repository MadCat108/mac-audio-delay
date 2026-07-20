import XCTest

@testable import AudioDelay

final class DelayValidationTests: XCTestCase {
  func testValidDelay() {
    XCTAssertEqual(DelayValidation.parse("90"), 90)
    XCTAssertEqual(DelayValidation.parse(" 1.5 "), 1.5)
    XCTAssertEqual(DelayValidation.parse("3600"), 3600)
  }

  func testInvalidDelay() {
    XCTAssertNil(DelayValidation.parse("0"))
    XCTAssertNil(DelayValidation.parse("3601"))
    XCTAssertNil(DelayValidation.parse("not a number"))
    XCTAssertNil(DelayValidation.parse("nan"))
  }

  func testCommandFormatting() {
    XCTAssertEqual(DelayValidation.commandValue(90), "90")
    XCTAssertEqual(DelayValidation.commandValue(1.25), "1.250")
  }
}
