import Foundation

enum DelayPreferences {
  static let defaultValue = "90"
  private static let savedDelayKey = "SavedDelaySeconds"

  static func load(from preferences: UserDefaults) -> String {
    guard let savedDelay = preferences.string(forKey: savedDelayKey),
      DelayValidation.parse(savedDelay) != nil
    else {
      return defaultValue
    }
    return savedDelay
  }

  static func saveIfValid(_ value: String, to preferences: UserDefaults) {
    guard DelayValidation.parse(value) != nil else { return }
    preferences.set(value, forKey: savedDelayKey)
  }
}
