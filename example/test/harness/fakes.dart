// Recording/scripting fakes installed at the plugins' platform-interface
// seams. Host journeys run the REAL package adapters end to end through
// the REAL example UI; only the plugin edge is scripted, and it returns
// IN-MEMORY data (XFile.fromData) so the journeys never touch dart:io —
// real filesystem effects live in integration_test, which runs on a real
// device where async I/O works normally.

import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:device_io/device_io.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// Scripts pickImage's platform edge: return an in-memory XFile carrying
/// [xfileBytes]/[xfileName], null (cancel), or throw [error]. Records that
/// it was called and with which source.
class FakeImagePickerPlatform extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  Uint8List? xfileBytes;
  String? xfileName;
  Object? error;
  bool called = false;
  ImageSource? source;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    called = true;
    this.source = source;
    if (error != null) throw error!;
    final bytes = xfileBytes;
    if (bytes == null) return null;
    return XFile.fromData(bytes, path: xfileName, mimeType: 'image/png');
  }
}

/// A PlatformException carrying image_picker's real denied code.
PlatformException photoAccessDenied() => PlatformException(
  code: 'photo_access_denied',
  message: 'The user did not allow photo access.',
);

/// Recording [SharePlatform] — the same seam law as the package suite:
/// journeys run the REAL NativeSharer; only share_plus's platform edge is
/// scripted. [received] records every ShareParams; the return is [result]
/// unless [throwError] fires first.
final class FakeSharePlatform extends SharePlatform
    with MockPlatformInterfaceMixin {
  ShareResult result = const ShareResult('handled', ShareResultStatus.success);
  Object? throwError;
  final List<ShareParams> received = [];

  @override
  Future<ShareResult> share(ShareParams params) async {
    received.add(params);
    if (throwError != null) throw throwError!;
    return result;
  }
}

/// In-memory [FileSaver] for the save journey. The native saver is
/// io-bound end to end (its own charter proves it on a real temp dir);
/// the journey's subject is the UI↔DeviceIO wiring, exercised through the
/// public `DeviceIO.custom` seam. Records the last call; replies with the
/// scripted [result].
final class RecordingFileSaver implements FileSaver {
  Outcome<SaveLocation> result = const Success(
    SavedAtPath('/inmem/save/people.csv'),
  );
  Uint8List? lastBytes;
  String? lastFileName;
  String? lastMimeType;
  String? lastDialogTitle;

  @override
  Future<Outcome<SaveLocation>> save({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    lastBytes = bytes;
    lastFileName = fileName;
    lastMimeType = mimeType;
    return result;
  }

  @override
  Future<Outcome<SaveLocation>> saveStream({
    required Stream<List<int>> byteStream,
    required String fileName,
    String? mimeType,
  }) async {
    lastFileName = fileName;
    lastMimeType = mimeType;
    return result;
  }

  @override
  Future<Outcome<SaveLocation>> saveAs({
    required Uint8List bytes,
    required String fileName,
    String? dialogTitle,
    String? mimeType,
  }) async {
    lastBytes = bytes;
    lastFileName = fileName;
    lastMimeType = mimeType;
    lastDialogTitle = dialogTitle;
    return result;
  }

  String? lastDirectory;

  @override
  Future<Outcome<SaveLocation>> saveInto({
    required String directory,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    lastDirectory = directory;
    lastBytes = bytes;
    lastFileName = fileName;
    lastMimeType = mimeType;
    return result;
  }
}

/// In-memory [FileOpener] for the open journey — same law as
/// [RecordingFileSaver]: the io-bound adapter is charter-proven; the
/// journey proves the UI wiring through `DeviceIO.custom`.
final class RecordingFileOpener implements FileOpener {
  Outcome<void> result = const Success(null);
  Uint8List? lastBytes;
  String? lastFileName;
  String? lastMimeType;
  String? lastPath;

  @override
  Future<Outcome<void>> openBytes({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    lastBytes = bytes;
    lastFileName = fileName;
    lastMimeType = mimeType;
    return result;
  }

  @override
  Future<Outcome<void>> openPath({
    required String filePath,
    String? mimeType,
  }) async {
    lastPath = filePath;
    lastMimeType = mimeType;
    return result;
  }

  SaveLocation? lastLocation;

  @override
  Future<Outcome<void>> open(SaveLocation location, {String? mimeType}) async {
    lastLocation = location;
    lastMimeType = mimeType;
    return result;
  }
}
