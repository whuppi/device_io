import 'package:device_io/src/types/platform_result.dart';

/// Platform-agnostic file opening in the OS default viewer.
///
/// Opens files in Preview, Photos, QuickTime, or whatever app the OS
/// associates with the file type. On web, file opening is unsupported
/// (files live in IndexedDB, not on a real filesystem).
///
/// Implementations:
/// - `NativeFileOpenerAdapter` — Process.run('open', ...) on macOS/Linux,
///   Process.run('start', ...) on Windows, url_launcher on mobile (future)
/// - `WebFileOpenerAdapter` — returns [PlatformUnsupported]
abstract interface class FileOpenerAdapter {
  /// Open a file at the given absolute path in the OS default app.
  ///
  /// [mimeType] is optional — the OS infers the app from the file extension.
  /// Returns [PlatformUnsupported] on web.
  /// Returns [PlatformFailed] if the file doesn't exist or can't be opened.
  Future<PlatformResult<void>> openFile({
    required String filePath,
    String? mimeType,
  });
}
