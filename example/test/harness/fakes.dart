// Recording/scripting fakes installed at the plugins' platform-interface
// seams. Host journeys run the REAL package adapters end to end through
// the REAL example UI; only the plugin edge is scripted, and it returns
// IN-MEMORY data (XFile.fromData) so the journeys never touch dart:io —
// real filesystem effects live in integration_test, which runs on a real
// device where async I/O works normally.

import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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
