import AppKit
import SwiftUI

struct AboutView: View {
  @ObservedObject var updateManager: UpdateManager

  private let projectURL = URL(string: "https://github.com/MadCat108/mac-audio-delay")!
  private let licenseURL = URL(
    string: "https://github.com/MadCat108/mac-audio-delay/blob/main/LICENSE"
  )!

  var body: some View {
    VStack(spacing: 18) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .scaledToFit()
        .frame(width: 92, height: 92)
        .accessibilityHidden(true)

      VStack(spacing: 8) {
        Text("Audio Delay")
          .font(.largeTitle.weight(.semibold))

        Text("Version \(updateManager.currentVersionText)")
          .font(.callout.monospacedDigit().weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 11)
          .padding(.vertical, 5)
          .background(.secondary.opacity(0.11), in: Capsule())
      }

      Text("Delay all Mac audio—or one application—by up to one hour.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 310)

      Divider()
        .padding(.horizontal, 8)

      HStack(spacing: 10) {
        Button {
          updateManager.checkForUpdates()
        } label: {
          Label(
            updateManager.isChecking ? "Checking…" : "Check for Updates",
            systemImage: "arrow.triangle.2.circlepath"
          )
        }
        .buttonStyle(.borderedProminent)
        .disabled(updateManager.isChecking)

        Link(destination: projectURL) {
          Label("View on GitHub", systemImage: "arrow.up.right")
        }
        .buttonStyle(.bordered)
      }

      HStack(spacing: 5) {
        Text("Open source")
        Text("·")
          .foregroundStyle(.tertiary)
        Link("MIT License", destination: licenseURL)
      }
      .font(.footnote)
      .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 30)
    .padding(.vertical, 26)
    .frame(width: 410)
  }
}
