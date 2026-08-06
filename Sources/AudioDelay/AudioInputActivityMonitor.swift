import Foundation

struct AudioInputActivityMonitor {
  let warningDelay: TimeInterval
  private let startedAt: Date
  private(set) var hasObservedActivity = false

  init(warningDelay: TimeInterval = 5, startedAt: Date = Date()) {
    self.warningDelay = warningDelay
    self.startedAt = startedAt
  }

  mutating func update(peak: StereoPeak, at date: Date = Date()) -> Bool {
    if peak.left > 0 || peak.right > 0 {
      hasObservedActivity = true
      return false
    }
    guard !hasObservedActivity else { return false }
    return date.timeIntervalSince(startedAt) >= warningDelay
  }
}