import 'dart:typed_data';

import 'package:device_io/src/types/platform_result.dart';

/// Platform-agnostic data sharing via OS share sheet.
///
/// Implementations handle temp file staging internally — callers just
/// pass bytes or a stream.
///
/// Implementations:
/// - `NativeSharingAdapter` — wraps share_plus (mobile/desktop)
/// - `WebSharingAdapter` — Web Share API (web)
///
/// A dismissed share sheet returns [PlatformCancelled].
abstract interface class SharingAdapter {
  /// Share text content via OS share sheet.
  Future<PlatformResult<void>> shareText({
    required String text,
    String? subject,
  });

  /// Share a file (from bytes) via OS share sheet.
  Future<PlatformResult<void>> shareFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String? subject,
    String? text,
  });

  /// Share a file from a byte stream (for large files).
  ///
  /// On native platforms the stream is staged to disk chunk by chunk
  /// (constant memory). On web the stream is buffered into memory first —
  /// the Web Share API needs the full content up front.
  Future<PlatformResult<void>> shareFileStream({
    required Stream<List<int>> byteStream,
    required String fileName,
    String? mimeType,
    String? subject,
    String? text,
  });
}
