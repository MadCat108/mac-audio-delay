import Foundation

struct DiagnosticsReport {
  let appVersion: String
  let macOSVersion: String
  let permission: String
  let status: String
  let delay: String
  let source: String
  let output: String
  let sampleRate: String
  let outputVolume: String
  let lastError: String?

  var text: String {
    let error = lastError.map(Self.redactingPaths) ?? "None"
    return """
      Audio Delay Diagnostics
      App version: \(appVersion)
      macOS: \(macOSVersion)
      System audio permission: \(permission)
      Status: \(status)
      Delay: \(delay)
      Source: \(source)
      Output: \(output)
      Sample rate: \(sampleRate)
      Output volume: \(outputVolume)
      Last error: \(error)
      """
  }

  private static func redactingPaths(in text: String) -> String {
    let patterns = [
      #"/Users/[^/\s]+(?:/[^\s]*)?"#,
      #"/private/var/folders/[^\s]+"#,
      #"/var/folders/[^\s]+"#,
    ]
    return patterns.reduce(text) { result, pattern in
      result.replacingOccurrences(
        of: pattern,
        with: "[redacted path]",
        options: .regularExpression
      )
    }
  }
}
