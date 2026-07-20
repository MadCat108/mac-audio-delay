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
      CommandGroup(after: .appInfo) {
        Button("Check for Updates…") {
          updateManager.checkForUpdates()
        }
        .disabled(updateManager.isChecking)
      }
    }
  }
}

final class AudioDelayAppDelegate: NSObject, NSApplicationDelegate {
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
