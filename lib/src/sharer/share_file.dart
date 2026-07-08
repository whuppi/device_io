import 'dart:typed_data' show Uint8List;

import 'package:meta/meta.dart';

/// One file to hand to `Sharer.shareFiles`.
///
/// A file is its [bytes] plus the [fileName] the share sheet shows. Give a
/// [mimeType] to override what the receiving app infers; when null the
/// adapter derives one from the file name.
///
/// ```dart
/// await deviceIO.sharer.shareFiles(
///   files: [
///     ShareFile(bytes: pngBytes, fileName: 'chart.png'),
///     ShareFile(bytes: csvBytes, fileName: 'data.csv'),
///   ],
/// );
/// ```
@immutable
final class ShareFile {
  /// Creates a file to share. Only [bytes] and [fileName] are required.
  const ShareFile({required this.bytes, required this.fileName, this.mimeType});

  /// The file's contents.
  final Uint8List bytes;

  /// The name the share sheet displays and the receiving app writes.
  final String fileName;

  /// MIME type override. When null the adapter derives one from
  /// [fileName].
  final String? mimeType;
}
