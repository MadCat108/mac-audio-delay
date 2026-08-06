import CoreAudio
import Foundation

enum AudioSourceSelection: Hashable {
  case allMacAudio
  case application(String)
}

@MainActor
final class AudioDelayModel: ObservableObject {
  enum RunState: Equatable {
    case stopped
    case waiting(Int)
    case running

    var label: String {
      switch self {
      case .stopped:
        return "Stopped"
      case .waiting(let seconds):
        return "Buffering — \(seconds) seconds remaining"
      case .running:
        return "Playing"
      }
    }
  }

  @Published var delayText: String {
    didSet {
      DelayPreferences.saveIfValid(delayText, to: preferences)
    }
  }
  @Published var outputDevices: [AudioDevice] = []
  @Published var selectedOutputID: AudioDeviceID? {
    didSet {
      guard let selectedOutputID,
        let output = outputDevices.first(where: { $0.id == selectedOutputID })
      else {
        return
      }
      AudioSelectionPreferences.saveOutputUID(output.uid, to: preferences)
    }
  }
  @Published var sourceApplications: [AudioApplication] = []
  @Published var selectedSource: AudioSourceSelection {
    didSet {
      let bundleIdentifier: String?
      if case .application(let identifier) = selectedSource {
        bundleIdentifier = identifier
      } else {
        bundleIdentifier = nil
      }
      AudioSelectionPreferences.saveSourceBundleIdentifier(bundleIdentifier, to: preferences)
    }
  }
  @Published var runState: RunState = .stopped
  @Published private(set) var bufferProgress = 0.0
  @Published private(set) var peakLevels = StereoPeak.zero
  @Published private(set) var inputPeakLevels = StereoPeak.zero
  @Published private(set) var noAudioDetected = false
  @Published private(set) var selectedSourceIsAvailable = true
  @Published var errorMessage: String?
  @Published var needsAudioCapturePermission = false

  private var engine: NativeAudioDelayEngine?
  private let preferences: UserDefaults
  private var countdownTimer: Timer?
  private var meterTimer: Timer?
  private var countdownDeadline: Date?
  private var countdownDuration = 0.0
  private var inputActivityMonitor = AudioInputActivityMonitor()
  private var sourceReconnectionMonitor = AudioSourceReconnectionMonitor()
  private var audioDeviceChangeMonitor: AudioDeviceChangeMonitor?
  private var outputAvailabilityTracker: AudioOutputAvailabilityTracker?

  var isRunning: Bool { engine != nil }
  var isWaitingForSelectedSource: Bool {
    guard isRunning, case .application = selectedSource else { return false }
    return !selectedSourceIsAvailable
  }

  init(preferences: UserDefaults = .standard) {
    self.preferences = preferences
    delayText = DelayPreferences.load(from: preferences)
    selectedSource = .allMacAudio
    refreshDevices()
    refreshApplications()
    audioDeviceChangeMonitor = try? AudioDeviceChangeMonitor { [weak self] in
      Task { @MainActor [weak self] in
        self?.audioDevicesChanged()
      }
    }
  }

  func refreshDevices() {
    do {
      let devices = try AudioDevices.all()
      outputDevices = devices.filter(\.hasOutput)

      if let selectedOutputID, outputDevices.contains(where: { $0.id == selectedOutputID }) {
        return
      }

      let defaultID = try? AudioDevices.defaultOutputID()
      selectedOutputID = AudioSelectionResolver.outputID(
        savedUID: AudioSelectionPreferences.outputUID(from: preferences),
        devices: outputDevices,
        defaultID: defaultID
      )
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func refreshApplications() {
    sourceApplications = AudioApplications.running()

    if case .application(let identifier) = selectedSource,
      sourceApplications.contains(where: { $0.bundleIdentifier == identifier })
    {
      return
    }

    selectedSource = AudioSelectionResolver.source(
      savedBundleIdentifier: AudioSelectionPreferences.sourceBundleIdentifier(from: preferences),
      applications: sourceApplications
    )
  }

  var selectedSourceApplicationName: String? {
    guard case .application(let identifier) = selectedSource else { return nil }
    return sourceApplications.first(where: { $0.bundleIdentifier == identifier })?.name
  }

  func start() {
    guard !isRunning else { return }
    needsAudioCapturePermission = false
    guard let seconds = DelayValidation.parse(delayText) else {
      errorMessage = "Enter a delay between 0 and 3600 seconds."
      return
    }
    guard let output = outputDevices.first(where: { $0.id == selectedOutputID }) else {
      errorMessage = "Select an output device."
      return
    }

    launch(seconds: seconds, output: output)
  }

  func stop() {
    countdownTimer?.invalidate()
    countdownTimer = nil
    meterTimer?.invalidate()
    meterTimer = nil
    countdownDeadline = nil
    countdownDuration = 0
    bufferProgress = 0
    peakLevels = .zero
    inputPeakLevels = .zero
    noAudioDetected = false
    selectedSourceIsAvailable = true
    sourceReconnectionMonitor.reset()
    outputAvailabilityTracker = nil
    engine?.stop()
    engine = nil
    runState = .stopped
  }

  private func launch(seconds: Double, output: AudioDevice) {
    do {
      guard #available(macOS 14.2, *) else {
        throw NativeAudioDelayError.unsupportedSystem
      }
      let engine = NativeAudioDelayEngine()
      selectedSourceIsAvailable = true
      try engine.start(
        delay: seconds,
        output: output,
        source: selectedSource,
        sourceAvailabilityChanged: { [weak self] isAvailable in
          Task { @MainActor [weak self] in
            self?.setSelectedSourceAvailability(isAvailable)
          }
        }
      )
      self.engine = engine
      outputAvailabilityTracker = AudioOutputAvailabilityTracker(outputUID: output.uid)
      peakLevels = .zero
      inputPeakLevels = .zero
      noAudioDetected = false
      inputActivityMonitor = AudioInputActivityMonitor()
      meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        Task { @MainActor in
          guard let self, let engine = self.engine else { return }
          self.peakLevels = engine.peakLevels()
          self.inputPeakLevels = engine.inputPeakLevels()
          let hasInputActivity = self.inputPeakLevels.left > 0
            || self.inputPeakLevels.right > 0
          if self.sourceReconnectionMonitor.receiveInputActivity(
            isActive: hasInputActivity
          ), let seconds = DelayValidation.parse(self.delayText) {
            self.beginCountdown(seconds: seconds)
          }
          let noInputDetected = self.inputActivityMonitor.update(
            peak: self.inputPeakLevels
          )
          self.noAudioDetected = self.selectedSourceIsAvailable && noInputDetected
        }
      }
      beginCountdown(seconds: seconds)
    } catch {
      engine?.stop()
      engine = nil
      if let nativeError = error as? NativeAudioDelayError,
        case .audioCapturePermissionDenied = nativeError
      {
        needsAudioCapturePermission = true
      } else {
        errorMessage = error.localizedDescription
      }
      runState = .stopped
    }
  }

  private func setSelectedSourceAvailability(_ isAvailable: Bool) {
    guard selectedSourceIsAvailable != isAvailable else { return }
    selectedSourceIsAvailable = isAvailable
    sourceReconnectionMonitor.sourceAvailabilityChanged(isAvailable: isAvailable)
    noAudioDetected = false
    if isAvailable {
      inputActivityMonitor = AudioInputActivityMonitor()
    }
  }

  private func audioDevicesChanged() {
    do {
      let devices = try AudioDevices.all().filter(\.hasOutput)
      let previouslySelectedOutputName = selectedOutputName
      let disconnectedOutput = outputAvailabilityTracker?.update(
        availableUIDs: Set(devices.map(\.uid))
      ) == false

      outputDevices = devices

      if disconnectedOutput {
        let disconnectedName = previouslySelectedOutputName ?? "The selected playback device"
        stop()
        selectAvailableOutput(preferSavedOutput: false)
        let replacementName = selectedOutputName ?? "the current system output"
        errorMessage = "\(disconnectedName) disconnected. Audio Delay stopped and normal playback was restored. \(replacementName) is now selected. Reconnect the device or press Start to use this output."
        return
      }

      if let selectedOutputID,
        devices.contains(where: { $0.id == selectedOutputID })
      {
        return
      }
      selectAvailableOutput(preferSavedOutput: true)
    } catch {
      if isRunning {
        errorMessage = error.localizedDescription
      }
    }
  }

  private var selectedOutputName: String? {
    guard let selectedOutputID else { return nil }
    return outputDevices.first(where: { $0.id == selectedOutputID })?.name
  }

  private func selectAvailableOutput(preferSavedOutput: Bool) {
    let defaultID = try? AudioDevices.defaultOutputID()
    selectedOutputID = AudioSelectionResolver.outputID(
      savedUID: preferSavedOutput
        ? AudioSelectionPreferences.outputUID(from: preferences)
        : nil,
      devices: outputDevices,
      defaultID: defaultID
    )
  }

  private func beginCountdown(seconds: Double) {
    countdownTimer?.invalidate()
    countdownDuration = seconds
    bufferProgress = 0
    countdownDeadline = Date().addingTimeInterval(seconds)
    updateCountdown()
    countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.updateCountdown() }
    }
  }

  private func updateCountdown() {
    guard let deadline = countdownDeadline else { return }
    let remainingInterval = max(0, deadline.timeIntervalSinceNow)
    if countdownDuration > 0 {
      bufferProgress = min(1, max(0, 1 - remainingInterval / countdownDuration))
    }
    let remaining = max(0, Int(ceil(remainingInterval)))
    if remaining == 0 {
      countdownTimer?.invalidate()
      countdownTimer = nil
      countdownDeadline = nil
      countdownDuration = 0
      bufferProgress = 1
      runState = .running
    } else {
      runState = .waiting(remaining)
    }
  }

}
