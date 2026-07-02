import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/platform_result.dart';
import 'package:device_io/src/picker/asset_picker_adapter.dart';

/// Web asset picker using image_picker (which uses HTML file input on web).
class WebAssetPickerAdapter implements AssetPickerAdapter {
  final _picker = ImagePicker();

  @override
  bool get isCameraSupported => false; // No camera on web.

  @override
  Future<PlatformResult<PickedAsset?>> pickImage({
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
        return const PlatformSupported(null);
      }

      final bytes = await xFile.readAsBytes();
      final mimeType = xFile.mimeType ?? mimeTypeFromFileName(xFile.name);

      return PlatformSupported(
        PickedAsset.fromBytes(
          bytes: bytes,
          mimeType: mimeType,
          fileName: xFile.name,
        ),
      );
    } catch (e) {
      return PlatformFailed('Failed to pick image', error: e);
    }
  }

  @override
  Future<PlatformResult<PickedAsset?>> captureImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    return const PlatformUnsupported('Camera is not available on web');
  }

  @override
  Future<PlatformResult<PickedAsset?>> pickFile({
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        withData: true, // Required on web — no file path access.
      );

      if (result == null || result.files.isEmpty) {
        return const PlatformSupported(null); // User cancelled.
      }

      final file = result.files.single;
      if (file.bytes == null) {
        return const PlatformFailed('File bytes unavailable on web');
      }

      final mimeType = mimeTypeFromFileName(file.name);

      return PlatformSupported(
        PickedAsset.fromBytes(
          bytes: file.bytes!,
          mimeType: mimeType,
          fileName: file.name,
        ),
      );
    } catch (e) {
      return PlatformFailed('Failed to pick file', error: e);
    }
  }
}
