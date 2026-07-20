import Foundation

struct AppVersion: Comparable, Equatable, CustomStringConvertible {
  let components: [Int]

  init?(_ value: String) {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
    guard !parts.isEmpty else { return nil }

    var parsed: [Int] = []
    for part in parts {
      guard !part.isEmpty, let component = Int(part), component >= 0 else { return nil }
      parsed.append(component)
    }
    components = parsed
  }

  var description: String {
    components.map(String.init).joined(separator: ".")
  }

  static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
    !(lhs < rhs) && !(rhs < lhs)
  }

  static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
    let count = max(lhs.components.count, rhs.components.count)
    for index in 0..<count {
      let left = index < lhs.components.count ? lhs.components[index] : 0
      let right = index < rhs.components.count ? rhs.components[index] : 0
      if left != right { return left < right }
    }
    return false
  }
}
