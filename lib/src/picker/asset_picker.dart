import 'package:device_io/src/picker/image_options.dart';
import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/types/platform_result.dart';

/// Platform-agnostic asset/image picking.
///
/// ```dart
/// final result = await deviceIO.picker.pickImage();
/// switch (result) {
///   case PlatformSuccess(:final value):
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
/// Implemented by `PluginAssetPicker` (all platforms — the underlying
/// image_picker / file_picker plugins are already federated).
///
/// Every method returns [PlatformCancelled] when the user dismisses the
/// picker, and [PlatformPermissionDenied] when the OS blocks access
/// (camera, photo library, storage).
abstract interface class AssetPicker {
  /// Whether camera capture is supported on this platform.
  ///
  /// The one pre-call probe on this interface, because UI needs it BEFORE
  /// showing a camera button — every other capability degrades at call
  /// time via [PlatformUnsupported].
  bool get isCameraSupported;

  /// Pick an image from the device gallery/photo library.
  Future<PlatformResult<PickedAsset>> pickImage({
    ImageOptions options = const ImageOptions(),
  });

  /// Pick multiple images from the device gallery/photo library.
  ///
  /// The returned list is never empty — an empty selection is
  /// [PlatformCancelled]. [limit] caps how many images the user can select
  /// on platforms that support it; ignored elsewhere.
  Future<PlatformResult<List<PickedAsset>>> pickImages({
    ImageOptions options = const ImageOptions(),
    int? limit,
  });

  /// Capture an image from the camera.
  ///
  /// Available on phones/tablets — native apps AND mobile browsers.
  /// Returns [PlatformUnsupported] on desktop, where no camera
  /// integration exists.
  Future<PlatformResult<PickedAsset>> captureImage({
    ImageOptions options = const ImageOptions(),
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
  /// [options] applies to images only — a picked video is returned
  /// untouched. Branch on the result's [PickedAsset.mimeType] to tell the
  /// two apart.
  Future<PlatformResult<PickedAsset>> pickMedia({
    ImageOptions options = const ImageOptions(),
  });

  /// Pick multiple images and/or videos from the gallery/photo library.
  ///
  /// The returned list is never empty — an empty selection is
  /// [PlatformCancelled]. [options] applies to images only; videos are
  /// returned untouched. [limit] caps how many items the user can select
  /// on platforms that support it; ignored elsewhere.
  Future<PlatformResult<List<PickedAsset>>> pickMultipleMedia({
    ImageOptions options = const ImageOptions(),
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
