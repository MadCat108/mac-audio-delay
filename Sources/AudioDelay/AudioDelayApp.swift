import AppKit
import SwiftUI

@main
struct AudioDelayApp: App {
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
