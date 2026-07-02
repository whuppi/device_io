import 'dart:typed_data' show Uint8List;

/// A picked asset (image, file, etc.).
///
/// Use [readStream] for large files (streaming, constant memory) or
/// [readBytes] for small files (convenience). Nothing is loaded until one
/// of them is called, and each call returns a fresh read — both may be
/// called any number of times.
///
/// Laziness by source:
/// - Native picks read from disk on demand.
/// - Web image picks read from the browser blob on demand.
/// - Web generic-file picks are the one eager case — the underlying file
///   picker plugin hands over bytes, not a blob reference.
//
// DESIGN NOTE — DO NOT add a filePath or bytes field here.
//
// Paths don't exist on web. Exposing one forces every consumer into
// platform-conditional code and pulls dart:io into shared imports.
// Eager bytes kill memory on large files (video, model weights).
// The closure-based readBytes/readStream API keeps this class
// cross-platform and lazy. If native FFI needs a real path, the app
// layer should write the bytes to disk itself — that concern belongs
// outside this package.
class PickedAsset {
  /// Create from lazy read callbacks.
  ///
  /// The contract for implementers: each [readStream] call must return a
  /// FRESH stream (consumers may read more than once), and neither
  /// callback runs any I/O until invoked.
  PickedAsset.lazy({
    required this.mimeType,
    this.fileName,
    required Future<Uint8List> Function() readBytes,
    required Stream<List<int>> Function() readStream,
  }) : _readBytes = readBytes,
       _readStream = readStream;

  /// Create from in-memory bytes (when the platform already loaded them).
  factory PickedAsset.fromBytes({
    required Uint8List bytes,
    required String mimeType,
    String? fileName,
  }) {
    return PickedAsset.lazy(
      mimeType: mimeType,
      fileName: fileName,
      readBytes: () async => bytes,
      readStream: () => Stream.value(bytes),
    );
  }

  /// MIME type (e.g. "image/png", "video/mp4").
  final String mimeType;

  /// Original file name, if available.
  final String? fileName;

  final Future<Uint8List> Function() _readBytes;
  final Stream<List<int>> Function() _readStream;

  /// Read the entire asset into memory.
  ///
  /// Convenient for small files (avatars, icons, thumbnails).
  /// For large files, use [readStream] instead to avoid OOM.
  Future<Uint8List> readBytes() => _readBytes();

  /// Stream the asset data. Constant memory regardless of file size.
  ///
  /// Use for large files (photos, videos, documents) or when piping
  /// directly into storage or upload without buffering. Each call returns
  /// a fresh stream.
  Stream<List<int>> readStream() => _readStream();
}
