import 'package:device_io/src/types/platform_result.dart';

/// Platform-agnostic asset/image picking.
///
/// Implementations:
/// - `NativeAssetPickerAdapter` — wraps image_picker (mobile/desktop)
/// - `WebAssetPickerAdapter` — HTML file input (web)
abstract interface class AssetPickerAdapter {
  /// Whether camera capture is supported on this platform.
  /// UI should hide the camera button when false.
  bool get isCameraSupported;

  /// Pick an image from the device gallery/photo library.
  ///
  /// Returns [PlatformSupported(null)] if the user cancelled.
  Future<PlatformResult<PickedAsset?>> pickImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  });

  /// Capture an image from the camera.
  ///
  /// Returns [PlatformUnsupported] on platforms without camera access (web).
  /// Returns [PlatformSupported(null)] if the user cancelled.
  Future<PlatformResult<PickedAsset?>> captureImage({
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  });

  /// Pick a generic file (any type).
  ///
  /// [allowedExtensions] filters by file extension (e.g. ['mp3', 'wav']).
  /// Returns [PlatformSupported(null)] if the user cancelled.
  Future<PlatformResult<PickedAsset?>> pickFile({
    List<String>? allowedExtensions,
  });
}
