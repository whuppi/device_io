import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:image_picker/image_picker.dart';

import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/platform_result.dart';
import 'package:device_io/src/picker/asset_picker_adapter.dart';

/// Native (mobile/desktop) asset picker using image_picker.
class NativeAssetPickerAdapter implements AssetPickerAdapter {
  final _picker = ImagePicker();

  @override
  bool get isCameraSupported =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<PlatformResult<PickedAsset?>> pickImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    return _pickFromSource(
      ImageSource.gallery,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }

  @override
  Future<PlatformResult<PickedAsset?>> captureImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    if (!isCameraSupported) {
      return const PlatformUnsupported('Camera is not available on this platform');
    }
    return _pickFromSource(
      ImageSource.camera,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }

  @override
  Future<PlatformResult<PickedAsset?>> pickFile({
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
      );

      if (result == null || result.files.isEmpty) {
        return const PlatformSupported(null); // User cancelled.
      }

      final file = result.files.single;
      final path = file.path!;
      final mimeType = mimeTypeFromFileName(file.name);

      return PlatformSupported(PickedAsset.fromFile(
        mimeType: mimeType,
        fileName: file.name,
        readBytesFromFile: () => File(path).readAsBytes(),
        streamFromFile: () => File(path).openRead(),
      ));
    } catch (e) {
      return PlatformFailed('Failed to pick file', error: e);
    }
  }

  Future<PlatformResult<PickedAsset?>> _pickFromSource(
    ImageSource source, {
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );

      if (xFile == null) {
        return const PlatformSupported(null); // User cancelled.
      }

      final path = xFile.path;
      final mimeType = xFile.mimeType ?? mimeTypeFromFileName(xFile.name);

      return PlatformSupported(PickedAsset.fromFile(
        mimeType: mimeType,
        fileName: xFile.name,
        readBytesFromFile: () => File(path).readAsBytes(),
        streamFromFile: () => File(path).openRead(),
      ));
    } catch (e) {
      return PlatformFailed('Failed to pick image', error: e);
    }
  }

}
