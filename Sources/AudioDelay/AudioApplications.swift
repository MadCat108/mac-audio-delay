import AppKit
import CoreAudio
import Foundation

struct AudioApplication: Identifiable, Hashable {
  let bundleIdentifier: String
  let name: String
  let bundleURL: URL?

  var id: String { bundleIdentifier }

  var icon: NSImage {
    guard let bundleURL else {
      return NSImage(systemSymbolName: "app", accessibilityDescription: nil)
        ?? NSImage(size: NSSize(width: 32, height: 32))
    }
    return NSWorkspace.shared.icon(forFile: bundleURL.path)
  }
}

enum AudioApplications {
  static func running() -> [AudioApplication] {
    let ownBundleIdentifier = Bundle.main.bundleIdentifier
    var applicationsByIdentifier: [String: AudioApplication] = [:]

    for processObjectID in processObjectIDs() {
      guard let pid = processPID(processObjectID),
        let runningApplication = NSRunningApplication(processIdentifier: pid)
      else {
        continue
      }
      guard let application = identity(for: runningApplication),
        application.bundleIdentifier != ownBundleIdentifier
      else {
        continue
      }
      applicationsByIdentifier[application.bundleIdentifier] = application
    }

    return applicationsByIdentifier.values.sorted {
      let comparison = $0.name.localizedCaseInsensitiveCompare($1.name)
      return comparison == .orderedSame
        ? $0.bundleIdentifier < $1.bundleIdentifier
        : comparison == .orderedAscending
    }
  }

  static func bundleIdentifier(forPID pid: pid_t) -> String? {
    guard let runningApplication = NSRunningApplication(processIdentifier: pid) else {
      return nil
    }
    return identity(for: runningApplication)?.bundleIdentifier
  }

  private static func processObjectIDs() -> [AudioObjectID] {
    let systemObject = AudioObjectID(kAudioObjectSystemObject)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyProcessObjectList,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &size) == noErr else {
      return []
    }

    let count = Int(size) / MemoryLayout<AudioObjectID>.size
    guard count > 0 else { return [] }

    var processObjectIDs = Array(
      repeating: AudioObjectID(kAudioObjectUnknown),
      count: count
    )
    guard AudioObjectGetPropertyData(
      systemObject,
      &address,
      0,
      nil,
      &size,
      &processObjectIDs
    ) == noErr else {
      return []
    }
    return processObjectIDs
  }

  private static func processPID(_ processObjectID: AudioObjectID) -> pid_t? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioProcessPropertyPID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var pid: pid_t = 0
    var size = UInt32(MemoryLayout<pid_t>.size)
    guard AudioObjectGetPropertyData(
      processObjectID,
      &address,
      0,
      nil,
      &size,
      &pid
    ) == noErr else {
      return nil
    }
    return pid
  }

  private static func identity(for runningApplication: NSRunningApplication) -> AudioApplication? {
    let rootURL = outermostApplicationURL(containing: runningApplication.bundleURL)
    guard rootURL != nil || runningApplication.activationPolicy != .prohibited else {
      return nil
    }
    let rootBundle = rootURL.flatMap(Bundle.init(url:))
    guard let bundleIdentifier = rootBundle?.bundleIdentifier ?? runningApplication.bundleIdentifier,
      !bundleIdentifier.isEmpty
    else {
      return nil
    }

    let displayName = rootBundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    let bundleName = rootBundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
    let filename = rootURL?.deletingPathExtension().lastPathComponent
    let name = displayName ?? bundleName ?? filename ?? runningApplication.localizedName
      ?? bundleIdentifier

    return AudioApplication(
      bundleIdentifier: bundleIdentifier,
      name: name,
      bundleURL: rootURL ?? runningApplication.bundleURL
    )
  }

  private static func outermostApplicationURL(containing url: URL?) -> URL? {
    guard var candidate = url else { return nil }
    var outermost: URL?

    while candidate.path != "/" {
      if candidate.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame {
        outermost = candidate
      }
      candidate.deleteLastPathComponent()
    }
    return outermost
  }
}
