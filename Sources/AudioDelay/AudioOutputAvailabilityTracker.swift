struct AudioOutputAvailabilityTracker {
  let outputUID: String
  private(set) var isAvailable = true

  mutating func update(availableUIDs: Set<String>) -> Bool? {
    let newValue = availableUIDs.contains(outputUID)
    guard newValue != isAvailable else { return nil }
    isAvailable = newValue
    return newValue
  }
}
