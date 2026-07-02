import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/platform_result.dart';

// window.showOpenFilePicker — the File System Access open dialog. It hands
// back blob-backed handles that read lazily, so a multi-select of large
// files never loads them all into memory up front (the file_picker web
// fallback does, via withData). package:web only generates STABLE specs
// and this is still a WICG draft, so the binding is declared here.
// Chromium-only; feature-detected before every use, never assumed.
@JS('showOpenFilePicker')
external JSPromise<JSArray<web.FileSystemFileHandle>> _showOpenFilePicker(
  _OpenFilePickerOptions options,
);

extension type _OpenFilePickerOptions._(JSObject _) implements JSObject {
  external factory _OpenFilePickerOptions({
    bool multiple,
    JSArray<_FilePickerAcceptType> types,
  });
}

extension type _FilePickerAcceptType._(JSObject _) implements JSObject {
  // `accept` maps a MIME type to a list of dot-prefixed extensions. Its
  // keys are dynamic (one per MIME), so it's built as a bare JSObject with
  // setProperty rather than a typed factory.
  external factory _FilePickerAcceptType({String description, JSObject accept});
}

/// Lazy web file pick via the File System Access API.
///
/// Returns null when the browser lacks `showOpenFilePicker` (Firefox,
/// Safari) so the caller falls through to the file_picker path. When the
/// API is present, the returned assets read from their blob-backed handles
/// on demand — nothing is loaded until [PickedAsset.readBytes] or
/// [PickedAsset.readStream] is called.
Future<PlatformResult<List<PickedAsset>>?> lazyWebFilePick({
  required bool allowMultiple,
  List<String>? allowedExtensions,
}) async {
  if (!_openPickerSupported) return null; // Fall through to file_picker.

  try {
    final handles = (await _showOpenFilePicker(
      _buildOptions(allowMultiple, allowedExtensions),
    ).toDart).toDart;

    if (handles.isEmpty) return const PlatformCancelled();

    final assets = <PickedAsset>[];
    for (final handle in handles) {
      final file = await handle.getFile().toDart;
      final type = file.type;
      assets.add(
        PickedAsset.lazy(
          mimeType: type.isNotEmpty ? type : mimeTypeFromFileName(file.name),
          fileName: file.name,
          readBytes: () => _readBytes(file),
          readStream: () => _readStream(file),
        ),
      );
    }
    return PlatformSupported(assets);
  } catch (e, st) {
    if (e is Error) rethrow; // Programmer bugs crash loudly.
    if (e.toString().contains('AbortError')) {
      return const PlatformCancelled(); // User dismissed the dialog.
    }
    // The dialog already opened; a failure after that is a real failure —
    // surface it rather than falling through to open a second dialog.
    return PlatformFailed('Failed to pick files', error: e, stackTrace: st);
  }
}

bool get _openPickerSupported =>
    web.window.hasProperty('showOpenFilePicker'.toJS).toDart;

_OpenFilePickerOptions _buildOptions(
  bool allowMultiple,
  List<String>? allowedExtensions,
) {
  if (allowedExtensions == null || allowedExtensions.isEmpty) {
    return _OpenFilePickerOptions(multiple: allowMultiple);
  }

  // Group each extension under its MIME type — the shape showOpenFilePicker
  // expects: accept = { "<mime>": [".ext", ...] }.
  final grouped = <String, List<String>>{};
  for (final ext in allowedExtensions) {
    final dotExt = ext.startsWith('.') ? ext : '.$ext';
    final mime = mimeTypeFromFileName('x$dotExt');
    grouped.putIfAbsent(mime, () => <String>[]).add(dotExt);
  }

  final accept = JSObject();
  for (final entry in grouped.entries) {
    accept.setProperty(
      entry.key.toJS,
      entry.value.map((e) => e.toJS).toList().toJS,
    );
  }

  return _OpenFilePickerOptions(
    multiple: allowMultiple,
    types: <_FilePickerAcceptType>[
      _FilePickerAcceptType(description: 'Allowed files', accept: accept),
    ].toJS,
  );
}

Future<Uint8List> _readBytes(web.File file) async {
  final buffer = (await file.arrayBuffer().toDart).toDart;
  return buffer.asUint8List();
}

// Fresh stream per call (the PickedAsset contract), single-chunk. The
// laziness win is that the blob-backed handle isn't read until this is
// invoked; chunked slicing via Blob.slice is a possible future refinement.
Stream<List<int>> _readStream(web.File file) async* {
  yield await _readBytes(file);
}
