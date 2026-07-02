import 'dart:io';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'package:device_io/src/_shared/native_fs.dart';
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
    } catch (e, st) {
      if (e is Error) rethrow; // Programmer bugs crash loudly.
      return PlatformFailed('Failed to share text', error: e, stackTrace: st);
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

  Future<PlatformResult<void>> _shareStagedFile({
    required String fileName,
    required String? mimeType,
    required String? subject,
    required String? text,
    required Future<void> Function(File file) writeTo,
  }) async {
    try {
      final tempFile = await stageFile(
        purpose: 'share',
        fileName: fileName,
        write: writeTo,
      );

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path, mimeType: mimeType)],
          subject: subject,
          text: text,
        ),
      );
      return _fromShareResult(result);
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed(
        'Failed to share "$fileName"',
        error: e,
        stackTrace: st,
      );
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
