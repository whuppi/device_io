import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Platform-agnostic asset/image picking.
///
/// Implemented by `PluginAssetPickerAdapter` (all platforms — the
/// underlying image_picker / file_picker plugins are already federated).
///
/// Every method returns [PlatformCancelled] when the user dismisses the
/// picker, and [PlatformPermissionDenied] when the OS blocks access
/// (camera, photo library, storage).
abstract interface class AssetPickerAdapter {
  /// Whether camera capture is supported on this platform.
  /// UI should hide the camera button when false.
  bool get isCameraSupported;

  /// Pick an image from the device gallery/photo library.
  Future<PlatformResult<PickedAsset>> pickImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  });

  /// Pick multiple images from the device gallery/photo library.
  ///
  /// The returned list is never empty — an empty selection is
  /// [PlatformCancelled]. [limit] caps how many images the user can select
  /// on platforms that support it; ignored elsewhere.
  Future<PlatformResult<List<PickedAsset>>> pickImages({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    int? limit,
  });

  /// Capture an image from the camera.
  ///
  /// Available on phones/tablets — native apps AND mobile browsers.
  /// Returns [PlatformUnsupported] on desktop, where no camera
  /// integration exists.
  Future<PlatformResult<PickedAsset>> captureImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  });

  /// Pick a generic file (any type).
  ///
  /// [allowedExtensions] filters by file extension (e.g. ['mp3', 'wav']).
  Future<PlatformResult<PickedAsset>> pickFile({
    List<String>? allowedExtensions,
  });

  /// Pick multiple generic files (any type).
  ///
  /// The returned list is never empty — an empty selection is
  /// [PlatformCancelled]. [allowedExtensions] filters by file extension.
  Future<PlatformResult<List<PickedAsset>>> pickFiles({
    List<String>? allowedExtensions,
  });
}
