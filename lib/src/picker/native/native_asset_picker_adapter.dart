import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import 'package:device_io/src/picker/asset_picker_adapter.dart';
import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Native (mobile/desktop) asset picker using image_picker + file_picker.
class NativeAssetPickerAdapter implements AssetPickerAdapter {
  final _picker = ImagePicker();

  @override
  bool get isCameraSupported =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<PlatformResult<PickedAsset>> pickImage({
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
  Future<PlatformResult<List<PickedAsset>>> pickImages({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    int? limit,
  }) async {
    try {
      final xFiles = await _picker.pickMultiImage(
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
        limit: limit,
      );

      if (xFiles.isEmpty) {
        return const PlatformCancelled();
      }
      return PlatformSupported(xFiles.map(_assetFromXFile).toList());
    } on PlatformException catch (e) {
      return _failure(e, 'Failed to pick images');
    } catch (e) {
      return PlatformFailed('Failed to pick images', error: e);
    }
  }

  @override
  Future<PlatformResult<PickedAsset>> captureImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    if (!isCameraSupported) {
      return const PlatformUnsupported(
        'Camera is not available on this platform',
      );
    }
    return _pickFromSource(
      ImageSource.camera,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }

  @override
  Future<PlatformResult<PickedAsset>> pickFile({
    List<String>? allowedExtensions,
  }) async {
    final result = await pickFiles(allowedExtensions: allowedExtensions);
    return result.map((assets) => assets.first);
  }

  @override
  Future<PlatformResult<List<PickedAsset>>> pickFiles({
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return const PlatformCancelled();
      }

      final assets = <PickedAsset>[];
      for (final file in result.files) {
        final path = file.path;
        if (path == null) {
          // file_picker returns path-less results in rare cases (e.g. some
          // Android content providers). Surface it as a clear failure
          // instead of silently dropping part of the selection.
          return const PlatformFailed('Picked file has no accessible path');
        }
        assets.add(
          PickedAsset.fromFile(
            mimeType: mimeTypeFromFileName(file.name),
            fileName: file.name,
            readBytesFromFile: () => File(path).readAsBytes(),
            streamFromFile: () => File(path).openRead(),
          ),
        );
      }
      return PlatformSupported(assets);
    } on PlatformException catch (e) {
      return _failure(e, 'Failed to pick files');
    } catch (e) {
      return PlatformFailed('Failed to pick files', error: e);
    }
  }

  Future<PlatformResult<PickedAsset>> _pickFromSource(
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
        return const PlatformCancelled();
      }
      return PlatformSupported(_assetFromXFile(xFile));
    } on PlatformException catch (e) {
      return _failure(e, 'Failed to pick image');
    } catch (e) {
      return PlatformFailed('Failed to pick image', error: e);
    }
  }

  PickedAsset _assetFromXFile(XFile xFile) {
    final path = xFile.path;
    return PickedAsset.fromFile(
      mimeType: xFile.mimeType ?? mimeTypeFromFileName(xFile.name),
      fileName: xFile.name,
      readBytesFromFile: () => File(path).readAsBytes(),
      streamFromFile: () => File(path).openRead(),
    );
  }

  /// Maps plugin permission errors (`camera_access_denied`,
  /// `photo_access_denied`, `read_external_storage_denied`, ...) to the
  /// typed variant; everything else stays a generic failure.
  PlatformResult<T> _failure<T>(PlatformException e, String message) {
    if (e.code.contains('denied') || e.code.contains('restricted')) {
      return PlatformPermissionDenied<T>(
        message: e.message ?? 'Permission denied',
        error: e,
      );
    }
    return PlatformFailed(message, error: e);
  }
}
