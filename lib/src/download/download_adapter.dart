import 'dart:typed_data';

import 'package:device_io/src/types/platform_result.dart';

/// Platform-agnostic file download/save to device.
///
/// Implementations:
/// - `NativeDownloadAdapter` — saves to downloads directory (mobile/desktop)
/// - `WebDownloadAdapter` — triggers browser download via blob URL (web)
abstract interface class DownloadAdapter {
  /// Save bytes to a user-accessible location.
  ///
  /// On mobile: saves to downloads/gallery.
  /// On web: triggers browser download.
  /// On desktop: saves to downloads directory.
  ///
  /// Existing files are never overwritten — when [fileName] is taken, a
  /// numbered variant is used instead (`report (1).pdf`), matching browser
  /// download behavior.
  ///
  /// Returns the saved file path (null on web where no path is meaningful).
  Future<PlatformResult<String?>> saveToDevice({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  });

  /// Save a byte stream to a user-accessible location (for large files).
  ///
  /// On native platforms the stream is written to disk chunk by chunk
  /// (constant memory). On web the stream is buffered into memory before
  /// the download triggers — blob downloads need the full content up front.
  ///
  /// Returns the saved file path (null on web).
  Future<PlatformResult<String?>> saveStreamToDevice({
    required Stream<List<int>> byteStream,
    required String fileName,
    String? mimeType,
  });
}
