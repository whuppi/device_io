import 'dart:typed_data';

import 'package:device_io/src/sharer/share_file.dart';
import 'package:device_io/src/sharer/share_origin.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Platform-agnostic data sharing via OS share sheet.
///
/// ```dart
/// await deviceIO.sharer.shareFile(
///   bytes: pngBytes,
///   fileName: 'photo.png',
///   text: 'Look at this!',
/// );
///
/// // Several files in one sheet:
/// await deviceIO.sharer.shareFiles(
///   files: [
///     ShareFile(bytes: pngBytes, fileName: 'chart.png'),
///     ShareFile(bytes: csvBytes, fileName: 'data.csv'),
///   ],
/// );
/// ```
///
/// Implementations handle temp file staging internally — callers just
/// pass bytes or a stream.
///
/// Every method takes an optional `sharePositionOrigin`: the iPadOS
/// share-popover anchor rectangle, in global coordinates. Required on iPad
/// for the sheet to have somewhere to point; ignored on platforms without
/// popover anchoring (web ignores it entirely).
///
/// Implementations:
/// - `NativeSharer` — wraps share_plus (mobile/desktop)
/// - `WebSharer` — Web Share API (web)
///
/// A dismissed share sheet returns [PlatformCancelled].
abstract interface class Sharer {
  /// Share text content via OS share sheet.
  ///
  /// See the class doc for [sharePositionOrigin].
  Future<PlatformResult<void>> shareText({
    required String text,
    String? subject,
    ShareOrigin? sharePositionOrigin,
  });

  /// Share a file (from bytes) via OS share sheet.
  ///
  /// See the class doc for [sharePositionOrigin].
  Future<PlatformResult<void>> shareFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String? subject,
    String? text,
    ShareOrigin? sharePositionOrigin,
  });

  /// Share multiple files in a single share sheet.
  ///
  /// Throws [ArgumentError] if [files] is empty — a share sheet with
  /// nothing in it is a caller bug, not a runtime condition.
  ///
  /// See the class doc for [sharePositionOrigin].
  Future<PlatformResult<void>> shareFiles({
    required List<ShareFile> files,
    String? subject,
    String? text,
    ShareOrigin? sharePositionOrigin,
  });

  /// Share a file from a byte stream (for large files).
  ///
  /// On native platforms the stream is staged to disk chunk by chunk
  /// (constant memory). On web the stream is buffered into memory first —
  /// the Web Share API needs the full content up front.
  ///
  /// See the class doc for [sharePositionOrigin].
  Future<PlatformResult<void>> shareFileStream({
    required Stream<List<int>> byteStream,
    required String fileName,
    String? mimeType,
    String? subject,
    String? text,
    ShareOrigin? sharePositionOrigin,
  });
}
