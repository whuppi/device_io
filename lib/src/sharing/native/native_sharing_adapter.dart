import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:device_io/src/types/platform_result.dart';
import 'package:device_io/src/sharing/sharing_adapter.dart';

/// Native (mobile/desktop) sharing via share_plus.
///
/// Handles temp file creation and cleanup internally.
class NativeSharingAdapter implements SharingAdapter {
  @override
  Future<PlatformResult<void>> shareText({
    required String text,
    String? subject,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );
      return const PlatformSupported(null);
    } catch (e) {
      return PlatformFailed('Failed to share text', error: e);
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
    File? tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: mimeType)],
          subject: subject,
          text: text,
        ),
      );
      return const PlatformSupported(null);
    } catch (e) {
      return PlatformFailed('Failed to share file', error: e);
    } finally {
      // Best-effort cleanup — temp files are also cleaned by the OS.
      try {
        await tempFile?.delete();
      } catch (_) {}
    }
  }
}
