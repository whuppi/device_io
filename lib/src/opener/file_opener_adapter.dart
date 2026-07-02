import 'dart:typed_data';

import 'package:device_io/src/types/platform_result.dart';

/// Platform-agnostic file opening in the default viewer.
///
/// Opens content in Preview, Photos, QuickTime, a browser tab — whatever
/// the platform associates with the content type.
///
/// Implementations:
/// - `NativeFileOpenerAdapter` — OS open command / open_filex
///   (mobile/desktop)
/// - `WebFileOpenerAdapter` — blob URL in a new tab (web)
abstract interface class FileOpenerAdapter {
  /// Open in-memory content in the platform's default viewer.
  ///
  /// Works on every platform: native stages the bytes to a temporary file
  /// and opens it; web opens a blob URL in a new tab.
  ///
  /// [mimeType] helps the platform pick the right viewer; when omitted it
  /// is inferred from [fileName]'s extension.
  Future<PlatformResult<void>> openBytes({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  });

  /// Open a file at the given absolute path in the OS default app.
  ///
  /// Pairs with the path returned by `DownloadAdapter.saveToDevice` —
  /// open what was just saved without re-reading it.
  ///
  /// [mimeType] is optional — the OS infers the app from the file extension.
  /// Returns [PlatformUnsupported] on web (no filesystem paths exist there;
  /// use [openBytes] instead).
  /// Returns [PlatformFailed] if the file doesn't exist or can't be opened.
  Future<PlatformResult<void>> openPath({
    required String filePath,
    String? mimeType,
  });
}
