import 'dart:typed_data';

import 'package:device_io/src/saver/save_location.dart';
import 'package:device_io/src/types/outcome.dart';

/// Platform-agnostic file opening in the default viewer.
///
/// Opens content in Preview, Photos, QuickTime, a browser tab — whatever
/// the platform associates with the content type.
///
/// ```dart
/// // Works on every platform (web opens a new tab):
/// await deviceIO.opener.openBytes(bytes: pdfBytes, fileName: 'doc.pdf');
///
/// // Open what save just wrote (native only):
/// final saved = await deviceIO.saver.save(
///   bytes: bytes, fileName: 'report.pdf');
/// if (saved case Success(value: SavedAtPath(:final path))) {
///   await deviceIO.opener.openPath(filePath: path);
/// }
/// ```
///
/// Implementations:
/// - `NativeFileOpener` — OS open command / open_filex
///   (mobile/desktop)
/// - `WebFileOpener` — blob URL in a new tab (web)
abstract interface class FileOpener {
  /// Open in-memory content in the platform's default viewer.
  ///
  /// Works on every platform: native stages the bytes to a temporary file
  /// and opens it; web opens a blob URL in a new tab.
  ///
  /// [mimeType] helps the platform pick the right viewer; when omitted it
  /// is inferred from [fileName]'s extension.
  Future<Outcome<void>> openBytes({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  });

  /// Open a file at the given absolute path in the OS default app.
  ///
  /// Pairs with the path returned by `FileSaver.save` —
  /// open what was just saved without re-reading it.
  ///
  /// [mimeType] is optional — the OS infers the app from the file extension.
  /// Returns [Unsupported] on web (no filesystem paths exist there;
  /// use [openBytes] instead).
  /// Returns [Failed] if the file doesn't exist or can't be opened.
  Future<Outcome<void>> openPath({required String filePath, String? mimeType});

  /// Open the file a `FileSaver.save`/`saveInto` call produced, closing the
  /// save→open loop without the caller destructuring the location.
  ///
  /// A [SavedAtPath] opens at its path (native, zero-copy). A [SavedByBrowser]
  /// download can't be reached back — the browser owns that file — so it
  /// returns [Unsupported].
  Future<Outcome<void>> open(SaveLocation location, {String? mimeType});
}
