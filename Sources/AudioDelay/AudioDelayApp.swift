import AppKit
import SwiftUI

@main
struct AudioDelayApp: App {
  @StateObject private var model = AudioDelayModel()

  var body: some Scene {
    WindowGroup {
      ContentView(model: model)
        .onReceive(
          NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
        ) { _ in
          model.stop()
        }
    }
    .windowResizability(.contentSize)
    .commands {
      CommandGroup(replacing: .newItem) {}
    }
  }
}
