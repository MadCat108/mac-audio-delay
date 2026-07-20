import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Hashable {
  let id: AudioDeviceID
  let name: String
  let uid: String
  let inputChannels: UInt32
  let outputChannels: UInt32

  var hasInput: Bool { inputChannels > 0 }
  var hasOutput: Bool { outputChannels > 0 }
}

enum AudioDeviceError: LocalizedError {
  case coreAudio(OSStatus, String)
  case deviceNotFound(String)

  var errorDescription: String? {
    switch self {
    case .coreAudio(let status, let action):
      return "Core Audio could not \(action) (error \(status))."
    case .deviceNotFound(let name):
      return "The audio device “\(name)” was not found."
    }
  }
}

enum AudioDevices {
  private static let systemObject = AudioObjectID(kAudioObjectSystemObject)

  static func all() throws -> [AudioDevice] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size)
    guard status == noErr else {
      throw AudioDeviceError.coreAudio(status, "list audio devices")
    }

    let count = Int(size) / MemoryLayout<AudioDeviceID>.size
    var ids = Array(repeating: AudioDeviceID(0), count: count)
    status = AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &ids)
    guard status == noErr else {
      throw AudioDeviceError.coreAudio(status, "read audio devices")
    }

    return ids.compactMap { id in
      guard let name = stringProperty(id, selector: kAudioObjectPropertyName),
        let uid = stringProperty(id, selector: kAudioDevicePropertyDeviceUID)
      else {
        return nil
      }
      return AudioDevice(
        id: id,
        name: name,
        uid: uid,
        inputChannels: channelCount(id, scope: kAudioDevicePropertyScopeInput),
        outputChannels: channelCount(id, scope: kAudioDevicePropertyScopeOutput)
      )
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  static func defaultOutputID() throws -> AudioDeviceID {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var id = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &id)
    guard status == noErr else {
      throw AudioDeviceError.coreAudio(status, "read the default output")
    }
    return id
  }

  static func setDefaultOutput(_ id: AudioDeviceID) throws {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var mutableID = id
    let size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectSetPropertyData(systemObject, &address, 0, nil, size, &mutableID)
    guard status == noErr else {
      throw AudioDeviceError.coreAudio(status, "change the default output")
    }
  }

  static func vbCable(in devices: [AudioDevice]) -> AudioDevice? {
    devices.first {
      $0.hasInput && $0.name.localizedCaseInsensitiveContains("VB-Cable")
    }
  }

  private static func stringProperty(_ id: AudioObjectID, selector: AudioObjectPropertySelector)
    -> String?
  {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
    return status == noErr ? value?.takeUnretainedValue() as String? : nil
  }

  private static func channelCount(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> UInt32 {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreamConfiguration,
      mScope: scope,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else {
      return 0
    }

    let storage = UnsafeMutableRawPointer.allocate(
      byteCount: Int(size),
      alignment: MemoryLayout<AudioBufferList>.alignment
    )
    defer { storage.deallocate() }
    guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, storage) == noErr else {
      return 0
    }

    let list = storage.bindMemory(to: AudioBufferList.self, capacity: 1)
    return UnsafeMutableAudioBufferListPointer(list).reduce(0) { $0 + $1.mNumberChannels }
  }
}
