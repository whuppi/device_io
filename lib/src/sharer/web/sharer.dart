import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:device_io/src/runtime/web/dom_exception.dart';
import 'package:device_io/src/sharer/share_file.dart';
import 'package:device_io/src/sharer/share_origin.dart';
import 'package:device_io/src/sharer/sharer.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/outcome.dart';

/// Web sharing via the Web Share API.
///
/// Returns [Unsupported] when the browser doesn't support sharing,
/// [Cancelled] when the user dismisses the share dialog.
final class WebSharer implements Sharer {
  // sharePositionOrigin is the iPadOS popover anchor — the web share
  // dialog has no popover to anchor, so every method accepts it and
  // ignores it.

  @override
  Future<Outcome<void>> shareText({
    required String text,
    String? subject,
    ShareOrigin? sharePositionOrigin,
  }) async {
    // Feature-detect instead of calling and string-matching the TypeError.
    if (!_shareSupported) {
      return const Unsupported('Sharing is not supported in this browser');
    }
    try {
      final data = web.ShareData(text: text);
      if (subject != null) data.title = subject;

      await web.window.navigator.share(data).toDart;
      return const Success(null);
    } catch (e, st) {
      if (e is Error) rethrow; // Programmer bugs crash loudly.
      return _mapShareError(e, st, 'Failed to share text');
    }
  }

  @override
  Future<Outcome<void>> shareFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String? subject,
    String? text,
    ShareOrigin? sharePositionOrigin,
  }) async {
    if (!_shareSupported) {
      return const Unsupported('Sharing is not supported in this browser');
    }
    try {
      final file = _toWebFile(bytes, fileName, mimeType);

      final data = web.ShareData(files: [file].toJS);
      if (subject != null) data.title = subject;
      if (text != null) data.text = text;

      // canShare validates the payload (file sharing arrived later than
      // text sharing — Safari and Firefox gained it separately).
      if (!web.window.navigator.canShare(data)) {
        return const Unsupported(
          'File sharing is not supported in this browser',
        );
      }

      await web.window.navigator.share(data).toDart;
      return const Success(null);
    } catch (e, st) {
      if (e is Error) rethrow;
      return _mapShareError(e, st, 'Failed to share "$fileName"');
    }
  }

  @override
  Future<Outcome<void>> shareFiles({
    required List<ShareFile> files,
    String? subject,
    String? text,
    ShareOrigin? sharePositionOrigin,
  }) async {
    if (files.isEmpty) {
      throw ArgumentError.value(files, 'files', 'must not be empty');
    }
    if (!_shareSupported) {
      return const Unsupported('Sharing is not supported in this browser');
    }
    try {
      final webFiles = [
        for (final f in files) _toWebFile(f.bytes, f.fileName, f.mimeType),
      ];

      final data = web.ShareData(files: webFiles.toJS);
      if (subject != null) data.title = subject;
      if (text != null) data.text = text;

      // canShare validates the payload (file sharing arrived later than
      // text sharing — Safari and Firefox gained it separately).
      if (!web.window.navigator.canShare(data)) {
        return const Unsupported(
          'File sharing is not supported in this browser',
        );
      }

      await web.window.navigator.share(data).toDart;
      return const Success(null);
    } catch (e, st) {
      if (e is Error) rethrow;
      return _mapShareError(e, st, 'Failed to share ${files.length} files');
    }
  }

  @override
  Future<Outcome<void>> shareFileStream({
    required Stream<List<int>> byteStream,
    required String fileName,
    String? mimeType,
    String? subject,
    String? text,
    ShareOrigin? sharePositionOrigin,
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
      return Failed('Failed to read the byte stream', error: e, stackTrace: st);
    }
    return shareFile(
      bytes: builder.takeBytes(),
      fileName: fileName,
      mimeType: mimeType,
      subject: subject,
      text: text,
    );
  }

  /// Wraps [bytes] in a `web.File` carrying the resolved MIME type, deriving
  /// one from [fileName] when [mimeType] is null.
  web.File _toWebFile(Uint8List bytes, String fileName, String? mimeType) {
    final type = mimeType ?? mimeTypeFromFileName(fileName);
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: type));
    return web.File([blob].toJS, fileName, web.FilePropertyBag(type: type));
  }

  bool get _shareSupported =>
      web.window.navigator.hasProperty('share'.toJS).toDart;

  Outcome<void> _mapShareError(Object e, StackTrace st, String message) {
    final name = domExceptionName(e, const [
      'AbortError',
      'NotAllowedError',
      'NotSupportedError',
    ]);
    if (name == 'AbortError') {
      return const Cancelled();
    }
    if (name == 'NotAllowedError') {
      return PermissionDenied(
        message:
            'The browser blocked sharing (needs a user gesture or '
            'permission)',
        error: e,
        stackTrace: st,
      );
    }
    if (name == 'NotSupportedError') {
      return const Unsupported('Sharing is not supported in this browser');
    }
    return Failed(message, error: e, stackTrace: st);
  }
}
