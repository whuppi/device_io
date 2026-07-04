import 'package:meta/meta.dart';

/// Resize / recompression options for image picking and capture.
///
/// One object instead of loose parameters so a new knob never changes five
/// method signatures. All fields optional; the default `ImageOptions()`
/// means "return the image untouched".
///
/// For media picks that can return videos, these options apply to images
/// only — a picked video is returned untouched.
@immutable
final class ImageOptions {
  /// Creates image options. All fields optional.
  const ImageOptions({this.maxWidth, this.maxHeight, this.quality});

  /// Maximum width in pixels; larger images are scaled down.
  final int? maxWidth;

  /// Maximum height in pixels; larger images are scaled down.
  final int? maxHeight;

  /// Recompression quality, 0–100; null keeps the original encoding.
  final int? quality;
}
