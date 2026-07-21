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

      Text("Route or delay all Mac audio or a single application for up to one hour.")
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 310)
        .fixedSize(horizontal: false, vertical: true)

      Divider()
        .padding(.horizontal, 8)

      HStack(spacing: 10) {
        Button {
          updateManager.checkForUpdates(reportsResultInline: true)
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

      ZStack {
        if let result = updateManager.inlineCheckResult {
          inlineUpdateResult(result)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .frame(maxWidth: .infinity, minHeight: 26)

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
    .animation(.easeOut(duration: 0.2), value: updateManager.inlineCheckResult)
  }

  @ViewBuilder
  private func inlineUpdateResult(_ result: UpdateManager.InlineCheckResult) -> some View {
    switch result {
    case .upToDate(let version):
      Label("You’re up to date — version \(version).", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    case .failure(let message):
      Label(message, systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
