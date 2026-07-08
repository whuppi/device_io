import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:device_io/src/_shared/native_fs.dart';
import 'package:device_io/src/saver/file_saver.dart';
import 'package:device_io/src/saver/save_location.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Native (mobile/desktop) file saver.
///
/// Silent saves go to the downloads directory — the user's real Downloads
/// on desktop, an app-private folder on mobile (see the interface docs).
/// [saveAs] opens the system save dialog instead.
final class NativeFileSaver implements FileSaver {
  /// Creates the saver, optionally scoping saves to [downloadsSubfolder].
  NativeFileSaver({this.downloadsSubfolder});

  /// Optional subfolder within the downloads directory.
  /// e.g. 'MyApp' → saves to Downloads/MyApp/filename.
  /// If null, saves directly to the downloads directory.
  final String? downloadsSubfolder;

  // ── Silent saves — downloads directory ──

  @override
  Future<PlatformResult<SaveLocation>> save({
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
      return PlatformSuccess(SavedAtPath(file.path));
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
  Future<PlatformResult<SaveLocation>> saveStream({
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
      return PlatformSuccess(SavedAtPath(file.path));
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed(
        'Failed to save "$fileName"',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ── User-visible save — system dialog ──

  @override
  Future<PlatformResult<SaveLocation>> saveAs({
    required Uint8List bytes,
    required String fileName,
    String? dialogTitle,
    String? mimeType, // Web-fallback concern; native dialogs infer the type.
  }) async {
    try {
      // Mobile: system create-document / Files export dialog — file_picker
      // writes the bytes. Desktop: native save dialog — file_picker writes
      // the bytes to the chosen path.
      final path = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: sanitizeFileName(fileName),
        bytes: bytes,
      );
      if (path == null) {
        return const PlatformCancelled();
      }
      return PlatformSuccess(SavedAtPath(path));
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed(
        'Failed to save "$fileName"',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ── Internals ──

  Future<Directory> _downloadsDir() async {
    // getDownloadsDirectory() is supported on desktop (macOS, Windows,
    // Linux). On mobile it may return an app-private dir or null — fall
    // back to app documents.
    var dir = await getDownloadsDirectory();
    dir ??= await getApplicationDocumentsDirectory();

    if (downloadsSubfolder != null) {
      dir = Directory('${dir.path}/${sanitizeFileName(downloadsSubfolder!)}');
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
