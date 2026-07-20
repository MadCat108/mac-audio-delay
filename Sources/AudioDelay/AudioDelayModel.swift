import AVFoundation
import CoreAudio
import Foundation

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
        return "Audio begins in \(seconds) seconds"
      case .running:
        return "Playing"
      }
    }
  }

  @Published var delayText = "90"
  @Published var outputDevices: [AudioDevice] = []
  @Published var selectedOutputID: AudioDeviceID?
  @Published var runState: RunState = .stopped
  @Published private(set) var bufferProgress = 0.0
  @Published var errorMessage: String?
  @Published var isVBCableInstalled = false

  private var process: Process?
  private var errorPipe: Pipe?
  private var recentError = Data()
  private var originalOutputID: AudioDeviceID?
  private var countdownTimer: Timer?
  private var countdownDeadline: Date?
  private var countdownDuration = 0.0
  private var stopping = false

  var isRunning: Bool { process?.isRunning == true }

  init() {
    refreshDevices()
  }

  func refreshDevices() {
    do {
      let devices = try AudioDevices.all()
      isVBCableInstalled = AudioDevices.vbCable(in: devices) != nil
      outputDevices = devices.filter {
        $0.hasOutput && !$0.name.localizedCaseInsensitiveContains("VB-Cable")
      }

      if let selectedOutputID,
        outputDevices.contains(where: { $0.id == selectedOutputID })
      {
        return
      }

      let defaultID = try? AudioDevices.defaultOutputID()
      selectedOutputID =
        outputDevices.first(where: { $0.id == defaultID })?.id
        ?? outputDevices.first?.id
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func start() {
    guard !isRunning else { return }
    guard let seconds = DelayValidation.parse(delayText) else {
      errorMessage = "Enter a delay between 1 and 3600 seconds."
      return
    }
    guard let output = outputDevices.first(where: { $0.id == selectedOutputID }) else {
      errorMessage = "Select an output device."
      return
    }

    requestAudioPermission { [weak self] granted in
      guard let self else { return }
      if granted {
        self.launch(seconds: seconds, output: output)
      } else {
        self.errorMessage =
          "Audio input permission is required. Reopen Audio Delay after allowing microphone access."
      }
    }
  }

  func stop() {
    stopping = true
    countdownTimer?.invalidate()
    countdownTimer = nil
    countdownDeadline = nil
    countdownDuration = 0
    bufferProgress = 0

    if let process, process.isRunning {
      process.terminationHandler = nil
      process.terminate()
    }
    cleanupProcess()
    restoreOriginalOutput()
    runState = .stopped
    stopping = false
  }

  private func requestAudioPermission(completion: @escaping @MainActor (Bool) -> Void) {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      completion(true)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        Task { @MainActor in completion(granted) }
      }
    default:
      completion(false)
    }
  }

  private func launch(seconds: Double, output: AudioDevice) {
    do {
      let devices = try AudioDevices.all()
      guard let cable = AudioDevices.vbCable(in: devices) else {
        isVBCableInstalled = false
        throw AudioDeviceError.deviceNotFound("VB-Cable")
      }

      guard let soxURL = Self.soxExecutableURL() else {
        throw NSError(
          domain: "AudioDelay",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "The bundled SoX audio engine is missing."]
        )
      }

      originalOutputID = try AudioDevices.defaultOutputID()
      try AudioDevices.setDefaultOutput(cable.id)

      let value = DelayValidation.commandValue(seconds)
      let process = Process()
      let pipe = Pipe()
      process.executableURL = soxURL
      process.arguments = [
        "-q",
        "-t", "coreaudio", cable.name,
        "-r", "48000", "-c", "2",
        "-t", "coreaudio", output.name,
        "delay", value, value,
      ]
      process.standardOutput = FileHandle.nullDevice
      process.standardError = pipe
      recentError.removeAll(keepingCapacity: true)
      pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
        let data = handle.availableData
        guard !data.isEmpty else { return }
        Task { @MainActor in self?.appendError(data) }
      }
      process.terminationHandler = { [weak self] process in
        let status = process.terminationStatus
        Task { @MainActor in self?.processEnded(status: status) }
      }

      self.process = process
      errorPipe = pipe
      try process.run()
      beginCountdown(seconds: seconds)
    } catch {
      cleanupProcess()
      restoreOriginalOutput()
      errorMessage = error.localizedDescription
      runState = .stopped
    }
  }

  private func beginCountdown(seconds: Double) {
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

  private func appendError(_ data: Data) {
    recentError.append(data)
    if recentError.count > 32_768 {
      recentError.removeFirst(recentError.count - 32_768)
    }
  }

  private func processEnded(status: Int32) {
    let wasStopping = stopping
    countdownTimer?.invalidate()
    countdownTimer = nil
    countdownDeadline = nil
    countdownDuration = 0
    bufferProgress = 0
    cleanupProcess()
    restoreOriginalOutput()
    runState = .stopped

    if status != 0 && !wasStopping {
      let text = String(data: recentError, encoding: .utf8)?.trimmingCharacters(
        in: .whitespacesAndNewlines)
      errorMessage = text?.isEmpty == false ? text : "The audio engine stopped unexpectedly."
    }
  }

  private func cleanupProcess() {
    errorPipe?.fileHandleForReading.readabilityHandler = nil
    errorPipe = nil
    process = nil
  }

  private func restoreOriginalOutput() {
    guard let originalOutputID else { return }
    try? AudioDevices.setDefaultOutput(originalOutputID)
    self.originalOutputID = nil
  }

  private static func soxExecutableURL() -> URL? {
    let bundled = Bundle.main.resourceURL?.appendingPathComponent("sox")
    if let bundled, FileManager.default.isExecutableFile(atPath: bundled.path) {
      return bundled
    }

    for path in ["/opt/homebrew/bin/sox", "/usr/local/bin/sox"]
    where FileManager.default.isExecutableFile(atPath: path) {
      return URL(fileURLWithPath: path)
    }
    return nil
  }
}
