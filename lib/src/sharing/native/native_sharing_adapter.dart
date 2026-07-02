import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:device_io/src/sharing/sharing_adapter.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Native (mobile/desktop) sharing via share_plus.
///
/// Files are staged in the OS temporary directory before sharing.
class NativeSharingAdapter implements SharingAdapter {
  @override
  Future<PlatformResult<void>> shareText({
    required String text,
    String? subject,
  }) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
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
    try {
      // Each share gets its own staging directory so concurrent shares of
      // the same fileName never collide, and the real fileName is preserved
      // (receiving apps display it).
      //
      // The staged file is deliberately NOT deleted after share() returns:
      // on Android the future resolves when the share sheet closes, but the
      // receiving app may read the content URI afterwards — deleting here
      // hands it a dead file. The staging dir lives under the OS cache
      // directory, which both Android and iOS reclaim automatically.
      final tempDir = await getTemporaryDirectory();
      final stagingDir = await Directory(
        '${tempDir.path}/device_io_share/'
        '${DateTime.now().microsecondsSinceEpoch}',
      ).create(recursive: true);
      final tempFile = File('${stagingDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes, flush: true);

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
    }
  }
}
