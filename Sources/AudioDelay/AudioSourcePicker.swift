import AppKit
import SwiftUI

struct AudioSourcePicker: View {
  @Binding var selection: AudioSourceSelection
  let applications: [AudioApplication]
  let disabled: Bool
  let onOpen: () -> Void

  @State private var isPresented = false
  @State private var searchText = ""
  @FocusState private var searchIsFocused: Bool

  var body: some View {
    Button {
      onOpen()
      searchText = ""
      isPresented = true
    } label: {
      HStack(spacing: 8) {
        selectedIcon
          .frame(width: 18, height: 18)

        Text(selectedTitle)
          .lineLimit(1)

        Spacer(minLength: 8)

        Image(systemName: "chevron.up.chevron.down")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .frame(height: 22)
      .contentShape(Rectangle())
    }
    .buttonStyle(.bordered)
    .disabled(disabled)
    .popover(isPresented: $isPresented, arrowEdge: .bottom) {
      VStack(spacing: 0) {
        HStack(spacing: 8) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)

          TextField("Search audio applications", text: $searchText)
            .textFieldStyle(.plain)
            .focused($searchIsFocused)

          if !searchText.isEmpty {
            Button {
              searchText = ""
            } label: {
              Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear search")
          }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)

        Divider()

        ScrollView {
          LazyVStack(spacing: 3) {
            AudioSourcePickerRow(
              title: "All Mac Audio",
              systemImage: "macbook.and.iphone",
              icon: nil,
              isSelected: selection == .allMacAudio
            ) {
              choose(.allMacAudio)
            }

            Divider()
              .padding(.vertical, 3)

            ForEach(filteredApplications) { application in
              AudioSourcePickerRow(
                title: application.name,
                systemImage: nil,
                icon: application.icon,
                isSelected: selection == .application(application.bundleIdentifier)
              ) {
                choose(.application(application.bundleIdentifier))
              }
            }

            if filteredApplications.isEmpty {
              Text("No matching audio applications")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            }
          }
          .padding(8)
        }
      }
      .frame(width: 340, height: 350)
      .onAppear {
        DispatchQueue.main.async {
          searchIsFocused = true
        }
      }
    }
  }

  private var selectedApplication: AudioApplication? {
    guard case .application(let identifier) = selection else { return nil }
    return applications.first { $0.bundleIdentifier == identifier }
  }

  private var selectedTitle: String {
    selectedApplication?.name ?? "All Mac Audio"
  }

  @ViewBuilder
  private var selectedIcon: some View {
    if let selectedApplication {
      Image(nsImage: selectedApplication.icon)
        .resizable()
        .scaledToFit()
    } else {
      Image(systemName: "macbook.and.iphone")
        .resizable()
        .scaledToFit()
        .foregroundStyle(.secondary)
    }
  }

  private var filteredApplications: [AudioApplication] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return applications
      .filter { application in
        query.isEmpty
          || application.name.localizedCaseInsensitiveContains(query)
          || application.bundleIdentifier.localizedCaseInsensitiveContains(query)
      }
      .sorted { left, right in
        let comparison = left.name.localizedCaseInsensitiveCompare(right.name)
        return comparison == .orderedSame
          ? left.bundleIdentifier < right.bundleIdentifier
          : comparison == .orderedAscending
      }
  }

  private func choose(_ newSelection: AudioSourceSelection) {
    selection = newSelection
    isPresented = false
  }
}

private struct AudioSourcePickerRow: View {
  let title: String
  let systemImage: String?
  let icon: NSImage?
  let isSelected: Bool
  let action: () -> Void

  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Group {
          if let icon {
            Image(nsImage: icon)
              .resizable()
              .scaledToFit()
          } else if let systemImage {
            Image(systemName: systemImage)
              .resizable()
              .scaledToFit()
              .foregroundStyle(.secondary)
          }
        }
        .frame(width: 20, height: 20)

        Text(title)
          .lineLimit(1)

        Spacer(minLength: 8)

        if isSelected {
          Image(systemName: "checkmark")
            .fontWeight(.semibold)
            .foregroundStyle(.tint)
        }
      }
      .padding(.horizontal, 10)
      .frame(height: 34)
      .contentShape(Rectangle())
      .background(
        isHovering ? Color.accentColor.opacity(0.12) : .clear,
        in: RoundedRectangle(cornerRadius: 7)
      )
    }
    .buttonStyle(.plain)
    .onHover { isHovering = $0 }
  }
}
