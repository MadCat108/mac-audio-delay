struct AudioSourceReconnectionMonitor {
  private(set) var isAwaitingInput = false

  mutating func sourceAvailabilityChanged(isAvailable: Bool) {
    if !isAvailable {
      isAwaitingInput = true
    }
  }

  mutating func receiveInputActivity(isActive: Bool) -> Bool {
    guard isAwaitingInput, isActive else { return false }
    isAwaitingInput = false
    return true
  }

  mutating func reset() {
    isAwaitingInput = false
  }
}
