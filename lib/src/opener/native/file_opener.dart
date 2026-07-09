import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show MethodChannel;

import 'package:device_io/src/runtime/native/fs.dart';
import 'package:device_io/src/opener/file_opener.dart';
import 'package:device_io/src/saver/save_location.dart';
import 'package:device_io/src/types/outcome.dart';

/// Native (mobile/desktop) file opener using the OS default app.
///
/// - macOS: `open <path>` · Linux: `xdg-open <path>` · Windows: `start`
/// - iOS/Android: open_filex (content-URI aware, permission mapped)
final class NativeFileOpener implements FileOpener {
  @override
  Future<Outcome<void>> openBytes({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      // Staged like shared files: the viewer may hold the file open long
      // after this call returns, so no eager cleanup — the OS reclaims
      // its cache directory.
      final file = await stageFile(
        purpose: 'open',
        fileName: fileName,
        write: (f) => f.writeAsBytes(bytes, flush: true),
      );
      return openPath(filePath: file.path, mimeType: mimeType);
    } catch (e, st) {
      if (e is Error) rethrow; // Programmer bugs crash loudly.
      return Failed('Failed to open "$fileName"', error: e, stackTrace: st);
    }
  }

  @override
  Future<Outcome<void>> openPath({
    required String filePath,
    String? mimeType,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return Failed('File not found: $filePath');
      }

      return switch (defaultTargetPlatform) {
        TargetPlatform.iOS ||
        TargetPlatform.android => _openMobile(filePath, mimeType),
        TargetPlatform.macOS => _openDesktop('open', [filePath]),
        TargetPlatform.linux => _openDesktop('xdg-open', [filePath]),
        TargetPlatform.windows => _openDesktop('cmd', [
          '/c',
          'start',
          '',
          filePath,
        ]),
        TargetPlatform.fuchsia => const Unsupported(
          'File opening is not supported on this platform',
        ),
      };
    } catch (e, st) {
      if (e is Error) rethrow;
      return Failed('Failed to open file', error: e, stackTrace: st);
    }
  }

  // open_filex's method channel, invoked directly instead of importing its
  // Dart API: the plugin declares only android + ios, so importing it drops
  // every desktop platform from pub.dev's attribution of THIS package. The
  // dependency stays in pubspec — it carries the Android content-URI and
  // iOS UIDocumentInteractionController native code the channel reaches.
  // open_filex protocol result codes:
  // 0 done · -1 no app · -2 not found · -3 permission denied · -4 error.
  static const _openFileChannel = MethodChannel('open_file');

  Future<Outcome<void>> _openMobile(String filePath, String? mimeType) async {
    final raw = await _openFileChannel.invokeMethod<String>('open_file', {
      'file_path': filePath,
      'type': mimeType,
      'uti': null,
    });
    // invokeMethod<String> is Future<String?> — a null response is a real
    // outcome (old plugin, unexpected native state), not a bug to crash on.
    // Without this guard `raw!` throws a TypeError, and the is-Error rethrow
    // in openPath would let it escape and crash the app.
    if (raw == null) {
      return const Failed('File opener returned no response');
    }
    final result = jsonDecode(raw) as Map<String, dynamic>;
    final message = result['message'] as String? ?? '';
    return switch (result['type'] as int?) {
      0 => const Success(null),
      -1 => const Failed('No app available to open this file type'),
      -2 => Failed('File not found: $filePath'),
      -3 => PermissionDenied(message: message),
      _ => Failed(message),
    };
  }

  Future<Outcome<void>> _openDesktop(String command, List<String> args) async {
    final result = await Process.run(command, args);
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      return Failed(
        'Failed to open file (exit code ${result.exitCode}'
        '${stderr.isEmpty ? '' : ': $stderr'})',
      );
    }
    return const Success(null);
  }

  @override
  Future<Outcome<void>> open(SaveLocation location, {String? mimeType}) async {
    return switch (location) {
      SavedAtPath(:final path) => openPath(filePath: path, mimeType: mimeType),
      // A native saver never produces SavedByBrowser, but the sealed type
      // spans both worlds; refuse it honestly rather than pretend a path.
      SavedByBrowser() => const Unsupported(
        'A browser-downloaded file has no path to open',
      ),
    };
  }
}
