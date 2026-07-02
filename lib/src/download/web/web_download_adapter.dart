import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:device_io/src/download/download_adapter.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Web download adapter using blob URL + anchor click.
///
/// Triggers a browser download — the user's browser download settings
/// determine where the file goes.
class WebDownloadAdapter implements DownloadAdapter {
  @override
  Future<PlatformResult<String?>> saveToDevice({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      _triggerDownload(bytes, fileName, mimeType);
      return const PlatformSupported(null); // No file path on web.
    } catch (e, st) {
      if (e is Error) rethrow; // Programmer bugs crash loudly.
      return PlatformFailed(
        'Failed to trigger download',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<PlatformResult<String?>> saveStreamToDevice({
    required Stream<List<int>> byteStream,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      // Blob downloads need the full content up front, so the stream is
      // buffered into memory here — web cannot stream to disk without the
      // File System Access API. The interface documents this limitation.
      final builder = BytesBuilder(copy: false);
      await for (final chunk in byteStream) {
        builder.add(chunk);
      }
      _triggerDownload(builder.takeBytes(), fileName, mimeType);
      return const PlatformSupported(null);
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed(
        'Failed to trigger download',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<PlatformResult<String?>> saveAs({
    required Uint8List bytes,
    required String fileName,
    String? dialogTitle,
  }) {
    // Browsers offer no save dialog to web pages — a download IS the
    // user-visible save on this platform.
    return saveToDevice(bytes: bytes, fileName: fileName);
  }

  void _triggerDownload(Uint8List bytes, String fileName, String? mimeType) {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType ?? mimeTypeFromFileName(fileName)),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.style.display = 'none';

    web.document.body!.appendChild(anchor);
    anchor.click();
    web.document.body!.removeChild(anchor);

    // Revoking synchronously after click is racy on some browsers for
    // large blobs (the download may not have opened the URL yet). Deferred
    // revoke; page unload frees the blob regardless.
    unawaited(
      Future<void>.delayed(
        const Duration(minutes: 1),
        () => web.URL.revokeObjectURL(url),
      ),
    );
  }
}
