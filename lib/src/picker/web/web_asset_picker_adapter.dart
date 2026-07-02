import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:device_io/src/picker/asset_picker_adapter.dart';
import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Web asset picker using image_picker + file_picker (HTML file input).
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
      return PlatformSupported(await _assetFromXFile(xFile));
    } catch (e) {
      return PlatformFailed('Failed to pick image', error: e);
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
      final assets = <PickedAsset>[];
      for (final xFile in xFiles) {
        assets.add(await _assetFromXFile(xFile));
      }
      return PlatformSupported(assets);
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
        withData: true, // Required on web — no file path access.
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
    } catch (e) {
      return PlatformFailed('Failed to pick files', error: e);
    }
  }

  Future<PickedAsset> _assetFromXFile(XFile xFile) async {
    // Web pickers load eagerly — the browser hands over the bytes directly.
    final bytes = await xFile.readAsBytes();
    return PickedAsset.fromBytes(
      bytes: bytes,
      mimeType: xFile.mimeType ?? mimeTypeFromFileName(xFile.name),
      fileName: xFile.name,
    );
  }
}
