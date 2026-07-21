import CoreAudio
import Foundation

enum AudioSelectionResolver {
  static func outputID(
    savedUID: String?,
    devices: [AudioDevice],
    defaultID: AudioDeviceID?
  ) -> AudioDeviceID? {
    if let savedUID, let savedDevice = devices.first(where: { $0.uid == savedUID }) {
      return savedDevice.id
    }
    if let defaultID, devices.contains(where: { $0.id == defaultID }) {
      return defaultID
    }
    return devices.first?.id
  }

  static func source(
    savedBundleIdentifier: String?,
    applications: [AudioApplication]
  ) -> AudioSourceSelection {
    guard let savedBundleIdentifier,
      applications.contains(where: { $0.bundleIdentifier == savedBundleIdentifier })
    else {
      return .allMacAudio
    }
    return .application(savedBundleIdentifier)
  }
}
