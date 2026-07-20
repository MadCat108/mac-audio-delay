import Foundation

struct StereoPeak: Equatable {
  let left: Double
  let right: Double
  let leftClipping: Bool
  let rightClipping: Bool

  static let zero = StereoPeak(
    left: 0,
    right: 0,
    leftClipping: false,
    rightClipping: false
  )
}

enum PeakMeterParser {
  static func parseLast(in text: String) -> StereoPeak? {
    var searchEnd = text.endIndex

    while let closingBracket = text[..<searchEnd].lastIndex(of: "]") {
      guard let openingBracket = text[..<closingBracket].lastIndex(of: "[") else {
        return nil
      }

      let contentStart = text.index(after: openingBracket)
      let content = text[contentStart..<closingBracket]
      let fields = content.split(separator: "|", omittingEmptySubsequences: false)

      if fields.count == 2,
        let left = parseChannel(fields[0]),
        let right = parseChannel(fields[1])
      {
        return StereoPeak(
          left: left.level,
          right: right.level,
          leftClipping: left.clipping,
          rightClipping: right.clipping
        )
      }

      searchEnd = openingBracket
    }

    return nil
  }

  private static func parseChannel(_ field: Substring) -> (level: Double, clipping: Bool)? {
    guard field.count == 6,
      field.allSatisfy({ $0 == " " || $0 == "-" || $0 == "=" || $0 == "!" })
    else {
      return nil
    }

    let clipping = field.contains("!")
    if clipping {
      return (1, true)
    }

    let equals = field.filter { $0 == "=" }.count
    let hyphens = field.filter { $0 == "-" }.count
    let level = min(1, Double(equals * 2 + hyphens) / 13)
    return (level, false)
  }
}
