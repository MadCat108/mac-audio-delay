import AudioDelayCore
import CoreAudio
import Foundation

enum NativeAudioDelayError: LocalizedError {
  case unsupportedSystem
  case audioCapturePermissionDenied
  case coreAudio(OSStatus, String)
  case processUnavailable
  case unsupportedFormat
  case allocationFailed(Double)

  var errorDescription: String? {
    switch self {
    case .unsupportedSystem:
      return "Audio Delay requires macOS 14.2 or newer for native system-audio capture."
    case .audioCapturePermissionDenied:
      return "System Audio Recording permission is required to route or delay Mac audio."
    case .coreAudio(let status, let action):
      return "Core Audio could not \(action) (error \(Self.describe(status)))."
    case .processUnavailable:
      return "Core Audio could not identify the Audio Delay process."
    case .unsupportedFormat:
      return "The selected output does not provide the 32-bit floating-point format required by the audio engine."
    case .allocationFailed(let seconds):
      return "There is not enough memory to create a \(DelayValidation.commandValue(seconds))-second audio buffer."
    }
  }

  private static func describe(_ status: OSStatus) -> String {
    let value = UInt32(bitPattern: status)
    let characters = [24, 16, 8, 0].map { shift -> Character in
      let byte = UInt8((value >> UInt32(shift)) & 0xff)
      return byte >= 32 && byte <= 126 ? Character(UnicodeScalar(byte)) : "?"
    }
    let fourCC = String(characters)
    return fourCC == "????" ? String(status) : "\(fourCC), \(status)"
  }

  static func isAudioCapturePermissionError(_ status: OSStatus) -> Bool {
    status == kAudioDevicePermissionsError
  }
}

/// Captures all system audio except this app, mutes the immediate copy while
/// capture is active, and sends the delayed copy to a selected physical output.
@available(macOS 14.2, *)
final class NativeAudioDelayEngine {
  private var tapID = AudioObjectID(kAudioObjectUnknown)
  private var aggregateID = AudioObjectID(kAudioObjectUnknown)
  private var processor: OpaquePointer?
  private var tapDescription: CATapDescription?
  private var selectedBundleIdentifier: String?
  private var processListAddress = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyProcessObjectList,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
  )
  private var processListListener: AudioObjectPropertyListenerBlock?

  deinit {
    stop()
  }

  func start(delay seconds: Double, output: AudioDevice, source: AudioSourceSelection) throws {
    stop()

    do {
      let tapDescription = CATapDescription()
      tapDescription.name = "Audio Delay System Audio"
      tapDescription.isPrivate = true
      tapDescription.muteBehavior = .mutedWhenTapped
      tapDescription.isMixdown = true
      tapDescription.isMono = false

      switch source {
      case .allMacAudio:
        tapDescription.processes = [try Self.currentProcessObjectID()]
        tapDescription.isExclusive = true
      case .application(let bundleIdentifier):
        selectedBundleIdentifier = bundleIdentifier
        tapDescription.processes = try Self.processObjectIDs(matching: bundleIdentifier)
        tapDescription.isExclusive = false
      }
      self.tapDescription = tapDescription

      // The Core Audio tap requests only System Audio Recording access when
      // capture starts. Do not call the broader screen-capture permission API.
      let tapStatus = AudioHardwareCreateProcessTap(tapDescription, &tapID)
      try Self.check(tapStatus, "create the system-audio tap")

      if selectedBundleIdentifier != nil {
        try registerProcessListListener()
      }

      let tapUID = try Self.stringProperty(
        tapID,
        selector: kAudioTapPropertyUID,
        action: "read the audio tap identifier"
      )
      aggregateID = try Self.createAggregateDevice(output: output, tapUID: tapUID)
      try Self.requireFloat32Streams(on: aggregateID)

      let sampleRate = try Self.nominalSampleRate(of: aggregateID)
      let delayFrames = UInt64((seconds * sampleRate).rounded())
      guard let createdProcessor = ADDelayProcessorCreate(delayFrames) else {
        throw NativeAudioDelayError.allocationFailed(seconds)
      }
      processor = createdProcessor

      try Self.check(
        ADDelayProcessorStart(createdProcessor, aggregateID),
        "start system-audio capture"
      )
    } catch {
      stop()
      throw error
    }
  }

  func stop() {
    unregisterProcessListListener()
    if let processor {
      ADDelayProcessorDestroy(processor)
      self.processor = nil
    }
    if aggregateID != kAudioObjectUnknown {
      AudioHardwareDestroyAggregateDevice(aggregateID)
      aggregateID = AudioObjectID(kAudioObjectUnknown)
    }
    if tapID != kAudioObjectUnknown {
      AudioHardwareDestroyProcessTap(tapID)
      tapID = AudioObjectID(kAudioObjectUnknown)
    }
    tapDescription = nil
    selectedBundleIdentifier = nil
  }

  func peakLevels() -> StereoPeak {
    guard let processor else { return .zero }
    var left: Float = 0
    var right: Float = 0
    ADDelayProcessorGetPeaks(processor, &left, &right)
    return StereoPeak(
      left: Self.meterLevel(left),
      right: Self.meterLevel(right),
      leftClipping: left >= 0.999,
      rightClipping: right >= 0.999
    )
  }

  func inputPeakLevels() -> StereoPeak {
    guard let processor else { return .zero }
    var left: Float = 0
    var right: Float = 0
    ADDelayProcessorGetInputPeaks(processor, &left, &right)
    return StereoPeak(
      left: Self.meterLevel(left),
      right: Self.meterLevel(right),
      leftClipping: left >= 0.999,
      rightClipping: right >= 0.999
    )
  }

  private static func meterLevel(_ amplitude: Float) -> Double {
    guard amplitude > 0.001 else { return 0 }
    let decibels = 20 * log10(Double(amplitude))
    return min(1, max(0, (decibels + 60) / 60))
  }

  private static func currentProcessObjectID() throws -> AudioObjectID {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var processID = AudioObjectID(kAudioObjectUnknown)
    var size = UInt32(MemoryLayout<AudioObjectID>.size)
    var pid = getpid()
    let status = withUnsafePointer(to: &pid) { qualifier in
      AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        UInt32(MemoryLayout<pid_t>.size),
        qualifier,
        &size,
        &processID
      )
    }
    try check(status, "identify this app's audio process")
    guard processID != kAudioObjectUnknown else {
      throw NativeAudioDelayError.processUnavailable
    }
    return processID
  }

  private func registerProcessListListener() throws {
    let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
      self?.refreshSelectedProcesses()
    }
    try Self.check(
      AudioObjectAddPropertyListenerBlock(
        AudioObjectID(kAudioObjectSystemObject),
        &processListAddress,
        DispatchQueue.main,
        listener
      ),
      "monitor the selected application"
    )
    processListListener = listener
  }

  private func unregisterProcessListListener() {
    guard let processListListener else { return }
    AudioObjectRemovePropertyListenerBlock(
      AudioObjectID(kAudioObjectSystemObject),
      &processListAddress,
      DispatchQueue.main,
      processListListener
    )
    self.processListListener = nil
  }

  private func refreshSelectedProcesses() {
    guard tapID != kAudioObjectUnknown,
      let selectedBundleIdentifier,
      let tapDescription,
      let processIDs = try? Self.processObjectIDs(matching: selectedBundleIdentifier),
      Set(processIDs) != Set(tapDescription.processes)
    else {
      return
    }

    tapDescription.processes = processIDs
    var mutableDescription = tapDescription
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioTapPropertyDescription,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    let size = UInt32(MemoryLayout<CATapDescription>.stride)
    _ = withUnsafeMutablePointer(to: &mutableDescription) { pointer in
      AudioObjectSetPropertyData(tapID, &address, 0, nil, size, pointer)
    }
  }

  private static func processObjectIDs(matching bundleIdentifier: String) throws
    -> [AudioObjectID]
  {
    let systemObject = AudioObjectID(kAudioObjectSystemObject)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyProcessObjectList,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    try check(
      AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size),
      "list audio applications"
    )
    let count = Int(size) / MemoryLayout<AudioObjectID>.size
    var processIDs = Array(repeating: AudioObjectID(kAudioObjectUnknown), count: count)
    try check(
      AudioObjectGetPropertyData(systemObject, &address, 0, nil, &size, &processIDs),
      "list audio applications"
    )

    return processIDs.filter { processID in
      guard let pid = processPID(processID) else { return false }
      if AudioApplications.bundleIdentifier(forPID: pid) == bundleIdentifier {
        return true
      }
      guard let processBundleIdentifier = try? stringProperty(
        processID,
        selector: kAudioProcessPropertyBundleID,
        action: "read an audio application identifier"
      ) else {
        return false
      }
      return processBundleIdentifier == bundleIdentifier
        || processBundleIdentifier.hasPrefix(bundleIdentifier + ".")
    }
  }

  private static func processPID(_ processID: AudioObjectID) -> pid_t? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioProcessPropertyPID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var pid: pid_t = 0
    var size = UInt32(MemoryLayout<pid_t>.size)
    guard AudioObjectGetPropertyData(processID, &address, 0, nil, &size, &pid) == noErr else {
      return nil
    }
    return pid
  }

  private static func createAggregateDevice(output: AudioDevice, tapUID: String) throws
    -> AudioObjectID
  {
    let aggregateUID = "org.audiodelay.utility.aggregate.\(UUID().uuidString)"
    let outputSubdevice: [String: Any] = [
      kAudioSubDeviceUIDKey: output.uid,
      kAudioSubDeviceInputChannelsKey: 0,
      kAudioSubDeviceOutputChannelsKey: output.outputChannels,
      kAudioSubDeviceDriftCompensationKey: false,
    ]
    let subTap: [String: Any] = [
      kAudioSubTapUIDKey: tapUID,
      kAudioSubTapDriftCompensationKey: true,
      kAudioSubTapDriftCompensationQualityKey: kAudioAggregateDriftCompensationMaxQuality,
    ]
    let description: [String: Any] = [
      kAudioAggregateDeviceNameKey: "Audio Delay Private Device",
      kAudioAggregateDeviceUIDKey: aggregateUID,
      kAudioAggregateDeviceSubDeviceListKey: [outputSubdevice],
      kAudioAggregateDeviceMainSubDeviceKey: output.uid,
      kAudioAggregateDeviceIsPrivateKey: true,
      kAudioAggregateDeviceIsStackedKey: false,
      kAudioAggregateDeviceTapListKey: [subTap],
      kAudioAggregateDeviceTapAutoStartKey: false,
    ]

    var id = AudioObjectID(kAudioObjectUnknown)
    try check(
      AudioHardwareCreateAggregateDevice(description as CFDictionary, &id),
      "create a private output device"
    )
    guard id != kAudioObjectUnknown else {
      throw NativeAudioDelayError.coreAudio(kAudioHardwareBadObjectError, "create a private output device")
    }
    return id
  }

  private static func nominalSampleRate(of deviceID: AudioObjectID) throws -> Double {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyNominalSampleRate,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var rate = 0.0
    var size = UInt32(MemoryLayout<Float64>.size)
    try check(
      AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rate),
      "read the output sample rate"
    )
    return rate
  }

  private static func requireFloat32Streams(on deviceID: AudioObjectID) throws {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyStreams,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    try check(
      AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size),
      "inspect the private audio device"
    )
    let count = Int(size) / MemoryLayout<AudioObjectID>.size
    var streams = Array(repeating: AudioObjectID(kAudioObjectUnknown), count: count)
    try check(
      AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &streams),
      "inspect the private audio device"
    )

    for streamID in streams {
      var formatAddress = AudioObjectPropertyAddress(
        mSelector: kAudioStreamPropertyVirtualFormat,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      var format = AudioStreamBasicDescription()
      var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
      try check(
        AudioObjectGetPropertyData(
          streamID,
          &formatAddress,
          0,
          nil,
          &formatSize,
          &format
        ),
        "read an audio stream format"
      )
      guard format.mFormatID == kAudioFormatLinearPCM,
        format.mFormatFlags & kAudioFormatFlagIsFloat != 0,
        format.mBitsPerChannel == 32
      else {
        throw NativeAudioDelayError.unsupportedFormat
      }
    }
  }

  private static func stringProperty(
    _ objectID: AudioObjectID,
    selector: AudioObjectPropertySelector,
    action: String
  ) throws -> String {
    var address = AudioObjectPropertyAddress(
      mSelector: selector,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    try check(
      AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value),
      action
    )
    guard let value else {
      throw NativeAudioDelayError.coreAudio(
        kAudioHardwareUnspecifiedError,
        action
      )
    }
    return value.takeUnretainedValue() as String
  }

  private static func check(_ status: OSStatus, _ action: String) throws {
    guard status == noErr else {
      if NativeAudioDelayError.isAudioCapturePermissionError(status) {
        throw NativeAudioDelayError.audioCapturePermissionDenied
      }
      throw NativeAudioDelayError.coreAudio(status, action)
    }
  }
}