import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import 'package:device_io/src/picker/asset_picker_adapter.dart';
import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/picker/xfile_picked_asset.dart';
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
      return PlatformSupported(xFiles.map(pickedAssetFromXFile).toList());
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick images');
    } catch (e, st) {
      if (e is Error) rethrow; // Programmer bugs crash loudly.
      return PlatformFailed('Failed to pick images', error: e, stackTrace: st);
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
    final result = await _pickPlatformFiles(
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
    );
    return result.map((assets) => assets.first);
  }

  @override
  Future<PlatformResult<List<PickedAsset>>> pickFiles({
    List<String>? allowedExtensions,
  }) {
    return _pickPlatformFiles(
      allowedExtensions: allowedExtensions,
      allowMultiple: true,
    );
  }

  Future<PlatformResult<List<PickedAsset>>> _pickPlatformFiles({
    required List<String>? allowedExtensions,
    required bool allowMultiple,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
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
        assets.add(pickedAssetFromXFile(XFile(path, name: file.name)));
      }
      return PlatformSupported(assets);
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick files');
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed('Failed to pick files', error: e, stackTrace: st);
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
      return PlatformSupported(pickedAssetFromXFile(xFile));
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick image');
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed('Failed to pick image', error: e, stackTrace: st);
    }
  }

  /// The exact permission error codes image_picker's platform
  /// implementations raise (verified against the iOS and Android plugin
  /// sources — file_picker's SAF pickers need no permissions and define
  /// none). Exact matching keeps this an explicit contract: an unknown
  /// code stays a generic failure instead of being guessed at.
  static const _permissionCodes = {
    'camera_access_denied',
    'camera_access_restricted',
    'photo_access_denied',
    'photo_access_restricted',
  };

  PlatformResult<T> _failure<T>(
    PlatformException e,
    StackTrace st,
    String message,
  ) {
    if (_permissionCodes.contains(e.code)) {
      return PlatformPermissionDenied<T>(
        message: e.message ?? 'Permission denied',
        error: e,
        stackTrace: st,
      );
    }
    return PlatformFailed(message, error: e, stackTrace: st);
  }
}
