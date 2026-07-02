import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:device_io/src/sharing/sharing_adapter.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Web sharing via the Web Share API.
///
/// Returns [PlatformUnsupported] when the browser doesn't support sharing,
/// [PlatformCancelled] when the user dismisses the share dialog.
final class WebSharingAdapter implements SharingAdapter {
  @override
  Future<PlatformResult<void>> shareText({
    required String text,
    String? subject,
  }) async {
    // Feature-detect instead of calling and string-matching the TypeError.
    if (!_shareSupported) {
      return const PlatformUnsupported(
        'Sharing is not supported in this browser',
      );
    }
    try {
      final data = web.ShareData(text: text);
      if (subject != null) data.title = subject;

      await web.window.navigator.share(data).toDart;
      return const PlatformSupported(null);
    } catch (e, st) {
      if (e is Error) rethrow; // Programmer bugs crash loudly.
      return _mapShareError(e, st, 'Failed to share text');
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
    if (!_shareSupported) {
      return const PlatformUnsupported(
        'Sharing is not supported in this browser',
      );
    }
    try {
      final type = mimeType ?? mimeTypeFromFileName(fileName);
      final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: type));
      final file = web.File(
        [blob].toJS,
        fileName,
        web.FilePropertyBag(type: type),
      );

      final data = web.ShareData(files: [file].toJS);
      if (subject != null) data.title = subject;
      if (text != null) data.text = text;

      // canShare validates the payload (file sharing arrived later than
      // text sharing — Safari and Firefox gained it separately).
      if (!web.window.navigator.canShare(data)) {
        return const PlatformUnsupported(
          'File sharing is not supported in this browser',
        );
      }

      await web.window.navigator.share(data).toDart;
      return const PlatformSupported(null);
    } catch (e, st) {
      if (e is Error) rethrow;
      return _mapShareError(e, st, 'Failed to share "$fileName"');
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
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed(
        'Failed to read the byte stream',
        error: e,
        stackTrace: st,
      );
    }
    return shareFile(
      bytes: builder.takeBytes(),
      fileName: fileName,
      mimeType: mimeType,
      subject: subject,
      text: text,
    );
  }

  bool get _shareSupported =>
      web.window.navigator.hasProperty('share'.toJS).toDart;

  PlatformResult<void> _mapShareError(Object e, StackTrace st, String message) {
    final name = _domExceptionName(e);
    if (name == 'AbortError') {
      return const PlatformCancelled();
    }
    if (name == 'NotAllowedError') {
      return PlatformPermissionDenied(
        message:
            'The browser blocked sharing (needs a user gesture or '
            'permission)',
        error: e,
        stackTrace: st,
      );
    }
    if (name == 'NotSupportedError') {
      return const PlatformUnsupported(
        'Sharing is not supported in this browser',
      );
    }
    return PlatformFailed(message, error: e, stackTrace: st);
  }

  /// Extracts the DOMException name from a rejected share() promise.
  ///
  /// A typed `is DOMException` check is not platform-consistent across
  /// dart2js and dart2wasm (the analyzer flags it), so the portable check
  /// is name matching on the error's string form — DOMException stringifies
  /// as `Name: message` on every backend.
  String? _domExceptionName(Object e) {
    final text = e.toString();
    for (final name in const [
      'AbortError',
      'NotAllowedError',
      'NotSupportedError',
    ]) {
      if (text.contains(name)) return name;
    }
    return null;
  }
}
