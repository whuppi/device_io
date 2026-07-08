import 'package:meta/meta.dart';

/// The rectangle an iPadOS share-sheet popover anchors to, in global logical
/// coordinates.
///
/// Flutter-free on purpose: the sharing API carries no `dart:ui` dependency,
/// so it compiles and tests under plain `dart test` (not only `flutter test`).
/// The native adapter maps this to share_plus's `Rect` at the plugin
/// boundary. Required on iPad for the sheet to have somewhere to point;
/// ignored on platforms without popover anchoring (web ignores it entirely).
///
/// From a Flutter `Rect`:
/// ```dart
/// ShareOrigin.fromLTWH(rect.left, rect.top, rect.width, rect.height);
/// ```
@immutable
final class ShareOrigin {
  /// A rectangle at [left]/[top] sized [width] by [height], mirroring
  /// `Rect.fromLTWH`.
  const ShareOrigin.fromLTWH(this.left, this.top, this.width, this.height);

  /// Distance from the left edge of the coordinate space.
  final double left;

  /// Distance from the top edge of the coordinate space.
  final double top;

  /// Width of the anchor rectangle.
  final double width;

  /// Height of the anchor rectangle.
  final double height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShareOrigin &&
          other.left == left &&
          other.top == top &&
          other.width == width &&
          other.height == height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() => 'ShareOrigin.fromLTWH($left, $top, $width, $height)';
}
