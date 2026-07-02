import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Platform-agnostic asset/image picking.
///
/// ```dart
/// final result = await deviceIO.assetPicker.pickImage();
/// switch (result) {
///   case PlatformSupported(:final value):
///     await upload(await value.readBytes());
///   case PlatformCancelled():
///     break; // user changed their mind
///   case PlatformPermissionDenied():
///     promptForSettings();
///   case PlatformUnsupported(:final reason):
///   case PlatformFailed():
///     showError(result);
/// }
/// ```
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

  /// Pick a video from the device gallery/photo library.
  ///
  /// [maxDuration] is a hint honored only where the platform supports it:
  /// the underlying plugin applies a duration cap to camera recording and
  /// ignores it for gallery picks, so it has no effect here on most
  /// platforms.
  Future<PlatformResult<PickedAsset>> pickVideo({Duration? maxDuration});

  /// Capture a video from the camera.
  ///
  /// Available on phones/tablets — native apps AND mobile browsers.
  /// Returns [PlatformUnsupported] on desktop, where no camera
  /// integration exists. [maxDuration] caps the recording length where
  /// the platform supports it.
  Future<PlatformResult<PickedAsset>> captureVideo({Duration? maxDuration});

  /// Pick a single image OR video from the gallery/photo library.
  ///
  /// The resize options ([maxWidth], [maxHeight], [imageQuality]) apply to
  /// images only — a picked video is returned untouched. Branch on the
  /// result's [PickedAsset.mimeType] to tell the two apart.
  ///
  /// ```dart
  /// final result = await deviceIO.assetPicker.pickMedia();
  /// switch (result) {
  ///   case PlatformSupported(:final value):
  ///     final isVideo = value.mimeType.startsWith('video/');
  ///     await upload(await value.readBytes(), isVideo: isVideo);
  ///   case PlatformCancelled():
  ///     break; // user changed their mind
  ///   case PlatformPermissionDenied():
  ///     promptForSettings();
  ///   case PlatformUnsupported(:final reason):
  ///   case PlatformFailed():
  ///     showError(result);
  /// }
  /// ```
  Future<PlatformResult<PickedAsset>> pickMedia({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  });

  /// Pick multiple images and/or videos from the gallery/photo library.
  ///
  /// The returned list is never empty — an empty selection is
  /// [PlatformCancelled]. The resize options ([maxWidth], [maxHeight],
  /// [imageQuality]) apply to images only; videos are returned untouched.
  /// [limit] caps how many items the user can select on platforms that
  /// support it; ignored elsewhere.
  Future<PlatformResult<List<PickedAsset>>> pickMultipleMedia({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
    int? limit,
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
