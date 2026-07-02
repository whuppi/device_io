import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

// The platform INTERFACE, not package:share_plus/share_plus.dart — the
// plugin's barrel unconditionally exports its Linux and Windows impls,
// which import url_launcher_linux / url_launcher_windows (each declaring
// a single platform), so importing the barrel drops every desktop
// platform from pub.dev's attribution of THIS package. The share_plus
// dependency stays in pubspec: it carries the native implementations and
// the generated plugin registrant wires SharePlatform.instance from the
// dependency alone. SharePlus.instance is a thin delegator over
// SharePlatform.instance, so behavior is identical.
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'package:device_io/src/_shared/native_fs.dart';
import 'package:device_io/src/sharing/share_file.dart';
import 'package:device_io/src/sharing/sharing_adapter.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Native (mobile/desktop) sharing via share_plus.
///
/// Files are staged in the OS temporary directory before sharing.
final class NativeSharingAdapter implements SharingAdapter {
  @override
  Future<PlatformResult<void>> shareText({
    required String text,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final result = await SharePlatform.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        ),
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
    Rect? sharePositionOrigin,
  }) {
    return _shareStagedFile(
      fileName: fileName,
      mimeType: mimeType,
      subject: subject,
      text: text,
      sharePositionOrigin: sharePositionOrigin,
      writeTo: (file) => file.writeAsBytes(bytes, flush: true),
    );
  }

  @override
  Future<PlatformResult<void>> shareFiles({
    required List<ShareFile> files,
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
  }) async {
    if (files.isEmpty) {
      throw ArgumentError.value(files, 'files', 'must not be empty');
    }
    try {
      final staged = await stageFiles(
        purpose: 'share',
        entries: [
          for (final f in files)
            (
              fileName: f.fileName,
              write: (File file) => file.writeAsBytes(f.bytes, flush: true),
            ),
        ],
      );

      final result = await SharePlatform.instance.share(
        ShareParams(
          files: [
            for (var i = 0; i < staged.length; i++)
              XFile(
                staged[i].path,
                mimeType:
                    files[i].mimeType ??
                    mimeTypeFromFileName(files[i].fileName),
              ),
          ],
          subject: subject,
          text: text,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return _fromShareResult(result);
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed(
        'Failed to share ${files.length} files',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<PlatformResult<void>> shareFileStream({
    required Stream<List<int>> byteStream,
    required String fileName,
    String? mimeType,
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
  }) {
    return _shareStagedFile(
      fileName: fileName,
      mimeType: mimeType,
      subject: subject,
      text: text,
      sharePositionOrigin: sharePositionOrigin,
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
    required Rect? sharePositionOrigin,
    required Future<void> Function(File file) writeTo,
  }) async {
    try {
      final tempFile = await stageFile(
        purpose: 'share',
        fileName: fileName,
        write: writeTo,
      );

      final result = await SharePlatform.instance.share(
        ShareParams(
          files: [
            XFile(
              tempFile.path,
              mimeType: mimeType ?? mimeTypeFromFileName(fileName),
            ),
          ],
          subject: subject,
          text: text,
          sharePositionOrigin: sharePositionOrigin,
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
