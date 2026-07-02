import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:device_io/src/picker/asset_picker_adapter.dart';
import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/picker/xfile_picked_asset.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Web asset picker using image_picker + file_picker (HTML file input).
///
/// Image picks are lazy — the XFile wraps a browser blob that is read on
/// demand. Generic file picks are eager (`withData`): the file picker
/// plugin hands over bytes, not a blob reference.
class WebAssetPickerAdapter implements AssetPickerAdapter {
  final _picker = ImagePicker();

  @override
  bool get isCameraSupported => false; // No camera capture on web.

  @override
  Future<PlatformResult<PickedAsset>> pickImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth?.toDouble(),
        maxHeight: maxHeight?.toDouble(),
        imageQuality: imageQuality,
      );

      if (xFile == null) {
        return const PlatformCancelled();
      }
      return PlatformSupported(pickedAssetFromXFile(xFile));
    } catch (e, st) {
      if (e is Error) rethrow; // Programmer bugs crash loudly.
      return PlatformFailed('Failed to pick image', error: e, stackTrace: st);
    }
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
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed('Failed to pick images', error: e, stackTrace: st);
    }
  }

  @override
  Future<PlatformResult<PickedAsset>> captureImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    return const PlatformUnsupported('Camera is not available on web');
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
        withData: true, // Web file picks have no lazy handle — see class doc.
      );

      if (result == null || result.files.isEmpty) {
        return const PlatformCancelled();
      }

      final assets = <PickedAsset>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) {
          return const PlatformFailed('File bytes unavailable on web');
        }
        assets.add(
          PickedAsset.fromBytes(
            bytes: bytes,
            mimeType: mimeTypeFromFileName(file.name),
            fileName: file.name,
          ),
        );
      }
      return PlatformSupported(assets);
    } catch (e, st) {
      if (e is Error) rethrow;
      return PlatformFailed('Failed to pick files', error: e, stackTrace: st);
    }
  }
}
