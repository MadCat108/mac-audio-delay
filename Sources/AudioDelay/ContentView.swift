import SwiftUI

struct ContentView: View {
  @ObservedObject var model: AudioDelayModel

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 5) {
        Text("Audio Delay")
          .font(.largeTitle.weight(.semibold))
        Text("Play browser audio through VB-CABLE after a fixed delay.")
          .foregroundStyle(.secondary)
      }

      if !model.isVBCableInstalled {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
          VStack(alignment: .leading, spacing: 4) {
            Text("VB-CABLE is not installed")
              .fontWeight(.medium)
            Link(
              "Download it from VB-Audio",
              destination: URL(string: "https://vb-audio.com/Cable/index.htm")!)
          }
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
      }

      Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 14) {
        GridRow {
          Text("Delay")
          HStack(spacing: 8) {
            TextField("90", text: $model.delayText)
              .textFieldStyle(.roundedBorder)
              .frame(width: 90)
              .disabled(model.isRunning)
            Text("seconds")
              .foregroundStyle(.secondary)
          }
        }

        GridRow {
          Text("Play through")
          Picker("Output device", selection: $model.selectedOutputID) {
            Text("Select a device").tag(Optional<UInt32>.none)
            ForEach(model.outputDevices) { device in
              Text(device.name).tag(Optional(device.id))
            }
          }
          .labelsHidden()
          .frame(minWidth: 290)
          .disabled(model.isRunning)
        }
      }

      HStack(spacing: 12) {
        Button("Start") { model.start() }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
          .disabled(model.isRunning || !model.isVBCableInstalled)

        Button("Stop") { model.stop() }
          .buttonStyle(.bordered)
          .disabled(!model.isRunning)

        Spacer()

        Button {
          model.refreshDevices()
        } label: {
          Label("Refresh Devices", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.plain)
        .disabled(model.isRunning)
      }

      HStack(spacing: 8) {
        Circle()
          .fill(model.isRunning ? Color.green : Color.secondary)
          .frame(width: 9, height: 9)
        Text(model.runState.label)
          .fontWeight(.medium)
        Spacer()
      }
      .padding(12)
      .background(.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))

      Text(
        "While running, Audio Delay temporarily routes the Mac’s sound into VB-CABLE. Your original output is restored when you press Stop or quit the app."
      )
      .font(.footnote)
      .foregroundStyle(.secondary)
    }
    .padding(24)
    .frame(width: 560)
    .alert(
      "Audio Delay",
      isPresented: Binding(
        get: { model.errorMessage != nil },
        set: { if !$0 { model.errorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "")
    }
  }
}
