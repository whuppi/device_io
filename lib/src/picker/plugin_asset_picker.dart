import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';

import 'package:device_io/src/picker/asset_picker.dart';
import 'package:device_io/src/picker/image_options.dart';
import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/picker/web_file_pick.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/outcome.dart';

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
//     browser has it; otherwise file_picker backs the read on demand via
//     readAsBytes()/readAsByteStream() — lazy for a single pick, buffered
//     up front only for a multi-selection. The one true platform bind is
//     behind the stub-default conditional export in web_file_pick.dart,
//     not in this file.
// The other capabilities keep their native/web adapter pairs because they
// genuinely bind platform APIs.
final class PluginAssetPicker implements AssetPicker {
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
  Future<Outcome<PickedAsset>> pickImage({
    ImageOptions options = const ImageOptions(),
  }) async {
    return _pickFromSource(ImageSource.gallery, options: options);
  }

  @override
  Future<Outcome<List<PickedAsset>>> pickImages({
    ImageOptions options = const ImageOptions(),
    int? limit,
  }) async {
    try {
      final xFiles = await _picker.pickMultiImage(
        maxWidth: options.maxWidth?.toDouble(),
        maxHeight: options.maxHeight?.toDouble(),
        imageQuality: options.quality,
        limit: limit,
      );

      if (xFiles.isEmpty) {
        return const Cancelled();
      }
      return Success(xFiles.map(_fromXFile).toList());
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick images');
    } catch (e, st) {
      if (e is Error) rethrow; // Programmer bugs crash loudly.
      return Failed('Failed to pick images', error: e, stackTrace: st);
    }
  }

  @override
  Future<Outcome<PickedAsset>> captureImage({
    ImageOptions options = const ImageOptions(),
  }) async {
    if (!isCameraSupported) {
      return const Unsupported(
        'Camera capture is not available on this platform '
        '(desktop has no camera integration)',
      );
    }
    return _pickFromSource(ImageSource.camera, options: options);
  }

  // ── Video + mixed media ──

  @override
  Future<Outcome<PickedAsset>> pickVideo({Duration? maxDuration}) async {
    return _pickVideoFromSource(ImageSource.gallery, maxDuration: maxDuration);
  }

  @override
  Future<Outcome<PickedAsset>> captureVideo({Duration? maxDuration}) async {
    if (!isCameraSupported) {
      return const Unsupported(
        'Camera capture is not available on this platform '
        '(desktop has no camera integration)',
      );
    }
    return _pickVideoFromSource(ImageSource.camera, maxDuration: maxDuration);
  }

  @override
  Future<Outcome<PickedAsset>> pickMedia({
    ImageOptions options = const ImageOptions(),
  }) async {
    try {
      final xFile = await _picker.pickMedia(
        maxWidth: options.maxWidth?.toDouble(),
        maxHeight: options.maxHeight?.toDouble(),
        imageQuality: options.quality,
      );

      if (xFile == null) {
        return const Cancelled();
      }
      return Success(_fromXFile(xFile));
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick media');
    } catch (e, st) {
      if (e is Error) rethrow;
      return Failed('Failed to pick media', error: e, stackTrace: st);
    }
  }

  @override
  Future<Outcome<List<PickedAsset>>> pickMultipleMedia({
    ImageOptions options = const ImageOptions(),
    int? limit,
  }) async {
    try {
      final xFiles = await _picker.pickMultipleMedia(
        maxWidth: options.maxWidth?.toDouble(),
        maxHeight: options.maxHeight?.toDouble(),
        imageQuality: options.quality,
        limit: limit,
      );

      if (xFiles.isEmpty) {
        return const Cancelled();
      }
      return Success(xFiles.map(_fromXFile).toList());
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick media');
    } catch (e, st) {
      if (e is Error) rethrow;
      return Failed('Failed to pick media', error: e, stackTrace: st);
    }
  }

  // ── Generic files ──

  @override
  Future<Outcome<PickedAsset>> pickFile({
    List<String>? allowedExtensions,
  }) async {
    final result = await _pickPlatformFiles(
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
    );
    // The single-file counterpart to pickFiles: take the first asset.
    // (Outcome.map was removed — a sealed result is consumed by
    // exhaustive switch, with the permission-denied arm before failed.)
    return switch (result) {
      Success(:final value) => Success(value.first),
      Cancelled() => const Cancelled(),
      Unsupported(:final reason) => Unsupported(reason),
      PermissionDenied(:final message, :final error, :final stackTrace) =>
        PermissionDenied(
          message: message,
          error: error,
          stackTrace: stackTrace,
        ),
      Failed(:final message, :final error, :final stackTrace) => Failed(
        message,
        error: error,
        stackTrace: stackTrace,
      ),
    };
  }

  @override
  Future<Outcome<List<PickedAsset>>> pickFiles({
    List<String>? allowedExtensions,
  }) {
    return _pickPlatformFiles(
      allowedExtensions: allowedExtensions,
      allowMultiple: true,
    );
  }

  // ── Internals ──

  Future<Outcome<List<PickedAsset>>> _pickPlatformFiles({
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
      final type = allowedExtensions != null ? FileType.custom : FileType.any;
      // Single and multi selection are separate file_picker entry points:
      // pickFile for one, pickFiles for many. Neither is handed an
      // eager-bytes flag, so the picked files are read on demand below via
      // readAsBytes()/readAsByteStream(); only a multi-selection on a browser
      // without File System Access loads up front.
      final List<PlatformFile> files;
      if (allowMultiple) {
        final result = await FilePicker.pickFiles(
          type: type,
          allowedExtensions: allowedExtensions,
        );
        if (result == null || result.files.isEmpty) {
          return const Cancelled();
        }
        files = result.files;
      } else {
        final file = await FilePicker.pickFile(
          type: type,
          allowedExtensions: allowedExtensions,
        );
        if (file == null) {
          return const Cancelled();
        }
        files = [file];
      }

      final assets = <PickedAsset>[];
      for (final file in files) {
        final asset = _fromPlatformFile(file);
        if (asset == null) {
          // Rare plugin edge case (a path-less Android content provider).
          // Fail the whole pick rather than silently dropping a selection.
          return const Failed('Picked file has no accessible data');
        }
        assets.add(asset);
      }
      return Success(assets);
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick files');
    } catch (e, st) {
      if (e is Error) rethrow;
      return Failed('Failed to pick files', error: e, stackTrace: st);
    }
  }

  Future<Outcome<PickedAsset>> _pickFromSource(
    ImageSource source, {
    required ImageOptions options,
  }) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: options.maxWidth?.toDouble(),
        maxHeight: options.maxHeight?.toDouble(),
        imageQuality: options.quality,
      );

      if (xFile == null) {
        return const Cancelled();
      }
      return Success(_fromXFile(xFile));
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick image');
    } catch (e, st) {
      if (e is Error) rethrow;
      return Failed('Failed to pick image', error: e, stackTrace: st);
    }
  }

  Future<Outcome<PickedAsset>> _pickVideoFromSource(
    ImageSource source, {
    Duration? maxDuration,
  }) async {
    try {
      final xFile = await _picker.pickVideo(
        source: source,
        maxDuration: maxDuration,
      );

      if (xFile == null) {
        return const Cancelled();
      }
      return Success(_fromXFile(xFile));
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick video');
    } catch (e, st) {
      if (e is Error) rethrow;
      return Failed('Failed to pick video', error: e, stackTrace: st);
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

  PickedAsset? _fromPlatformFile(PlatformFile file) {
    // Android SAF without caching yields no path and (on native) no data;
    // fail the pick rather than return a lazy asset that throws on first
    // read. On web there is always a blob path to read from.
    if (!kIsWeb && file.path == null) return null;
    return PickedAsset.lazy(
      mimeType: mimeTypeFromFileName(file.name),
      fileName: file.name,
      readBytes: file.readAsBytes,
      readStream: file.readAsByteStream,
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

  Outcome<T> _failure<T>(PlatformException e, StackTrace st, String message) {
    if (_permissionCodes.contains(e.code)) {
      return PermissionDenied<T>(
        message: e.message ?? 'Permission denied',
        error: e,
        stackTrace: st,
      );
    }
    return Failed(message, error: e, stackTrace: st);
  }

  @override
  Future<Outcome<String>> pickDirectory({String? dialogTitle}) async {
    // file_picker's getDirectoryPath is native-only; the browser exposes no
    // directory path, so there is nothing to return on web. Note: file_picker
    // swallows a PlatformException (e.g. a protected/permission-denied dir) to
    // null internally, so such an error surfaces here as Cancelled, not Failed
    // — a plugin limitation, not a lost result.
    if (kIsWeb) {
      return const Unsupported('Directory picking is not available on web');
    }
    try {
      final path = await FilePicker.getDirectoryPath(dialogTitle: dialogTitle);
      if (path == null) return const Cancelled();
      return Success(path);
    } on PlatformException catch (e, st) {
      return _failure(e, st, 'Failed to pick a directory');
    } catch (e, st) {
      if (e is Error) rethrow;
      return Failed('Failed to pick a directory', error: e, stackTrace: st);
    }
  }
}
