import AppKit
import SwiftUI

@main
struct AudioDelayApp: App {
  @NSApplicationDelegateAdaptor(AudioDelayAppDelegate.self) private var appDelegate
  @StateObject private var model = AudioDelayModel()
  @StateObject private var updateManager = UpdateManager()

  var body: some Scene {
    WindowGroup {
      ContentView(model: model)
        .background {
          MainWindowAccessor { window in
            appDelegate.configureMainWindow(window, model: model)
          }
        }
        .task {
          updateManager.checkForUpdates(interactive: false)
        }
        .onReceive(
          NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        ) { _ in
          model.stop()
        }
    }
    .windowResizability(.contentSize)
    .commands {
      CommandGroup(replacing: .newItem) {}
      AudioDelayCommands(updateManager: updateManager)
    }

    Window("About Audio Delay", id: "about") {
      AboutView(model: model, updateManager: updateManager)
    }
    .windowResizability(.contentSize)
    .defaultPosition(.center)
  }
}

private struct AudioDelayCommands: Commands {
  @Environment(\.openWindow) private var openWindow
  @ObservedObject var updateManager: UpdateManager

  var body: some Commands {
    CommandGroup(replacing: .appInfo) {
      Button("About Audio Delay") {
        openWindow(id: "about")
      }
    }

    CommandGroup(after: .appInfo) {
      Button("Check for Updates…") {
        updateManager.checkForUpdates()
      }
      .disabled(updateManager.isChecking)
    }
  }
}

private struct MainWindowAccessor: NSViewRepresentable {
  let configure: (NSWindow) -> Void

  func makeNSView(context: Context) -> WindowAccessView {
    WindowAccessView(configure: configure)
  }

  func updateNSView(_ nsView: WindowAccessView, context: Context) {
    nsView.configure = configure
    nsView.configureWindowIfAvailable()
  }

  final class WindowAccessView: NSView {
    var configure: (NSWindow) -> Void

    init(configure: @escaping (NSWindow) -> Void) {
      self.configure = configure
      super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      configureWindowIfAvailable()
    }

    func configureWindowIfAvailable() {
      guard let window else { return }
      configure(window)
    }
  }
}

final class AudioDelayAppDelegate: NSObject, NSApplicationDelegate {
  private weak var model: AudioDelayModel?
  private weak var mainWindow: NSWindow?

  func configureMainWindow(_ window: NSWindow, model: AudioDelayModel) {
    self.model = model
    mainWindow = window

    guard let closeButton = window.standardWindowButton(.closeButton) else {
      return
    }
    closeButton.target = self
    closeButton.action = #selector(closeMainWindow)
  }

  @MainActor
  @objc private func closeMainWindow() {
    guard let model else {
      NSApp.terminate(nil)
      return
    }

    if model.isRunning {
      let alert = NSAlert()
      alert.alertStyle = .warning
      alert.icon = NSApp.applicationIconImage
      alert.messageText = "Quit Audio Delay?"
      alert.informativeText =
        "Audio delay is active. Quitting will stop delayed playback and return "
        + "the source audio to its normal, undelayed system output."
      alert.addButton(withTitle: "Quit")
      alert.addButton(withTitle: "Cancel")

      if alert.runModal() != .alertFirstButtonReturn {
        mainWindow?.makeKeyAndOrderFront(nil)
        return
      }

      model.stop()
    }

    NSApp.terminate(nil)
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    let applicationWindows = sender.windows.filter(\.canBecomeMain)

    for window in applicationWindows where window.isMiniaturized {
      window.deminiaturize(nil)
    }

    applicationWindows.first?.makeKeyAndOrderFront(nil)
    sender.activate(ignoringOtherApps: true)
    return true
  }
}
