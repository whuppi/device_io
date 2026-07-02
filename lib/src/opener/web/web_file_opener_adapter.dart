import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:device_io/src/opener/file_opener_adapter.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Web file opener — blob URL in a new tab.
///
/// The browser IS the viewer on web: PDFs, images, video, and text render
/// in the new tab; anything the browser can't display downloads instead.
class WebFileOpenerAdapter implements FileOpenerAdapter {
  @override
  Future<PlatformResult<void>> openBytes({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: mimeType ?? mimeTypeFromFileName(fileName)),
      );
      final url = web.URL.createObjectURL(blob);

      final opened = web.window.open(url, '_blank');
      if (opened == null) {
        web.URL.revokeObjectURL(url);
        return const PlatformFailed(
          'The browser blocked opening a new tab (popup blocker)',
        );
      }

      // The tab needs the URL alive while it loads; revoke after a grace
      // period instead of immediately. The blob is freed on page unload
      // regardless, so a missed revoke can't leak past the session.
      unawaited(
        Future<void>.delayed(
          const Duration(minutes: 1),
          () => web.URL.revokeObjectURL(url),
        ),
      );
      return const PlatformSupported(null);
    } catch (e, st) {
      if (e is Error) rethrow; // Programmer bugs crash loudly.
      return PlatformFailed(
        'Failed to open "$fileName"',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<PlatformResult<void>> openPath({
    required String filePath,
    String? mimeType,
  }) async {
    return const PlatformUnsupported(
      'Filesystem paths do not exist on web — use openBytes instead',
    );
  }
}
