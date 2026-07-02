import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:device_io/src/sharing/sharing_adapter.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Web sharing via the Web Share API.
///
/// Returns [PlatformUnsupported] when the browser doesn't support sharing,
/// [PlatformCancelled] when the user dismisses the share dialog.
class WebSharingAdapter implements SharingAdapter {
  @override
  Future<PlatformResult<void>> shareText({
    required String text,
    String? subject,
  }) async {
    try {
      final data = web.ShareData(text: text, title: subject ?? '');
      await web.window.navigator.share(data).toDart;
      return const PlatformSupported(null);
    } catch (e) {
      return _mapShareError(e, 'Failed to share text');
    }
  }

  @override
  Future<PlatformResult<void>> shareFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String? subject,
    String? text,
  }) async {
    try {
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: mimeType ?? 'application/octet-stream'),
      );
      final file = web.File(
        [blob].toJS,
        fileName,
        web.FilePropertyBag(type: mimeType ?? 'application/octet-stream'),
      );

      final data = web.ShareData(
        files: [file].toJS,
        title: subject ?? '',
        text: text ?? '',
      );

      // Check if the browser can share files.
      if (!web.window.navigator.canShare(data)) {
        return const PlatformUnsupported(
          'File sharing is not supported in this browser',
        );
      }

      await web.window.navigator.share(data).toDart;
      return const PlatformSupported(null);
    } catch (e) {
      return _mapShareError(e, 'Failed to share file');
    }
  }

  @override
  Future<PlatformResult<void>> shareFileStream({
    required Stream<List<int>> byteStream,
    required String fileName,
    String? mimeType,
    String? subject,
    String? text,
  }) async {
    // The Web Share API needs the full content up front, so the stream is
    // buffered into memory here. The interface documents this limitation.
    final builder = BytesBuilder(copy: false);
    try {
      await for (final chunk in byteStream) {
        builder.add(chunk);
      }
    } catch (e) {
      return PlatformFailed('Failed to read the byte stream', error: e);
    }
    return shareFile(
      bytes: builder.takeBytes(),
      fileName: fileName,
      mimeType: mimeType,
      subject: subject,
      text: text,
    );
  }

  /// Web Share errors arrive as untyped JS DOMExceptions — string matching
  /// on the exception name is the only signal available.
  PlatformResult<void> _mapShareError(Object e, String message) {
    final text = e.toString();
    if (text.contains('AbortError')) {
      return const PlatformCancelled();
    }
    if (text.contains('not a function') || text.contains('NotSupportedError')) {
      return const PlatformUnsupported(
        'Sharing is not supported in this browser',
      );
    }
    if (text.contains('NotAllowedError')) {
      return const PlatformPermissionDenied(
        message:
            'The browser blocked sharing (needs a user gesture or '
            'permission)',
      );
    }
    return PlatformFailed(message, error: e);
  }
}
