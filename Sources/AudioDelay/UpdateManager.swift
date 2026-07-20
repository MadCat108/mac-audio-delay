import AppKit
import Foundation

@MainActor
final class UpdateManager: ObservableObject {
  @Published private(set) var isChecking = false

  private let automaticCheckInterval: TimeInterval = 24 * 60 * 60
  private let lastCheckKey = "LastSuccessfulUpdateCheck"
  private let versionURL = URL(
    string: "https://raw.githubusercontent.com/MadCat108/mac-audio-delay/main/VERSION"
  )!

  var currentVersionText: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
  }

  func checkForUpdates(interactive: Bool = true) {
    guard !isChecking else { return }
    if !interactive,
      let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date,
      Date().timeIntervalSince(lastCheck) < automaticCheckInterval
    {
      return
    }
    isChecking = true

    Task { [weak self] in
      guard let self else { return }
      defer { isChecking = false }

      do {
        let latest = try await fetchLatestVersion()
        guard let current = AppVersion(currentVersionText) else {
          throw UpdateError.invalidInstalledVersion
        }
        UserDefaults.standard.set(Date(), forKey: lastCheckKey)

        if current < latest {
          presentAvailableUpdate(latest.description)
        } else if interactive {
          presentUpToDate()
        }
      } catch {
        if interactive {
          presentFailure(error.localizedDescription)
        }
      }
    }
  }

  private func fetchLatestVersion() async throws -> AppVersion {
    var request = URLRequest(url: versionURL)
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.timeoutInterval = 15

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
      (200..<300).contains(httpResponse.statusCode)
    else {
      throw UpdateError.unavailable
    }

    guard data.count <= 64,
      let text = String(data: data, encoding: .utf8),
      let version = AppVersion(text)
    else {
      throw UpdateError.invalidLatestVersion
    }
    return version
  }

  private func presentAvailableUpdate(_ version: String) {
    let alert = NSAlert()
    alert.messageText = "Audio Delay \(version) is available"
    alert.informativeText =
      "Install the update now? Audio Delay will close, rebuild locally, and reopen automatically."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Install Update")
    alert.addButton(withTitle: "Later")

    if alert.runModal() == .alertFirstButtonReturn {
      launchUpdater()
    }
  }

  private func presentUpToDate() {
    let alert = NSAlert()
    alert.messageText = "Audio Delay is up to date"
    alert.informativeText = "You’re using version \(currentVersionText)."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  private func presentFailure(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Couldn’t check for updates"
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
  }

  private func launchUpdater() {
    do {
      guard let bundledScript = Bundle.main.url(forResource: "update", withExtension: "sh") else {
        throw UpdateError.missingUpdater
      }
      guard let bundledUpdater = Bundle.main.url(
        forResource: "Audio Delay Updater",
        withExtension: "app"
      ) else {
        throw UpdateError.missingUpdater
      }

      let updateDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("audio-delay-update-\(UUID().uuidString)", isDirectory: true)
      try FileManager.default.createDirectory(
        at: updateDirectory,
        withIntermediateDirectories: true
      )
      let temporaryScript = updateDirectory.appendingPathComponent("update.sh")
      let temporaryUpdater = updateDirectory.appendingPathComponent("Audio Delay Updater.app")
      try FileManager.default.copyItem(at: bundledScript, to: temporaryScript)
      try FileManager.default.copyItem(at: bundledUpdater, to: temporaryUpdater)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: temporaryScript.path
      )

      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = true
      configuration.addsToRecentItems = false
      configuration.arguments = [
        temporaryScript.path,
        temporaryUpdater.appendingPathComponent("Contents/Resources/AppIcon.icns").path,
      ]
      NSWorkspace.shared.openApplication(
        at: temporaryUpdater,
        configuration: configuration
      ) { [weak self] _, error in
        DispatchQueue.main.async {
          if let error {
            try? FileManager.default.removeItem(at: updateDirectory)
            self?.presentFailure(error.localizedDescription)
          } else {
            NSApp.terminate(nil)
          }
        }
      }
    } catch {
      presentFailure(error.localizedDescription)
    }
  }
}

private enum UpdateError: LocalizedError {
  case unavailable
  case invalidInstalledVersion
  case invalidLatestVersion
  case missingUpdater

  var errorDescription: String? {
    switch self {
    case .unavailable:
      return "GitHub did not return a valid update response."
    case .invalidInstalledVersion:
      return "The installed application version is invalid."
    case .invalidLatestVersion:
      return "GitHub returned an invalid version number."
    case .missingUpdater:
      return "The bundled update helper is missing."
    }
  }
}
