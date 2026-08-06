import Foundation

enum OutputLevelPreferences {
  static let defaultVolume = 1.0
  private static let savedVolumeKey = "SavedOutputVolume"

  static func loadVolume(from preferences: UserDefaults) -> Double {
    guard preferences.object(forKey: savedVolumeKey) != nil else {
      return defaultVolume
    }
    return min(1, max(0, preferences.double(forKey: savedVolumeKey)))
  }

  static func saveVolume(_ volume: Double, to preferences: UserDefaults) {
    preferences.set(min(1, max(0, volume)), forKey: savedVolumeKey)
  }
}
