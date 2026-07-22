import AppKit
import SwiftUI

struct UpdateAvailableView: View {
  let currentVersion: String
  let availableVersion: String
  let update: () -> Void
  let postpone: () -> Void
  let showOtherOptions: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 14) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .scaledToFit()
          .frame(width: 58, height: 58)
          .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text("A new version is available")
            .font(.title2.weight(.semibold))
          Text("Audio Delay is ready to update.")
            .foregroundStyle(.secondary)
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("CURRENT VERSION")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(currentVersion)
          .font(.body.monospacedDigit())
          .foregroundStyle(.secondary)

        Divider()
          .padding(.vertical, 4)

        Text("NEW VERSION")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.tint)
        Text(availableVersion)
          .font(.title.monospacedDigit().weight(.semibold))
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))

      Text("Audio Delay will close, update itself locally, and reopen automatically.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 10) {
        Button("Other Options…", action: showOtherOptions)
          .buttonStyle(.bordered)

        Spacer()

        Button("Later", action: postpone)
          .buttonStyle(.bordered)

        Button("Update Now", action: update)
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
      }
      .controlSize(.large)
    }
    .padding()
    .frame(width: 440)
  }
}
