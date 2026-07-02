import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:device_io/src/_shared/native_fs.dart';
import 'package:device_io/src/download/download_adapter.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Native (mobile/desktop) download adapter.
///
/// Silent saves go to the downloads directory — the user's real Downloads
/// on desktop, an app-private folder on mobile (see the interface docs).
/// [saveAs] opens the system save dialog instead.
class NativeDownloadAdapter implements DownloadAdapter {
  /// Creates the adapter, optionally scoping saves to [appSubfolder].
  NativeDownloadAdapter({this.appSubfolder});

  /// Optional subfolder within the downloads directory.
  /// e.g. 'MyApp' → saves to Downloads/MyApp/filename.
  /// If null, saves directly to the downloads directory.
  final String? appSubfolder;

  @override
  Future<PlatformResult<String?>> saveToDevice({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      final dir = await _downloadsDir();
      final file = await reserveFreshFile(dir, sanitizeFileName(fileName));
      try {
        await file.writeAsBytes(bytes, flush: true);
      } catch (_) {
        // Don't leave the empty reserved placeholder behind.
        await _deleteQuietly(file);
        rethrow;
      }
      return PlatformSupported(file.path);
    } catch (e, st) {
      if (e is Error) rethrow; // Programmer bugs crash loudly.
      return PlatformFailed(
        'Failed to save "$fileName"',
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
      final dir = await _downloadsDir();
      final file = await reserveFreshFile(dir, sanitizeFileName(fileName));

      // Browser-style two-phase write: stream into a `.part` sibling, then
      // rename over the reserved placeholder. A failed stream never leaves
      // a half-written file under the final name.
      final part = File(
        '${file.path}.${DateTime.now().microsecondsSinceEpoch}.part',
      );
      try {
        final sink = part.openWrite();
        try {
          await sink.addStream(byteStream);
        } finally {
          await sink.close();
        }
        await part.rename(file.path);
      } catch (_) {
        await _deleteQuietly(part);
        await _deleteQuietly(file);
        rethrow;
      }
      return PlatformSupported(file.path);
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed(
        'Failed to save "$fileName"',
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
  }) async {
    try {
      // Mobile: system create-document / Files export dialog — file_picker
      // writes the bytes. Desktop: native save dialog — file_picker writes
      // the bytes to the chosen path.
      final path = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: sanitizeFileName(fileName),
        bytes: bytes,
      );
      if (path == null) {
        return const PlatformCancelled();
      }
      return PlatformSupported(path);
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed(
        'Failed to save "$fileName"',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<Directory> _downloadsDir() async {
    // getDownloadsDirectory() is supported on desktop (macOS, Windows,
    // Linux). On mobile it may return an app-private dir or null — fall
    // back to app documents.
    var dir = await getDownloadsDirectory();
    dir ??= await getApplicationDocumentsDirectory();

    if (appSubfolder != null) {
      dir = Directory('${dir.path}/${sanitizeFileName(appSubfolder!)}');
    }
    // path_provider does not guarantee the directory exists (it usually
    // does not on iOS). Creating is idempotent.
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _deleteQuietly(File file) async {
    // Best-effort cleanup on an already-failing path — the original error
    // is the one worth surfacing.
    try {
      await file.delete();
    } catch (_) {}
  }
}
