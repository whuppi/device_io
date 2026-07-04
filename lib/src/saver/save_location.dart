import 'package:meta/meta.dart';

/// Where a save operation put the file.
///
/// Saving lands in one of two worlds and the difference matters to callers:
/// a real filesystem path can be re-opened (`FileOpener.openPath`), while a
/// browser-managed download has no path at all. A sealed type makes the two
/// impossible to confuse — there is no nullable path to misread.
///
/// ```dart
/// final saved = await deviceIO.saver.save(bytes: bytes, fileName: 'a.pdf');
/// switch (saved) {
///   case PlatformSuccess(value: SavedAtPath(:final path)):
///     await deviceIO.opener.openPath(filePath: path);
///   case PlatformSuccess(value: SavedByBrowser()):
///     break; // the browser owns the file now
///   default:
///     showError(saved);
/// }
/// ```
@immutable
sealed class SaveLocation {
  /// Const base constructor for the sealed subclasses.
  const SaveLocation();
}

/// The file was written to a real filesystem path (mobile/desktop, and
/// native save dialogs).
final class SavedAtPath extends SaveLocation {
  /// Creates a location carrying the absolute [path] of the saved file.
  const SavedAtPath(this.path);

  /// Absolute path of the saved file.
  final String path;

  @override
  String toString() => 'SavedAtPath($path)';
}

/// The browser handled the save — a download, or a File System Access
/// write. No filesystem path exists from the page's point of view.
final class SavedByBrowser extends SaveLocation {
  /// Creates a browser-handled location, with the chosen [fileName] when
  /// the browser reported one (File System Access save dialogs do).
  const SavedByBrowser({this.fileName});

  /// The file name the user chose in the browser's save dialog, when the
  /// File System Access API reported it; null for plain downloads.
  final String? fileName;

  @override
  String toString() => 'SavedByBrowser(${fileName ?? ''})';
}
