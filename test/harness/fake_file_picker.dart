// Fake for file_picker's method channel. The adapter reaches file_picker via
// the static `FilePicker.pickFiles`, whose platform interface lives INSIDE
// package:file_picker (a banned test import). So instead of swapping a
// platform instance, this fake mocks the plugin's MethodChannel directly.
//
// The channel + method + argument map + return shape it reproduces:
//   channel  'miguelruivo.flutter.plugins.filepicker' (StandardMethodCodec)
//   method   the FileType name — 'custom' (with an extension filter) or 'any'
//   args     {allowMultipleSelection, allowedExtensions, withData,
//            compressionQuality}
//   return   invokeListMethod → List<Map>? ; each Map → PlatformFile.fromMap
//            (keys: name, path, bytes, size, identifier). null → cancelled.
//   getDirectoryPath → channel method 'dir'; returns a String? path
//            (null → cancelled).
//
// The fake RECORDS the invoked method + args and returns SCRIPTED file maps
// (or null). Tests assert both, so a gutted adapter that dropped the
// extension filter or mis-set FileType is caught.
//
// No io-exempt marker needed: this file does no file I/O. The file_picker
// PlatformFile paths it returns point at temp files the TEST created via the
// TempWorkspace harness (which carries the marker).

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');

/// A recording, scripting mock of file_picker's method channel.
final class FakeFilePicker {
  // ── recorded request ──
  bool called = false;
  String? method;
  bool? allowMultipleSelection;
  List<String>? allowedExtensions;
  bool? withData;

  // ── script ──
  List<Map<String, Object?>>? _files;
  String? _dirPath;
  bool _dirScripted = false;

  /// Script getDirectoryPath returning this path (null → cancelled).
  void returnDirectory(String? path) {
    _dirPath = path;
    _dirScripted = true;
  }

  /// Script a successful pick returning these platform-file maps.
  void returnFiles(List<Map<String, Object?>> files) => _files = files;

  /// Script a cancelled pick — the channel yields null, adapter → Cancelled.
  void returnCancelled() => _files = null;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          called = true;
          method = call.method;
          if (call.method == 'dir') {
            return _dirScripted ? _dirPath : null;
          }
          final args = (call.arguments as Map).cast<Object?, Object?>();
          allowMultipleSelection = args['allowMultipleSelection'] as bool?;
          allowedExtensions = (args['allowedExtensions'] as List?)
              ?.cast<String>();
          withData = args['withData'] as bool?;
          return _files;
        });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}
