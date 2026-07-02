import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:device_io/src/types/platform_result.dart';
import 'package:device_io/src/download/download_adapter.dart';

/// Native (mobile/desktop) download adapter.
///
/// Saves files to the device's downloads directory (or app documents
/// on platforms where downloads dir is not accessible).
class NativeDownloadAdapter implements DownloadAdapter {
  /// Optional subfolder within the downloads directory.
  /// e.g. 'MyApp' → saves to Downloads/MyApp/filename.
  /// If null, saves directly to the downloads directory.
  final String? appSubfolder;

  NativeDownloadAdapter({this.appSubfolder});

  @override
  Future<PlatformResult<String?>> saveToDevice({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      final dir = await _downloadsDir();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return PlatformSupported(file.path);
    } catch (e) {
      return PlatformFailed('Failed to save file', error: e);
    }
  }

  @override
  Future<PlatformResult<String?>> saveStreamToDevice({
    required Stream<List<int>> byteStream,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      final dir = await _downloadsDir();
      final file = File('${dir.path}/$fileName');
      final sink = file.openWrite();
      try {
        await sink.addStream(byteStream);
      } finally {
        await sink.close();
      }
      return PlatformSupported(file.path);
    } catch (e) {
      return PlatformFailed('Failed to save file', error: e);
    }
  }

  Future<Directory> _downloadsDir() async {
    // getDownloadsDirectory() is supported on desktop (macOS, Windows, Linux).
    // On mobile it returns null — fall back to app documents.
    var dir = await getDownloadsDirectory();
    dir ??= await getApplicationDocumentsDirectory();

    if (appSubfolder != null) {
      dir = Directory('${dir.path}/$appSubfolder');
      await dir.create(recursive: true);
    }

    return dir;
  }
}
