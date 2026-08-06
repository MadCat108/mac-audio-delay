import AppKit
import SwiftUI

struct ContentView: View {
  @ObservedObject var model: AudioDelayModel
  private let delayPresets = [0, 15, 30, 60, 90, 120, 180]

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 16) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .scaledToFit()
          .frame(width: 68, height: 68)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 5) {
          Text("Audio Delay")
            .font(.largeTitle.weight(.semibold))
          Text("Play your Mac's audio after a fixed delay.")
            .foregroundStyle(.secondary)
        }

        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal)

      VStack(alignment: .leading, spacing: 14) {
        Label("Delay", systemImage: "timer")
          .font(.headline)

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            TextField("90", text: $model.delayText)
              .textFieldStyle(.roundedBorder)
              .font(.title2.monospacedDigit())
              .frame(width: 100)
              .disabled(model.isRunning)
            Text("seconds")
              .foregroundStyle(.secondary)
          }

          Spacer()

          HStack(spacing: 6) {
            ForEach(delayPresets, id: \.self) { seconds in
              Button("\(seconds)") {
                model.delayText = String(seconds)
              }
              .buttonStyle(.bordered)
              .controlSize(.small)
              .disabled(model.isRunning)
            }
          }
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

      VStack(alignment: .leading, spacing: 14) {
        Label("Delay audio from", systemImage: "waveform")
          .font(.headline)

        HStack(spacing: 10) {
          AudioSourcePicker(
            selection: $model.selectedSource,
            applications: model.sourceApplications,
            disabled: model.isRunning,
            onOpen: model.refreshApplications
          )
          .frame(maxWidth: .infinity)

          Button {
            model.refreshApplications()
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .help("Refresh running applications")
          .disabled(model.isRunning)
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

      VStack(alignment: .leading, spacing: 14) {
        Label("Play through", systemImage: "speaker.wave.2")
          .font(.headline)

        HStack(spacing: 10) {
          Picker("Output device", selection: $model.selectedOutputID) {
            Text("Select a device").tag(Optional<UInt32>.none)
            ForEach(model.outputDevices) { device in
              Text(device.name).tag(Optional(device.id))
            }
          }
          .labelsHidden()
          .frame(maxWidth: .infinity)
          .disabled(model.isRunning)

          Button {
            model.refreshDevices()
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .help("Refresh audio devices")
          .disabled(model.isRunning)
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

      Button {
        if model.isRunning {
          model.stop()
        } else {
          model.start()
        }
      } label: {
        Label(
          model.isRunning
            ? (isRoutingOnly ? "Stop Audio Routing" : "Stop Audio Delay")
            : (isRoutingOnly ? "Start Audio Routing" : "Start Audio Delay"),
          systemImage: model.isRunning ? "stop.fill" : "play.fill"
        )
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .tint(model.isRunning ? .red : .accentColor)
      .keyboardShortcut(.defaultAction)
      .disabled(!model.isRunning && model.selectedOutputID == nil)
      .padding(.horizontal)

      VStack(alignment: .leading, spacing: 10) {
        if isBuffering {
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              Capsule()
                .fill(.secondary.opacity(0.16))
              Capsule()
                .fill(
                  LinearGradient(
                    colors: [.cyan, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .frame(width: geometry.size.width * model.bufferProgress)
            }
          }
          .frame(height: 8)
          .animation(.linear(duration: 0.25), value: model.bufferProgress)
          .accessibilityLabel("Audio buffer")
          .accessibilityValue("\(Int(model.bufferProgress * 100)) percent")
        }

        HStack(spacing: 8) {
          Image(systemName: statusSymbol)
            .foregroundStyle(statusColor)
            .frame(width: 14)
          Text(statusLabel)
            .fontWeight(.medium)
            .contentTransition(.numericText())
          Spacer()
          if model.isRunning {
            StereoPeakMeter(peak: meterPeak)
              .transition(.opacity.combined(with: .move(edge: .trailing)))
          }
        }
        .animation(.easeOut(duration: 0.2), value: model.runState)

        if model.noAudioDetected {
          Divider()

          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.yellow)
            Text("No source audio detected. Start audio in the selected source, or check System Audio Recording permission.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Privacy Settings") {
              AudioCapturePermissionSettings.open()
            }
            .controlSize(.small)
          }
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .animation(.easeOut(duration: 0.2), value: model.noAudioDetected)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
      .padding(.horizontal)

      Label(
        footerText,
        systemImage: "info.circle"
      )
      .font(.footnote)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal)
    }
    .frame(width: 528)
    .padding(.horizontal)
    .padding(.vertical, 24)
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
    .alert(
      "System Audio Permission Needed",
      isPresented: $model.needsAudioCapturePermission
    ) {
      Button("Open Privacy Settings") {
        AudioCapturePermissionSettings.open()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Audio Delay only needs access to system audio. It does not request screen or microphone access. Enable Audio Delay under System Audio Recording Only, then press Start again."
      )
    }
  }

  private var isBuffering: Bool {
    if case .waiting = model.runState { return true }
    return false
  }

  private var meterPeak: StereoPeak {
    isBuffering ? model.inputPeakLevels : model.peakLevels
  }

  private var statusSymbol: String {
    if model.noAudioDetected { return "exclamationmark.triangle.fill" }
    switch model.runState {
    case .stopped: return "checkmark.circle.fill"
    case .waiting: return "hourglass"
    case .running: return "play.fill"
    }
  }

  private var statusLabel: String {
    model.noAudioDetected ? "No Audio Detected" : model.runState.label
  }

  private var statusColor: Color {
    if model.noAudioDetected { return .yellow }
    switch model.runState {
    case .stopped: return .secondary
    case .waiting: return .blue
    case .running: return .green
    }
  }

  private var footerText: String {
    if isRoutingOnly {
      if let applicationName = model.selectedSourceApplicationName {
        return "\(applicationName) is routed directly to the selected output. Other Mac audio plays normally."
      }
      return "All Mac audio is routed directly to the selected output. Press Stop to end routing."
    }
    if let applicationName = model.selectedSourceApplicationName {
      return "Only \(applicationName) is delayed while Playing. Other Mac audio plays normally."
    }
    return "All Mac audio is delayed while Playing. Press Stop to return to normal playback."
  }

  private var isRoutingOnly: Bool {
    DelayValidation.parse(model.delayText) == 0
  }
}