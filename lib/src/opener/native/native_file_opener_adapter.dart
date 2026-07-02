import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:open_filex/open_filex.dart';

import 'package:device_io/src/_shared/native_fs.dart';
import 'package:device_io/src/opener/file_opener_adapter.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Native (mobile/desktop) file opener using the OS default app.
///
/// - macOS: `open <path>` · Linux: `xdg-open <path>` · Windows: `start`
/// - iOS/Android: open_filex (content-URI aware, permission mapped)
final class NativeFileOpenerAdapter implements FileOpenerAdapter {
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

  Future<PlatformResult<void>> _openMobile(
    String filePath,
    String? mimeType,
  ) async {
    final result = await OpenFilex.open(filePath, type: mimeType);
    return switch (result.type) {
      ResultType.done => const PlatformSupported(null),
      ResultType.fileNotFound => PlatformFailed('File not found: $filePath'),
      ResultType.noAppToOpen => const PlatformFailed(
        'No app available to open this file type',
      ),
      ResultType.permissionDenied => PlatformPermissionDenied(
        message: result.message,
      ),
      ResultType.error => PlatformFailed(result.message),
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
    return const PlatformSupported(null);
  }
}
