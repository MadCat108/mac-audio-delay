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
    let currentVersion = CommandLine.arguments.count >= 4 ? CommandLine.arguments[3] : "Unknown"
    let availableVersion = CommandLine.arguments.count >= 5 ? CommandLine.arguments[4] : "Latest"
    let icon = NSImage(contentsOfFile: iconPath) ?? NSApp.applicationIconImage
    if let icon {
      NSApp.applicationIconImage = icon
    }

    let controller = UpdaterWindowController(
      icon: icon,
      currentVersion: currentVersion,
      availableVersion: availableVersion
    )
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
  private let terminalRetryButton = NSButton(title: "Retry in Terminal…", target: nil, action: nil)
  private let showLogButton = NSButton(title: "Show Log", target: nil, action: nil)
  private let closeButton = NSButton(title: "Close", target: nil, action: nil)
  private var process: Process?
  private var outputPipe: Pipe?
  private var pendingOutput = ""
  private var failed = false
  private var toolchainFailureDetected = false
  private var toolchainRepairAvailable = false
  private var toolchainVersions: [String] = []
  private var activityTimer: Timer?
  private var stageStartedAt = Date()
  private var stageDetail = ""

  private let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/Audio Delay Update.log")

  init(icon: NSImage?, currentVersion: String, availableVersion: String) {
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
    buildInterface(
      icon: icon,
      currentVersion: currentVersion,
      availableVersion: availableVersion
    )
  }

  required init?(coder: NSCoder) {
    nil
  }

  func start(scriptURL: URL) {
    updateStage(progress: 4, status: "Preparing update…", detail: "Starting the update helper")
    startActivityTimer()

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
      activityTimer?.invalidate()
      activityTimer = nil
      fail("The updater could not be launched.", detail: error.localizedDescription)
    }
  }

  private func startActivityTimer() {
    activityTimer?.invalidate()
    activityTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.process != nil, !self.failed else { return }
        let elapsed = max(0, Int(Date().timeIntervalSince(self.stageStartedAt)))
        guard elapsed >= 8 else { return }

        let elapsedText: String
        if elapsed < 60 {
          elapsedText = "\(elapsed)s elapsed"
        } else {
          elapsedText = "\(elapsed / 60)m \(elapsed % 60)s elapsed"
        }
        self.detailLabel.stringValue = "\(self.stageDetail)\nStill working — \(elapsedText)"
      }
    }
  }

  private func buildInterface(
    icon: NSImage?,
    currentVersion: String,
    availableVersion: String
  ) {
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
    iconView.wantsLayer = true
    iconView.layer?.cornerRadius = 14
    iconView.layer?.cornerCurve = .continuous
    iconView.layer?.masksToBounds = true
    iconView.translatesAutoresizingMaskIntoConstraints = false

    let titleLabel = NSTextField(labelWithString: "Updating Audio Delay")
    titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)

    let subtitleLabel = NSTextField(
      wrappingLabelWithString: "The app is being rebuilt locally from its public source."
    )
    subtitleLabel.font = .systemFont(ofSize: 13)
    subtitleLabel.textColor = .secondaryLabelColor

    let versionLabel = NSTextField(labelWithAttributedString: Self.versionTransitionText(
      current: currentVersion,
      available: availableVersion
    ))

    let headingStack = NSStackView(views: [titleLabel, subtitleLabel, versionLabel])
    headingStack.orientation = .vertical
    headingStack.alignment = .leading
    headingStack.spacing = 5
    headingStack.setCustomSpacing(9, after: subtitleLabel)

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
    detailLabel.maximumNumberOfLines = 10

    showLogButton.target = self
    showLogButton.action = #selector(showLog)
    showLogButton.isHidden = true
    terminalRetryButton.target = self
    terminalRetryButton.action = #selector(retryInTerminal)
    terminalRetryButton.bezelStyle = .rounded
    terminalRetryButton.isHidden = true
    closeButton.target = self
    closeButton.action = #selector(closeUpdater)
    closeButton.bezelStyle = .rounded
    closeButton.isHidden = true

    let buttons = NSStackView(views: [terminalRetryButton, showLogButton, closeButton])
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

  private static func versionTransitionText(
    current: String,
    available: String
  ) -> NSAttributedString {
    let result = NSMutableAttributedString(
      string: "Updating from ",
      attributes: [
        .font: NSFont.systemFont(ofSize: 13),
        .foregroundColor: NSColor.secondaryLabelColor,
      ]
    )
    result.append(NSAttributedString(
      string: current,
      attributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
        .foregroundColor: NSColor.labelColor,
      ]
    ))
    result.append(NSAttributedString(
      string: "  →  ",
      attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: NSColor.tertiaryLabelColor,
      ]
    ))
    result.append(NSAttributedString(
      string: available,
      attributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
        .foregroundColor: NSColor.controlAccentColor,
      ]
    ))
    return result
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
    case lower.hasPrefix("audio delay build cannot proceed"):
      toolchainFailureDetected = true
      updateStage(
        progress: 32,
        status: "Audio Delay build cannot proceed",
        detail: "Apple’s installed build tools do not match."
      )
    case toolchainFailureDetected && lower == "guided repair: available":
      toolchainRepairAvailable = true
    case toolchainFailureDetected && (
      lower.hasPrefix("macos:") ||
        lower.hasPrefix("swift compiler:") ||
        lower.hasPrefix("macos sdk:") ||
        lower.hasPrefix("swift package manager:")
    ):
      toolchainVersions.append(line)
      updateStage(
        progress: 32,
        status: "Audio Delay build cannot proceed",
        detail: toolchainVersions.joined(separator: "\n")
      )
    case lower.contains("audio delay update started"):
      updateStage(progress: 7, status: "Preparing update…", detail: "Connecting securely to GitHub")
    case lower == "audio delay stage: downloading source":
      updateStage(
        progress: 12,
        status: "Downloading latest source…",
        detail: "Receiving the public source archive from GitHub"
      )
    case lower.contains("downloading audio delay source"):
      updateStage(progress: 14, status: "Downloading latest source…", detail: line)
    case lower == "audio delay stage: extracting source":
      updateStage(
        progress: 18,
        status: "Extracting downloaded source…",
        detail: "Unpacking the source archive"
      )
    case lower == "audio delay stage: source ready":
      updateStage(
        progress: 22,
        status: "Source ready",
        detail: "The downloaded source was extracted and validated"
      )
    case lower.contains("downloaded audio delay version"):
      updateStage(progress: 23, status: line, detail: "Preparing installation on this Mac")
    case lower == "audio delay stage: checking system":
      updateStage(
        progress: 25,
        status: "Checking this Mac…",
        detail: "Reading the macOS version and processor architecture"
      )
    case lower == "audio delay stage: closing running app":
      updateStage(
        progress: 27,
        status: "Closing the previous version…",
        detail: "Waiting for Audio Delay to stop cleanly"
      )
    case lower == "audio delay stage: checking build tools":
      updateStage(
        progress: 30,
        status: "Checking Apple build tools…",
        detail: "Verifying the Swift compiler and macOS SDK; this can take a moment"
      )
    case lower.contains("command line tools"):
      updateStage(progress: 31, status: "Checking Apple build tools…", detail: line)
    case lower == "audio delay stage: build tools ready":
      updateStage(
        progress: 35,
        status: "Apple build tools ready",
        detail: "The Swift compiler and macOS SDK passed verification"
      )
    case lower == "audio delay stage: starting local build":
      updateStage(
        progress: 38,
        status: "Starting local build…",
        detail: "Preparing the native audio engine and application"
      )
    case lower.contains("building audio delay locally"):
      updateStage(progress: 39, status: "Starting local build…", detail: line)
    case lower == "audio delay stage: preparing build":
      updateStage(
        progress: 41,
        status: "Preparing Swift build…",
        detail: "Planning the release build"
      )
    case lower == "audio delay stage: compiling application":
      updateStage(
        progress: 45,
        status: "Compiling Audio Delay…",
        detail: "Building locally; the first build can take several minutes"
      )
    case lower.contains("building for production"):
      updateStage(progress: 47, status: "Compiling Audio Delay…", detail: "Swift production build is running")
    case lower.contains("compiling audiodelayupdater"):
      updateStage(progress: 76, status: "Compiling update helper…", detail: line)
    case lower.contains("linking audiodelayupdater"):
      updateStage(progress: 82, status: "Linking update helper…", detail: line)
    case lower.contains("compiling audiodelay"):
      updateStage(progress: 56, status: "Compiling Audio Delay…", detail: line)
    case lower.contains("linking audiodelay"):
      updateStage(progress: 64, status: "Linking Audio Delay…", detail: line)
    case lower == "audio delay stage: application compiled":
      updateStage(progress: 68, status: "Audio Delay compiled", detail: "Main application build completed")
    case lower == "audio delay stage: compiling updater":
      updateStage(progress: 72, status: "Compiling update helper…", detail: "Building the in-app updater")
    case lower.contains("build of product 'audiodelayupdater'"):
      updateStage(progress: 84, status: "Update helper compiled", detail: line)
    case lower == "audio delay stage: updater compiled":
      updateStage(progress: 85, status: "Update helper compiled", detail: "Both executable components are ready")
    case lower.contains("build of product 'audiodelay'"):
      updateStage(progress: 68, status: "Audio Delay compiled", detail: line)
    case lower == "audio delay stage: packaging application":
      updateStage(progress: 87, status: "Packaging application…", detail: "Assembling the macOS app bundle and resources")
    case lower == "audio delay stage: signing application":
      updateStage(progress: 90, status: "Signing application…", detail: "Applying the local code signature")
    case lower == "audio delay stage: verifying application":
      updateStage(progress: 93, status: "Verifying application…", detail: "Checking bundle integrity and signature")
    case lower.hasPrefix("built:"):
      updateStage(progress: 95, status: "Application ready", detail: line)
    case lower == "audio delay stage: installing application":
      updateStage(progress: 97, status: "Installing update…", detail: "Replacing the previous user installation")
    case lower.hasPrefix("installed:"):
      updateStage(progress: 99, status: "Update installed", detail: line)
    case lower == "audio delay stage: installation complete":
      updateStage(progress: 99, status: "Update installed", detail: "Finalizing the update")
    case lower.contains("update completed"):
      updateStage(progress: 100, status: "Update complete", detail: "Opening Audio Delay…")
    default:
      break
    }
  }

  private func updateStage(progress value: Double, status: String, detail: String) {
    guard !failed else { return }
    if statusLabel.stringValue != status {
      stageStartedAt = Date()
    }
    stageDetail = detail
    progress.animator().doubleValue = max(progress.doubleValue, value)
    statusLabel.stringValue = status
    detailLabel.stringValue = detail
  }

  private func finish(status: Int32) {
    activityTimer?.invalidate()
    activityTimer = nil
    outputPipe?.fileHandleForReading.readabilityHandler = nil
    outputPipe = nil
    process = nil

    if !pendingOutput.isEmpty {
      processOutputLine(pendingOutput.trimmingCharacters(in: .whitespacesAndNewlines))
      pendingOutput = ""
    }

    guard status == 0 else {
      if toolchainFailureDetected {
        presentToolchainFailure()
        return
      }
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

  private func presentToolchainFailure() {
    window?.setContentSize(NSSize(width: 660, height: 420))
    window?.center()

    let versionText = toolchainVersions.isEmpty
      ? "Tool versions are available in the diagnostic log."
      : toolchainVersions.joined(separator: "\n")
    let detail: String
    if toolchainRepairAvailable {
      detail = """
        Apple’s installed Command Line Tools are incomplete or contain mixed files.
        \(versionText)
        The guided Terminal repair removes only /Library/Developer/CommandLineTools,
        opens Apple’s installer, then continues the Audio Delay installation.
        """
      terminalRetryButton.title = "Repair in Terminal…"
    } else {
      detail = """
        Apple’s Swift compiler could not use the installed macOS SDK.
        \(versionText)
        This failure was not recognized as safe for automatic repair. Use Retry in Terminal to view the complete diagnostic.
        """
    }

    fail("Audio Delay build cannot proceed", detail: detail)
  }

  private func fail(_ status: String, detail: String) {
    failed = true
    statusLabel.stringValue = status
    statusLabel.textColor = .systemRed
    detailLabel.stringValue = detail
    terminalRetryButton.isHidden = false
    showLogButton.isHidden = false
    closeButton.isHidden = false
    window?.styleMask.insert(.closable)
    NSApp.requestUserAttention(.criticalRequest)
  }

  @objc private func showLog() {
    NSWorkspace.shared.activateFileViewerSelecting([logURL])
  }

  @objc private func retryInTerminal() {
    let alert = NSAlert()
    if toolchainRepairAvailable {
      alert.messageText = "Repair Apple Command Line Tools in Terminal?"
      alert.informativeText =
        "Terminal will explain the repair, request confirmation, and let macOS request the administrator password directly. Audio Delay will continue installing after Apple’s installer finishes."
    } else {
      alert.messageText = "Retry the update in Terminal?"
      alert.informativeText =
        "Terminal will download the official public source, rebuild Audio Delay locally, and show the complete installation output."
    }
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Open Terminal")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return }

    do {
      let commandURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("Audio-Delay-Manual-Update-\(UUID().uuidString).command")
      let startingMessage = toolchainRepairAvailable
        ? "Starting the guided Apple tools repair and Audio Delay update..."
        : "Starting the Audio Delay manual update..."
      let command = """
        #!/bin/zsh
        set -o pipefail

        echo "\(startingMessage)"
        curl -fsSL https://raw.githubusercontent.com/MadCat108/mac-audio-delay/main/bootstrap.sh | zsh
        update_exit=$?

        echo
        if (( update_exit == 0 )); then
          echo "Audio Delay was updated successfully."
        else
          echo "The update failed with status $update_exit."
        fi
        echo "Press any key to close this Terminal window."
        read -k 1
        echo
        exit $update_exit
        """

      try command.write(to: commandURL, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: commandURL.path
      )
      guard NSWorkspace.shared.open(commandURL) else {
        throw NSError(
          domain: "AudioDelayUpdater",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "macOS could not open the Terminal command."]
        )
      }
      detailLabel.stringValue = toolchainRepairAvailable
        ? "The guided repair is now running in Terminal."
        : "The manual installer is now running in Terminal."
    } catch {
      detailLabel.stringValue = "Could not open Terminal: \(error.localizedDescription)"
      NSApp.requestUserAttention(.criticalRequest)
    }
  }

  @objc private func closeUpdater() {
    NSApp.terminate(nil)
  }
}