import 'package:device_io/src/picker/image_options.dart';
import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/types/outcome.dart';

/// Platform-agnostic asset/image picking.
///
/// ```dart
/// final result = await deviceIO.picker.pickImage();
/// switch (result) {
///   case Success(:final value):
///     await upload(await value.readBytes());
///   case Cancelled():
///     break; // user changed their mind
///   case PermissionDenied():
///     promptForSettings();
///   case Unsupported(:final reason):
///   case Failed():
///     showError(result);
/// }
/// ```
///
/// Implemented by `PluginAssetPicker` (all platforms — the underlying
/// image_picker / file_picker plugins are already federated).
///
/// Every method returns [Cancelled] when the user dismisses the
/// picker, and [PermissionDenied] when the OS blocks access
/// (camera, photo library, storage).
abstract interface class AssetPicker {
  /// Whether camera capture is supported on this platform.
  ///
  /// The one pre-call probe on this interface, because UI needs it BEFORE
  /// showing a camera button — every other capability degrades at call
  /// time via [Unsupported].
  bool get isCameraSupported;

  /// Pick an image from the device gallery/photo library.
  Future<Outcome<PickedAsset>> pickImage({
    ImageOptions options = const ImageOptions(),
  });

  /// Pick multiple images from the device gallery/photo library.
  ///
  /// The returned list is never empty — an empty selection is
  /// [Cancelled]. [limit] caps how many images the user can select
  /// on platforms that support it; ignored elsewhere.
  Future<Outcome<List<PickedAsset>>> pickImages({
    ImageOptions options = const ImageOptions(),
    int? limit,
  });

  /// Capture an image from the camera.
  ///
  /// Available on phones/tablets — native apps AND mobile browsers.
  /// Returns [Unsupported] on desktop, where no camera
  /// integration exists.
  Future<Outcome<PickedAsset>> captureImage({
    ImageOptions options = const ImageOptions(),
  });

  /// Pick a video from the device gallery/photo library.
  ///
  /// [maxDuration] is a hint honored only where the platform supports it:
  /// the underlying plugin applies a duration cap to camera recording and
  /// ignores it for gallery picks, so it has no effect here on most
  /// platforms.
  Future<Outcome<PickedAsset>> pickVideo({Duration? maxDuration});

  /// Capture a video from the camera.
  ///
  /// Available on phones/tablets — native apps AND mobile browsers.
  /// Returns [Unsupported] on desktop, where no camera
  /// integration exists. [maxDuration] caps the recording length where
  /// the platform supports it.
  Future<Outcome<PickedAsset>> captureVideo({Duration? maxDuration});

  /// Pick a single image OR video from the gallery/photo library.
  ///
  /// [options] applies to images only — a picked video is returned
  /// untouched. Branch on the result's [PickedAsset.mimeType] to tell the
  /// two apart.
  Future<Outcome<PickedAsset>> pickMedia({
    ImageOptions options = const ImageOptions(),
  });

  /// Pick multiple images and/or videos from the gallery/photo library.
  ///
  /// The returned list is never empty — an empty selection is
  /// [Cancelled]. [options] applies to images only; videos are
  /// returned untouched. [limit] caps how many items the user can select
  /// on platforms that support it; ignored elsewhere.
  Future<Outcome<List<PickedAsset>>> pickMultipleMedia({
    ImageOptions options = const ImageOptions(),
    int? limit,
  });

  /// Pick a generic file (any type).
  ///
  /// [allowedExtensions] filters by file extension (e.g. ['mp3', 'wav']).
  Future<Outcome<PickedAsset>> pickFile({List<String>? allowedExtensions});

  /// Pick multiple generic files (any type).
  ///
  /// The returned list is never empty — an empty selection is
  /// [Cancelled]. [allowedExtensions] filters by file extension.
  Future<Outcome<List<PickedAsset>>> pickFiles({
    List<String>? allowedExtensions,
  });

  /// Let the user choose a directory; the returned path can be handed to
  /// `FileSaver.saveInto` to export files there.
  ///
  /// Native only — the browser exposes no directory path, so web returns
  /// [Unsupported]. On Android with the Storage Access Framework the path
  /// is a `content://` tree URI, still a valid `saveInto` target.
  Future<Outcome<String>> pickDirectory({String? dialogTitle});
}
