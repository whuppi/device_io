import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:device_io/src/types/platform_result.dart';
import 'package:device_io/src/sharing/sharing_adapter.dart';

/// Web sharing via the Web Share API.
///
/// Falls back to [PlatformUnsupported] if the browser doesn't support sharing.
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
      if (_isAbortError(e)) return const PlatformSupported(null);
      if (_isNotSupportedError(e)) {
        return const PlatformUnsupported(
          'Sharing is not supported in this browser',
        );
      }
      return PlatformFailed('Failed to share text', error: e);
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
      if (_isAbortError(e)) return const PlatformSupported(null);
      if (_isNotSupportedError(e)) {
        return const PlatformUnsupported(
          'Sharing is not supported in this browser',
        );
      }
      return PlatformFailed('Failed to share file', error: e);
    }
  }

  bool _isAbortError(Object e) => e.toString().contains('AbortError');

  bool _isNotSupportedError(Object e) {
    final msg = e.toString();
    return msg.contains('not a function') || msg.contains('NotSupportedError');
  }
}
