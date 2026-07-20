import AppKit
import Foundation

@main
struct AudioDelayUpdaterMain {
  static func main() {
    let application = NSApplication.shared
    let delegate = UpdaterApplicationDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.regular)
    application.run()
  }
}

@MainActor
private final class UpdaterApplicationDelegate: NSObject, NSApplicationDelegate {
  private var windowController: UpdaterWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard CommandLine.arguments.count >= 2 else {
      showLaunchFailure("The update script path is missing.")
      return
    }

    let scriptURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let iconPath = CommandLine.arguments.count >= 3 ? CommandLine.arguments[2] : ""
    let icon = NSImage(contentsOfFile: iconPath) ?? NSApp.applicationIconImage
    if let icon {
      NSApp.applicationIconImage = icon
    }

    let controller = UpdaterWindowController(icon: icon)
    windowController = controller
    controller.showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
    controller.start(scriptURL: scriptURL)
  }

  private func showLaunchFailure(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Audio Delay update could not start"
    alert.informativeText = message
    alert.alertStyle = .critical
    alert.runModal()
    NSApp.terminate(nil)
  }
}

@MainActor
private final class UpdaterWindowController: NSWindowController {
  private let progress = NSProgressIndicator()
  private let statusLabel = NSTextField(labelWithString: "Preparing update…")
  private let detailLabel = NSTextField(wrappingLabelWithString: "")
  private let showLogButton = NSButton(title: "Show Log", target: nil, action: nil)
  private let closeButton = NSButton(title: "Close", target: nil, action: nil)
  private var process: Process?
  private var outputPipe: Pipe?
  private var pendingOutput = ""
  private var failed = false

  private let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/Audio Delay Update.log")

  init(icon: NSImage?) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 540, height: 286),
      styleMask: [.titled, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Audio Delay Update"
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.center()

    super.init(window: window)
    buildInterface(icon: icon)
  }

  required init?(coder: NSCoder) {
    nil
  }

  func start(scriptURL: URL) {
    updateStage(progress: 4, status: "Preparing update…", detail: "Starting the update helper")

    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = [scriptURL.path]
    process.environment = ProcessInfo.processInfo.environment.merging([
      "AUDIO_DELAY_UPDATE_FOREGROUND": "1",
      "AUDIO_DELAY_NO_OPEN": "1",
    ]) { _, new in new }
    process.standardOutput = pipe
    process.standardError = pipe

    pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }
      DispatchQueue.main.async {
        self?.consume(data)
      }
    }
    process.terminationHandler = { [weak self] process in
      DispatchQueue.main.async {
        self?.finish(status: process.terminationStatus)
      }
    }

    self.process = process
    outputPipe = pipe

    do {
      try process.run()
    } catch {
      fail("The updater could not be launched.", detail: error.localizedDescription)
    }
  }

  private func buildInterface(icon: NSImage?) {
    guard let contentView = window?.contentView else { return }

    let background = NSVisualEffectView()
    background.material = .contentBackground
    background.blendingMode = .behindWindow
    background.state = .active
    background.translatesAutoresizingMaskIntoConstraints = false
    contentView.addSubview(background)

    let iconView = NSImageView()
    iconView.image = icon ?? NSImage(
      systemSymbolName: "waveform.badge.plus",
      accessibilityDescription: "Audio Delay"
    )
    iconView.imageScaling = .scaleProportionallyUpOrDown
    iconView.translatesAutoresizingMaskIntoConstraints = false

    let titleLabel = NSTextField(labelWithString: "Updating Audio Delay")
    titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)

    let subtitleLabel = NSTextField(
      wrappingLabelWithString: "The app is being rebuilt locally from its public source."
    )
    subtitleLabel.font = .systemFont(ofSize: 13)
    subtitleLabel.textColor = .secondaryLabelColor

    let headingStack = NSStackView(views: [titleLabel, subtitleLabel])
    headingStack.orientation = .vertical
    headingStack.alignment = .leading
    headingStack.spacing = 5

    let header = NSStackView(views: [iconView, headingStack])
    header.orientation = .horizontal
    header.alignment = .centerY
    header.spacing = 16

    progress.style = .bar
    progress.isIndeterminate = false
    progress.minValue = 0
    progress.maxValue = 100
    progress.doubleValue = 4
    progress.controlSize = .large

    statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
    detailLabel.font = .systemFont(ofSize: 12)
    detailLabel.textColor = .secondaryLabelColor
    detailLabel.maximumNumberOfLines = 2

    showLogButton.target = self
    showLogButton.action = #selector(showLog)
    showLogButton.isHidden = true
    closeButton.target = self
    closeButton.action = #selector(closeUpdater)
    closeButton.bezelStyle = .rounded
    closeButton.isHidden = true

    let buttons = NSStackView(views: [showLogButton, closeButton])
    buttons.orientation = .horizontal
    buttons.alignment = .centerY
    buttons.spacing = 8

    let statusSpacer = NSView()
    statusSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    let statusRow = NSStackView(views: [statusLabel, statusSpacer, buttons])
    statusRow.orientation = .horizontal
    statusRow.alignment = .centerY
    statusRow.spacing = 10

    let stack = NSStackView(views: [header, progress, statusRow, detailLabel])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 14
    stack.translatesAutoresizingMaskIntoConstraints = false
    background.addSubview(stack)

    NSLayoutConstraint.activate([
      background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
      background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
      background.topAnchor.constraint(equalTo: contentView.topAnchor),
      background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

      iconView.widthAnchor.constraint(equalToConstant: 64),
      iconView.heightAnchor.constraint(equalToConstant: 64),
      header.widthAnchor.constraint(equalTo: stack.widthAnchor),
      progress.widthAnchor.constraint(equalTo: stack.widthAnchor),
      statusRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
      detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),

      stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 28),
      stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -28),
      stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 28),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -24),
    ])
  }

  private func consume(_ data: Data) {
    pendingOutput += String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\r", with: "\n")
    var lines = pendingOutput.components(separatedBy: "\n")
    pendingOutput = lines.removeLast()

    for line in lines {
      processOutputLine(line.trimmingCharacters(in: .whitespacesAndNewlines))
    }
  }

  private func processOutputLine(_ line: String) {
    guard !line.isEmpty else { return }
    let lower = line.lowercased()

    switch true {
    case lower.contains("audio delay update started"):
      updateStage(progress: 7, status: "Preparing update…", detail: "Connecting securely to GitHub")
    case lower.contains("downloading audio delay source"):
      updateStage(progress: 14, status: "Downloading latest source…", detail: line)
    case lower.contains("downloaded audio delay version"):
      updateStage(progress: 20, status: line, detail: "Verifying the downloaded source")
    case lower.contains("command line tools"):
      updateStage(progress: 22, status: "Checking Apple build tools…", detail: line)
    case lower.contains("vb-cable"):
      updateStage(progress: 27, status: "Checking VB-CABLE…", detail: line)
    case lower.contains("building audio delay locally"):
      updateStage(progress: 32, status: "Preparing the local build…", detail: line)
    case lower.contains("downloading the official sox"):
      updateStage(progress: 40, status: "Downloading the audio engine…", detail: line)
    case lower.contains("building the minimal coreaudio"):
      updateStage(progress: 56, status: "Building the audio engine…", detail: "This is normally the longest step")
    case lower.contains("building for production"):
      updateStage(progress: 76, status: "Building Audio Delay…", detail: "Compiling the latest application")
    case lower.contains("build of product"):
      updateStage(progress: 88, status: "Finishing the application…", detail: line)
    case lower.hasPrefix("built:"):
      updateStage(progress: 92, status: "Verifying the application…", detail: line)
    case lower.hasPrefix("installed:"):
      updateStage(progress: 97, status: "Installing the update…", detail: line)
    case lower.contains("update completed"):
      updateStage(progress: 100, status: "Update complete", detail: "Opening Audio Delay…")
    default:
      break
    }
  }

  private func updateStage(progress value: Double, status: String, detail: String) {
    guard !failed else { return }
    progress.animator().doubleValue = max(progress.doubleValue, value)
    statusLabel.stringValue = status
    detailLabel.stringValue = detail
  }

  private func finish(status: Int32) {
    outputPipe?.fileHandleForReading.readabilityHandler = nil
    outputPipe = nil
    process = nil

    if !pendingOutput.isEmpty {
      processOutputLine(pendingOutput.trimmingCharacters(in: .whitespacesAndNewlines))
      pendingOutput = ""
    }

    guard status == 0 else {
      fail(
        "The update could not be completed.",
        detail: "The diagnostic log has the technical details."
      )
      return
    }

    updateStage(progress: 100, status: "Update complete", detail: "Opening Audio Delay…")
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
      let appURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Applications/Audio Delay.app")
      NSWorkspace.shared.open(appURL)
      NSApp.terminate(nil)
    }
  }

  private func fail(_ status: String, detail: String) {
    failed = true
    statusLabel.stringValue = status
    statusLabel.textColor = .systemRed
    detailLabel.stringValue = detail
    showLogButton.isHidden = false
    closeButton.isHidden = false
    window?.styleMask.insert(.closable)
    NSApp.requestUserAttention(.criticalRequest)
  }

  @objc private func showLog() {
    NSWorkspace.shared.activateFileViewerSelecting([logURL])
  }

  @objc private func closeUpdater() {
    NSApp.terminate(nil)
  }
}
