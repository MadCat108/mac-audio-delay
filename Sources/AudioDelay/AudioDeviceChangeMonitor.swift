import CoreAudio
import Foundation

final class AudioDeviceChangeMonitor {
  private var devicesAddress = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDevices,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
  )
  private var listener: AudioObjectPropertyListenerBlock?

  init(changeHandler: @escaping () -> Void) throws {
    let listener: AudioObjectPropertyListenerBlock = { _, _ in
      changeHandler()
    }
    let status = AudioObjectAddPropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &devicesAddress,
      DispatchQueue.main,
      listener
    )
    guard status == noErr else {
      throw AudioDeviceError.coreAudio(status, "monitor audio devices")
    }
    self.listener = listener
  }

  deinit {
    stop()
  }

  func stop() {
    guard let listener else { return }
    AudioObjectRemovePropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &devicesAddress,
      DispatchQueue.main,
      listener
    )
    self.listener = nil
  }
}
