struct AudioSourceAvailabilityTracker {
  private(set) var isAvailable: Bool

  init(isAvailable: Bool) {
    self.isAvailable = isAvailable
  }

  mutating func update(isAvailable newValue: Bool) -> Bool? {
    guard newValue != isAvailable else { return nil }
    isAvailable = newValue
    return newValue
  }
}
