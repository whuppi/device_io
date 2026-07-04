import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show MethodChannel;

import 'package:device_io/src/_shared/native_fs.dart';
import 'package:device_io/src/opener/file_opener.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Native (mobile/desktop) file opener using the OS default app.
///
/// - macOS: `open <path>` · Linux: `xdg-open <path>` · Windows: `start`
/// - iOS/Android: open_filex (content-URI aware, permission mapped)
final class NativeFileOpener implements FileOpener {
  @override
  Future<PlatformResult<void>> openBytes({
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
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return PlatformFailed('File not found: $filePath');
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
        TargetPlatform.fuchsia => const PlatformUnsupported(
          'File opening is not supported on this platform',
        ),
      };
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed('Failed to open file', error: e, stackTrace: st);
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

  Future<PlatformResult<void>> _openMobile(
    String filePath,
    String? mimeType,
  ) async {
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
      return const PlatformFailed('File opener returned no response');
    }
    final result = jsonDecode(raw) as Map<String, dynamic>;
    final message = result['message'] as String? ?? '';
    return switch (result['type'] as int?) {
      0 => const PlatformSuccess(null),
      -1 => const PlatformFailed('No app available to open this file type'),
      -2 => PlatformFailed('File not found: $filePath'),
      -3 => PlatformPermissionDenied(message: message),
      _ => PlatformFailed(message),
    };
  }

  Future<PlatformResult<void>> _openDesktop(
    String command,
    List<String> args,
  ) async {
    final result = await Process.run(command, args);
    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      return PlatformFailed(
        'Failed to open file (exit code ${result.exitCode}'
        '${stderr.isEmpty ? '' : ': $stderr'})',
      );
    }
    return const PlatformSuccess(null);
  }
}
