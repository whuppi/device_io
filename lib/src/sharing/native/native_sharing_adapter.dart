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
      final result = await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );
      return _fromShareResult(result);
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
  }) {
    return _shareStagedFile(
      fileName: fileName,
      mimeType: mimeType,
      subject: subject,
      text: text,
      writeTo: (file) => file.writeAsBytes(bytes, flush: true),
    );
  }

  @override
  Future<PlatformResult<void>> shareFileStream({
    required Stream<List<int>> byteStream,
    required String fileName,
    String? mimeType,
    String? subject,
    String? text,
  }) {
    return _shareStagedFile(
      fileName: fileName,
      mimeType: mimeType,
      subject: subject,
      text: text,
      writeTo: (file) async {
        final sink = file.openWrite();
        try {
          await sink.addStream(byteStream);
        } finally {
          await sink.close();
        }
      },
    );
  }

  /// Stages the content to a fresh temp file and shares it.
  ///
  /// Each share gets its own staging directory so concurrent shares of the
  /// same fileName never collide, and the real fileName is preserved
  /// (receiving apps display it).
  ///
  /// The staged file is deliberately NOT deleted after share() returns:
  /// on Android the future resolves when the share sheet closes, but the
  /// receiving app may read the content URI afterwards — deleting here
  /// hands it a dead file. The staging dir lives under the OS cache
  /// directory, which both Android and iOS reclaim automatically.
  Future<PlatformResult<void>> _shareStagedFile({
    required String fileName,
    required String? mimeType,
    required String? subject,
    required String? text,
    required Future<void> Function(File file) writeTo,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final stagingDir = await Directory(
        '${tempDir.path}/device_io_share/'
        '${DateTime.now().microsecondsSinceEpoch}',
      ).create(recursive: true);
      final tempFile = File('${stagingDir.path}/$fileName');
      await writeTo(tempFile);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: mimeType)],
          subject: subject,
          text: text,
        ),
      );
      return _fromShareResult(result);
    } catch (e) {
      return PlatformFailed('Failed to share file', error: e);
    }
  }

  /// `unavailable` means the platform cannot report an outcome — the sheet
  /// was still shown, so it maps to success, not to a failure.
  PlatformResult<void> _fromShareResult(ShareResult result) {
    return switch (result.status) {
      ShareResultStatus.dismissed => const PlatformCancelled(),
      ShareResultStatus.success ||
      ShareResultStatus.unavailable => const PlatformSupported(null),
    };
  }
}
