import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;

import 'package:device_io/src/types/platform_result.dart';
import 'package:device_io/src/opener/file_opener_adapter.dart';

/// Native (desktop/mobile) file opener using OS default app.
///
/// Uses the platform's standard "open" command:
/// - macOS: `open <path>`
/// - Linux: `xdg-open <path>`
/// - Windows: `start "" <path>`
/// - iOS/Android: not yet implemented (needs url_launcher with file:// URI)
class NativeFileOpenerAdapter implements FileOpenerAdapter {
  @override
  Future<PlatformResult<void>> openFile({
    required String filePath,
    String? mimeType,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return PlatformFailed('File not found: $filePath');
      }

      final (command, args) = switch (defaultTargetPlatform) {
        TargetPlatform.macOS => ('open', [filePath]),
        TargetPlatform.linux => ('xdg-open', [filePath]),
        TargetPlatform.windows => ('cmd', ['/c', 'start', '', filePath]),
        _ => (null, <String>[]),
      };

      if (command == null) {
        return const PlatformUnsupported(
          'File opening is not yet supported on this platform',
        );
      }

      final result = await Process.run(command, args);
      if (result.exitCode != 0) {
        return PlatformFailed(
          'Failed to open file (exit code ${result.exitCode})',
        );
      }

      return const PlatformSupported(null);
    } catch (e) {
      return PlatformFailed('Failed to open file', error: e);
    }
  }
}
