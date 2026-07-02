import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import 'package:device_io/src/picker/asset_picker_adapter.dart';
import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/picker/web_file_pick.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Asset picker over image_picker + file_picker — every platform.
//
// DESIGN NOTE — one adapter, no native/web split.
//
// The underlying plugins are already federated across all platforms and
// this file touches neither dart:io nor package:web, so a per-platform
// pair here would be a fake matrix: two near-identical copies diverging
// only where flagged with kIsWeb below:
//   - camera capture support (mobile only);
//   - web file picks prefer the File System Access picker (lazy) where the
//     browser has it, and fall back to file_picker's eager bytes where it
//     doesn't — the one true platform bind is behind the stub-default
//     conditional export in web_file_pick.dart, not in this file.
// The other capabilities keep their native/web adapter pairs because they
// genuinely bind platform APIs.
final class PluginAssetPickerAdapter implements AssetPickerAdapter {
  final _picker = ImagePicker();

  /// Camera capture works wherever the device is a phone/tablet — native
  /// apps AND mobile browsers (image_picker's web implementation sets the
  /// input `capture` attribute, which opens the camera there). On web,
  /// [defaultTargetPlatform] reports the underlying OS, so this needs no
  /// kIsWeb branch. Desktop is false: the desktop implementations throw
  /// unless a camera delegate is wired, which this package doesn't do.
  @override
  bool get isCameraSupported =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  // ── Images — gallery + camera ──

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
      return PlatformSupported(xFiles.map(_fromXFile).toList());
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
        'Camera capture is not available on this platform '
        '(desktop has no camera integration)',
      );
    }
    return _pickFromSource(
      ImageSource.camera,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }

  // ── Video + mixed media ──

  @override
  Future<PlatformResult<PickedAsset>> pickVideo({Duration? maxDuration}) async {
    return _pickVideoFromSource(ImageSource.gallery, maxDuration: maxDuration);
  }

  @override
  Future<PlatformResult<PickedAsset>> captureVideo({
    Duration? maxDuration,
  }) async {
    if (!isCameraSupported) {
      return const PlatformUnsupported(
        'Camera capture is not available on this platform '
        '(desktop has no camera integration)',
      );
    }
    return _pickVideoFromSource(ImageSource.camera, maxDuration: maxDuration);
  }

  @override
  Future<PlatformResult<PickedAsset>> pickMedia({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final xFile = await _picker.pickMedia(
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );

      if (xFile == null) {
        return const PlatformCancelled();
      }
      return PlatformSupported(_fromXFile(xFile));
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick media');
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed('Failed to pick media', error: e, stackTrace: st);
    }
  }

  @override
  Future<PlatformResult<List<PickedAsset>>> pickMultipleMedia({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    int? limit,
  }) async {
    try {
      final xFiles = await _picker.pickMultipleMedia(
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
        limit: limit,
      );

      if (xFiles.isEmpty) {
        return const PlatformCancelled();
      }
      return PlatformSupported(xFiles.map(_fromXFile).toList());
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick media');
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed('Failed to pick media', error: e, stackTrace: st);
    }
  }

  // ── Generic files ──

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

  // ── Internals ──

  Future<PlatformResult<List<PickedAsset>>> _pickPlatformFiles({
    required List<String>? allowedExtensions,
    required bool allowMultiple,
  }) async {
    // On web with the File System Access API, pick lazily via blob-backed
    // handles (no eager load of the whole selection). Null means the path
    // doesn't apply here — fall through to the file_picker path below.
    final lazy = await lazyWebFilePick(
      allowMultiple: allowMultiple,
      allowedExtensions: allowedExtensions,
    );
    if (lazy != null) return lazy;

    try {
      final result = await FilePicker.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        // Web file picks have no lazy handle — the plugin must hand over
        // bytes up front. Native picks stay lazy via the cached-file path.
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) {
        return const PlatformCancelled();
      }

      final assets = <PickedAsset>[];
      for (final file in result.files) {
        final asset = kIsWeb ? _fromWebBytes(file) : _fromNativePath(file);
        if (asset == null) {
          // Rare plugin edge cases (path-less Android content providers,
          // missing web bytes). Fail the whole pick rather than silently
          // dropping part of the selection.
          return const PlatformFailed('Picked file has no accessible data');
        }
        assets.add(asset);
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
      return PlatformSupported(_fromXFile(xFile));
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick image');
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed('Failed to pick image', error: e, stackTrace: st);
    }
  }

  Future<PlatformResult<PickedAsset>> _pickVideoFromSource(
    ImageSource source, {
    Duration? maxDuration,
  }) async {
    try {
      final xFile = await _picker.pickVideo(
        source: source,
        maxDuration: maxDuration,
      );

      if (xFile == null) {
        return const PlatformCancelled();
      }
      return PlatformSupported(_fromXFile(xFile));
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick video');
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed('Failed to pick video', error: e, stackTrace: st);
    }
  }

  /// Lazy on every platform: XFile is file-backed on native and
  /// blob-backed on web — nothing is read until the consumer asks.
  PickedAsset _fromXFile(XFile xFile) {
    return PickedAsset.lazy(
      mimeType: xFile.mimeType ?? mimeTypeFromFileName(xFile.name),
      fileName: xFile.name,
      readBytes: xFile.readAsBytes,
      readStream: () => xFile.openRead(),
    );
  }

  PickedAsset? _fromNativePath(PlatformFile file) {
    final path = file.path;
    if (path == null) return null;
    return _fromXFile(XFile(path, name: file.name));
  }

  PickedAsset? _fromWebBytes(PlatformFile file) {
    final bytes = file.bytes;
    if (bytes == null) return null;
    return PickedAsset.fromBytes(
      bytes: bytes,
      mimeType: mimeTypeFromFileName(file.name),
      fileName: file.name,
    );
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
