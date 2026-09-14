import Foundation

#if os(iOS)
  import Flutter
  import UIKit
  import UniformTypeIdentifiers
#else
  import AppKit
  import FlutterMacOS
#endif

/// The Apple half of the links door, one source for iOS and macOS.
///
/// It runs the picker that hands out access the app can KEEP — the
/// in-place document picker on iOS, the open panel on macOS — mints a
/// bookmark per pick, and turns a bookmark back into a readable path
/// inside a security scope it holds until the Dart side closes the
/// handle. iCloud placeholders are refused with `notDownloaded` and a
/// download can be started; a bookmark that no longer resolves is
/// `missing`; a scope the system refuses is `permission`.
///
/// An id is either a bookmark (base64) or, when no bookmark could be
/// minted, the picked file's URL — readable for this launch only, which is
/// what lets the copy path read a file the app may not keep.
///
/// The method names and payload keys mirror `LinksChannel` on the Dart
/// side, which is the one contract.
public class DeviceIoPlugin: NSObject, FlutterPlugin {
  static let channelName = "device_io/links"

  /// What `open` is holding for a handle: the URL, and whether a security
  /// scope was started on it and must be stopped on close.
  private struct Held {
    let url: URL
    let scoped: Bool
  }

  private var held: [Int: Held] = [:]
  private var nextHandle = 1

  #if os(iOS)
    private var pickerDelegate: PickerDelegate?
  #endif

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let instance = DeviceIoPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "mode":
      result("darwin")
    case "pickFiles":
      pickFiles(extensions: args["extensions"] as? [String], result: result)
    case "pickFolder":
      pickFolder(result: result)
    case "describe":
      guard let path = args["path"] as? String else {
        return result(FlutterError(code: "failed", message: "describe needs a path", details: nil))
      }
      guard FileManager.default.fileExists(atPath: path) else {
        return result(FlutterError(code: "missing", message: "No file at that path", details: nil))
      }
      result(describe(url: URL(fileURLWithPath: path)))
    case "children":
      guard let folder = args["folder"] as? String else {
        return result(FlutterError(code: "failed", message: "children needs a folder", details: nil))
      }
      children(
        id: folder, extensions: args["extensions"] as? [String],
        recursive: args["recursive"] as? Bool ?? false, result: result)
    case "open":
      guard let id = args["id"] as? String else {
        return result(FlutterError(code: "failed", message: "open needs an id", details: nil))
      }
      open(id: id, relative: args["relative"] as? String, result: result)
    case "close":
      if let handle = args["handle"] as? Int, let entry = held.removeValue(forKey: handle), entry.scoped {
        entry.url.stopAccessingSecurityScopedResource()
      }
      result(nil)
    case "startDownload":
      guard let id = args["id"] as? String else {
        return result(FlutterError(code: "failed", message: "startDownload needs an id", details: nil))
      }
      startDownload(id: id, relative: args["relative"] as? String, result: result)
    case "takeGrant", "releaseGrant":
      // Bookmarks are the grant; there is nothing to take or count.
      result(nil)
    case "grants":
      result([[String: Any]]())
    case "grantCapacity":
      result(0)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Picking

  private func pickFiles(extensions: [String]?, result: @escaping FlutterResult) {
    #if os(iOS)
      guard let controller = Self.topController() else {
        return result(FlutterError(code: "failed", message: "No view controller to present from", details: nil))
      }
      var types: [UTType] = [.item]
      if let extensions = extensions {
        let mapped = extensions.compactMap { UTType(filenameExtension: $0) }
        // One unknown extension would silently hide those files; offer
        // everything instead of a partial filter.
        if mapped.count == extensions.count, !mapped.isEmpty { types = mapped }
      }
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
      picker.allowsMultipleSelection = true
      let delegate = PickerDelegate { [weak self] urls in
        self?.pickerDelegate = nil
        guard let self = self else { return }
        result(urls.map { self.describe(url: $0) })
      }
      pickerDelegate = delegate
      picker.delegate = delegate
      controller.present(picker, animated: true)
    #else
      let panel = NSOpenPanel()
      panel.canChooseFiles = true
      panel.canChooseDirectories = false
      panel.allowsMultipleSelection = true
      if let extensions = extensions, !extensions.isEmpty {
        panel.allowedFileTypes = extensions
      }
      panel.begin { response in
        guard response == .OK else { return result([[String: Any]]()) }
        result(panel.urls.map { self.describe(url: $0) })
      }
    #endif
  }

  private func pickFolder(result: @escaping FlutterResult) {
    #if os(iOS)
      guard let controller = Self.topController() else {
        return result(FlutterError(code: "failed", message: "No view controller to present from", details: nil))
      }
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
      picker.allowsMultipleSelection = false
      let delegate = PickerDelegate { [weak self] urls in
        self?.pickerDelegate = nil
        guard let self = self, let url = urls.first else { return result(nil) }
        result(self.describeFolder(url: url))
      }
      pickerDelegate = delegate
      picker.delegate = delegate
      controller.present(picker, animated: true)
    #else
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.allowsMultipleSelection = false
      panel.begin { response in
        guard response == .OK, let url = panel.url else { return result(nil) }
        result(self.describeFolder(url: url))
      }
    #endif
  }

  #if os(iOS)
    private static func topController() -> UIViewController? {
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
      var top = window?.rootViewController
      while let presented = top?.presentedViewController { top = presented }
      return top
    }

    /// The picker's delegate, held only while the picker is on screen.
    final class PickerDelegate: NSObject, UIDocumentPickerDelegate {
      private let done: ([URL]) -> Void
      init(done: @escaping ([URL]) -> Void) { self.done = done }
      func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        done(urls)
      }
      func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { done([]) }
    }
  #endif

  // MARK: - Describing

  /// `{id, name, size, regular, persistable, downloaded}` for one picked URL.
  /// The id IS the bookmark; a bookmark that cannot be minted makes the
  /// pick a session-only candidate rather than a failure.
  private func describe(url: URL) -> [String: Any] {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let values = try? url.resourceValues(forKeys: [
      .fileSizeKey, .nameKey, .isRegularFileKey, .ubiquitousItemDownloadingStatusKey,
    ])
    let bookmark = Self.mintBookmark(url)
    return [
      "id": bookmark ?? url.absoluteString,
      "name": values?.name ?? url.lastPathComponent,
      "size": values?.fileSize as Any? ?? NSNull(),
      "regular": values?.isRegularFile ?? true,
      "persistable": bookmark != nil,
      "downloaded": Self.isDownloaded(values),
    ]
  }

  private func describeFolder(url: URL) -> [String: Any] {
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    return [
      "id": Self.mintBookmark(url) ?? url.absoluteString,
      "name": url.lastPathComponent,
    ]
  }

  private static func mintBookmark(_ url: URL) -> String? {
    #if os(iOS)
      // iOS has no security-scoped bookmark option; a regular bookmark is
      // what persists the picker's access across launches.
      let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    #else
      let data = try? url.bookmarkData(
        options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    #endif
    return data?.base64EncodedString()
  }

  private static func isDownloaded(_ values: URLResourceValues?) -> Bool {
    guard let status = values?.ubiquitousItemDownloadingStatus else { return true }
    return status == .current || status == .downloaded
  }

  // MARK: - Resolving

  /// A resolved id. `scoped` says whether a security scope must be started
  /// to read it — true for a bookmark, false for a plain URL the picker
  /// granted for this launch.
  private enum Resolved {
    case url(URL, scoped: Bool)
    case missing
  }

  private static func resolve(id: String) -> Resolved {
    if let data = Data(base64Encoded: id) {
      var stale = false
      #if os(iOS)
        let options: URL.BookmarkResolutionOptions = []
      #else
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
      #endif
      guard let url = try? URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &stale)
      else { return .missing }
      return .url(url, scoped: true)
    }
    guard let url = URL(string: id), url.isFileURL else { return .missing }
    return .url(url, scoped: false)
  }

  private func children(
    id: String, extensions: [String]?, recursive: Bool, result: @escaping FlutterResult
  ) {
    guard case .url(let folder, _) = Self.resolve(id: id) else {
      return result(FlutterError(code: "missing", message: "The linked folder no longer resolves", details: nil))
    }
    let scoped = folder.startAccessingSecurityScopedResource()
    defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
    let wanted = extensions.map { Set($0.map { $0.lowercased() }) }
    let keys: [URLResourceKey] = [.nameKey, .fileSizeKey, .isRegularFileKey, .isDirectoryKey]
    // The folder's own files, or every file under it: one enumerator
    // either way, descending only when asked.
    let options: FileManager.DirectoryEnumerationOptions =
      recursive ? [.skipsHiddenFiles] : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
    guard
      let enumerator = FileManager.default.enumerator(
        at: folder, includingPropertiesForKeys: keys, options: options)
    else {
      return result(FlutterError(code: "permission", message: "The linked folder could not be read", details: nil))
    }
    let base = folder.standardizedFileURL.path.hasSuffix("/")
      ? folder.standardizedFileURL.path : folder.standardizedFileURL.path + "/"
    var out: [[String: Any]] = []
    for case let entry as URL in enumerator {
      let values = try? entry.resourceValues(forKeys: Set(keys))
      if values?.isDirectory == true { continue }
      if let wanted = wanted, !wanted.contains(entry.pathExtension.lowercased()) { continue }
      let full = entry.standardizedFileURL.path
      let relative = full.hasPrefix(base) ? String(full.dropFirst(base.count)) : entry.lastPathComponent
      out.append([
        "id": id,
        "relative": relative,
        "name": values?.name ?? entry.lastPathComponent,
        "size": values?.fileSize as Any? ?? NSNull(),
        "regular": values?.isRegularFile ?? true,
      ])
    }
    out.sort { ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "") }
    result(out)
  }


  /// Turns an id (plus an optional child path) into a readable path. A
  /// bookmark is opened inside a security scope this plugin holds until
  /// `close(handle)`; a plain URL is read on the access the picker granted
  /// for this launch.
  private func open(id: String, relative: String?, result: @escaping FlutterResult) {
    guard case .url(let base, let scoped) = Self.resolve(id: id) else {
      return result(FlutterError(code: "missing", message: "The linked file no longer resolves", details: nil))
    }
    let started = scoped && base.startAccessingSecurityScopedResource()
    if scoped && !started && Self.needsScope(base) {
      return result(FlutterError(code: "permission", message: "The system refused access to the linked file", details: nil))
    }
    func release() {
      if started { base.stopAccessingSecurityScopedResource() }
    }
    let target = relative.map { base.appendingPathComponent($0) } ?? base
    let values = try? target.resourceValues(forKeys: [.fileSizeKey, .ubiquitousItemDownloadingStatusKey])
    if !FileManager.default.fileExists(atPath: target.path) {
      release()
      return result(FlutterError(code: "missing", message: "The linked file is no longer there", details: nil))
    }
    if !Self.isDownloaded(values) {
      release()
      return result(FlutterError(
        code: "notDownloaded", message: "The linked file is an iCloud placeholder",
        details: ["id": id, "relative": relative as Any? ?? NSNull()]))
    }
    let handle = nextHandle
    nextHandle += 1
    held[handle] = Held(url: base, scoped: started)
    result([
      "path": target.path,
      "size": values?.fileSize as Any? ?? NSNull(),
      "handle": handle,
    ])
  }

  /// A URL outside the sandbox needs a scope; a refused scope on one
  /// INSIDE it (an unsandboxed build, the app's own container) is not a
  /// refusal at all.
  private static func needsScope(_ url: URL) -> Bool {
    #if os(iOS)
      return true
    #else
      let home = FileManager.default.homeDirectoryForCurrentUser.path
      return !url.path.hasPrefix(home) || ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    #endif
  }

  private func startDownload(id: String, relative: String?, result: @escaping FlutterResult) {
    guard case .url(let base, _) = Self.resolve(id: id) else {
      return result(FlutterError(code: "missing", message: "The linked file no longer resolves", details: nil))
    }
    let scoped = base.startAccessingSecurityScopedResource()
    defer { if scoped { base.stopAccessingSecurityScopedResource() } }
    let target = relative.map { base.appendingPathComponent($0) } ?? base
    do {
      try FileManager.default.startDownloadingUbiquitousItem(at: target)
      result(nil)
    } catch {
      result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
    }
  }
}
