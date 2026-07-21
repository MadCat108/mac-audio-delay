import Foundation

enum DelayValidation {
  static let minimumSeconds = 0.0
  static let maximumSeconds = 3_600.0

  static func parse(_ text: String) -> Double? {
    guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)),
      value.isFinite,
      value >= minimumSeconds,
      value <= maximumSeconds
    else {
      return nil
    }
    return value
  }

  static func commandValue(_ seconds: Double) -> String {
    seconds.rounded() == seconds ? String(Int(seconds)) : String(format: "%.3f", seconds)
  }
}
