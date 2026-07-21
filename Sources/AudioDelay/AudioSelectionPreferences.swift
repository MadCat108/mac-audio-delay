import Foundation

enum AudioSelectionPreferences {
  private static let outputUIDKey = "SavedOutputDeviceUID"
  private static let sourceBundleIdentifierKey = "SavedSourceBundleIdentifier"

  static func outputUID(from preferences: UserDefaults) -> String? {
    preferences.string(forKey: outputUIDKey)
  }

  static func saveOutputUID(_ uid: String, to preferences: UserDefaults) {
    preferences.set(uid, forKey: outputUIDKey)
  }

  static func sourceBundleIdentifier(from preferences: UserDefaults) -> String? {
    preferences.string(forKey: sourceBundleIdentifierKey)
  }

  static func saveSourceBundleIdentifier(_ bundleIdentifier: String?, to preferences: UserDefaults) {
    if let bundleIdentifier {
      preferences.set(bundleIdentifier, forKey: sourceBundleIdentifierKey)
    } else {
      preferences.removeObject(forKey: sourceBundleIdentifierKey)
    }
  }
}
