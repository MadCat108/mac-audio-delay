enum AudioCaptureAccessState: String {
  case notChecked = "Not checked this session"
  case available = "Available when last checked"
  case permissionRequired = "Permission required"
}

enum AudioDelayStatus: Equatable {
  case stopped
  case buffering(Int)
  case playing
  case noAudioDetected
  case waitingForSource(String)
  case outputDisconnected
  case permissionRequired

  var label: String {
    switch self {
    case .stopped:
      return "Stopped"
    case .buffering(let seconds):
      return "Buffering — \(seconds) seconds remaining"
    case .playing:
      return "Playing"
    case .noAudioDetected:
      return "No Audio Detected"
    case .waitingForSource(let name):
      return "Waiting for \(name) to reopen"
    case .outputDisconnected:
      return "Output Disconnected"
    case .permissionRequired:
      return "Permission Required"
    }
  }
}
