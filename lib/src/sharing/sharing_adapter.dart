import 'dart:typed_data';

import 'package:device_io/src/types/platform_result.dart';

/// Platform-agnostic data sharing via OS share sheet.
///
/// Implementations handle temp file creation/cleanup internally —
/// callers just pass bytes.
///
/// Implementations:
/// - [NativeSharingAdapter] — wraps share_plus (mobile/desktop)
/// - [WebSharingAdapter] — Web Share API (web)
abstract interface class SharingAdapter {
  /// Share text content via OS share sheet.
  Future<PlatformResult<void>> shareText({
    required String text,
    String? subject,
  });

  /// Share a file (from bytes) via OS share sheet.
  ///
  /// The adapter handles temp file creation and cleanup internally.
  Future<PlatformResult<void>> shareFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String? subject,
    String? text,
  });
}
