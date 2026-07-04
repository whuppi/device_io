import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:device_io/src/saver/file_saver.dart';
import 'package:device_io/src/saver/save_location.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/platform_result.dart';

// window.showSaveFilePicker — the File System Access save dialog.
// package:web only generates STABLE specs and this is still a WICG draft,
// so the binding is declared here. Chromium-only; feature-detected before
// every use, never assumed.
@JS('showSaveFilePicker')
external JSPromise<web.FileSystemFileHandle> _showSaveFilePicker(
  _SaveFilePickerOptions options,
);

extension type _SaveFilePickerOptions._(JSObject _) implements JSObject {
  external factory _SaveFilePickerOptions({String suggestedName});
}

/// Web file saver.
///
/// Silent saves trigger a browser download via blob URL + anchor click.
/// [saveAs] uses the real save dialog where the browser has one
/// (File System Access API on Chromium), falling back to a download.
final class WebFileSaver implements FileSaver {
  @override
  Future<PlatformResult<SaveLocation>> save({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      _triggerDownload(bytes, fileName, mimeType);
      return const PlatformSuccess(SavedByBrowser());
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
  Future<PlatformResult<SaveLocation>> saveStream({
    required Stream<List<int>> byteStream,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      // Blob downloads need the full content up front, so the stream is
      // buffered into memory here — a silent (no-dialog) streaming write
      // needs a File System Access handle, which only user-initiated
      // dialogs can produce. The interface documents this limitation.
      final builder = BytesBuilder(copy: false);
      await for (final chunk in byteStream) {
        builder.add(chunk);
      }
      _triggerDownload(builder.takeBytes(), fileName, mimeType);
      return const PlatformSuccess(SavedByBrowser());
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
  Future<PlatformResult<SaveLocation>> saveAs({
    required Uint8List bytes,
    required String fileName,
    String? dialogTitle,
    String? mimeType,
  }) async {
    // dialogTitle has no browser equivalent — save dialogs are chrome-owned.
    if (!_savePickerSupported) {
      // No File System Access API (Firefox, Safari): a browser download IS
      // the user-visible save on those browsers.
      return save(bytes: bytes, fileName: fileName, mimeType: mimeType);
    }
    try {
      final handle = await _showSaveFilePicker(
        _SaveFilePickerOptions(suggestedName: fileName),
      ).toDart;
      final writable = await handle.createWritable().toDart;
      await writable.write(bytes.toJS).toDart;
      await writable.close().toDart;
      return PlatformSuccess(SavedByBrowser(fileName: handle.name));
    } catch (e, st) {
      if (e is Error) rethrow;
      if (e.toString().contains('AbortError')) {
        return const PlatformCancelled();
      }
      // SecurityError (called outside a user gesture) and other dialog
      // failures: the save should still succeed — fall back to a download.
      final fallback = await save(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
      return switch (fallback) {
        PlatformSuccess() => fallback,
        _ => PlatformFailed(
          'Failed to save "$fileName"',
          error: e,
          stackTrace: st,
        ),
      };
    }
  }

  bool get _savePickerSupported =>
      web.window.hasProperty('showSaveFilePicker'.toJS).toDart;

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
