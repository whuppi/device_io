import 'dart:typed_data' show Uint8List;

/// Result of a platform IO operation that may not be supported on all platforms.
///
/// Three outcomes:
/// - [PlatformSupported] — operation succeeded with a value
/// - [PlatformUnsupported] — operation is not available on this platform
/// - [PlatformFailed] — operation is supported but failed at runtime
sealed class PlatformResult<T> {
  const PlatformResult();

  /// True if this is a [PlatformSupported] result.
  bool get isSupported => this is PlatformSupported<T>;

  /// True if this is a [PlatformUnsupported] result.
  bool get isUnsupported => this is PlatformUnsupported<T>;

  /// True if this is a [PlatformFailed] result.
  bool get isFailed => this is PlatformFailed<T>;

  /// Gets the value if supported, or null otherwise.
  T? get valueOrNull => switch (this) {
        PlatformSupported(:final value) => value,
        _ => null,
      };

  /// Execute callback based on result type.
  R when<R>({
    required R Function(T value) supported,
    required R Function(String reason) unsupported,
    required R Function(String message, Object? error) failed,
  }) {
    return switch (this) {
      PlatformSupported(:final value) => supported(value),
      PlatformUnsupported(:final reason) => unsupported(reason),
      PlatformFailed(:final message, :final error) => failed(message, error),
    };
  }

  /// Map the success value.
  PlatformResult<U> map<U>(U Function(T) transform) {
    return switch (this) {
      PlatformSupported(:final value) =>
        PlatformSupported(transform(value)),
      PlatformUnsupported(:final reason) => PlatformUnsupported(reason),
      PlatformFailed(:final message, :final error) =>
        PlatformFailed(message, error: error),
    };
  }
}

/// Operation succeeded with a value.
final class PlatformSupported<T> extends PlatformResult<T> {
  final T value;
  const PlatformSupported(this.value);

  @override
  String toString() => 'PlatformSupported($value)';
}

/// Operation is not supported on this platform.
final class PlatformUnsupported<T> extends PlatformResult<T> {
  final String reason;
  const PlatformUnsupported(this.reason);

  @override
  String toString() => 'PlatformUnsupported($reason)';
}

/// Operation is supported but failed at runtime.
final class PlatformFailed<T> extends PlatformResult<T> {
  final String message;
  final Object? error;
  const PlatformFailed(this.message, {this.error});

  @override
  String toString() => 'PlatformFailed($message)';
}

/// A picked asset (image, file, etc.).
///
/// Use [readStream] for large files (streaming, constant memory) or
/// [readBytes] for small files (convenience).
///
/// On native: data is read lazily from disk — nothing loaded until you call
/// [readBytes] or [readStream].
/// On web: data is loaded eagerly by the browser picker plugin (limitation
/// of the underlying Flutter file picker packages, not the browser itself).
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
  /// MIME type (e.g. "image/png", "video/mp4").
  final String mimeType;

  /// Original file name, if available.
  final String? fileName;

  final Future<Uint8List> Function() _readBytes;
  final Stream<List<int>> Function() _readStream;

  PickedAsset._({
    required this.mimeType,
    this.fileName,
    required Future<Uint8List> Function() readBytes,
    required Stream<List<int>> Function() readStream,
  })  : _readBytes = readBytes,
        _readStream = readStream;

  /// Create from in-memory bytes (web, or when bytes are already loaded).
  factory PickedAsset.fromBytes({
    required Uint8List bytes,
    required String mimeType,
    String? fileName,
  }) {
    return PickedAsset._(
      mimeType: mimeType,
      fileName: fileName,
      readBytes: () async => bytes,
      readStream: () => Stream.value(bytes),
    );
  }

  /// Create from a file read function (native — deferred loading).
  ///
  /// [readBytesFromFile] and [streamFromFile] are provided by the native
  /// picker adapter which has access to dart:io.
  factory PickedAsset.fromFile({
    required String mimeType,
    String? fileName,
    required Future<Uint8List> Function() readBytesFromFile,
    required Stream<List<int>> Function() streamFromFile,
  }) {
    return PickedAsset._(
      mimeType: mimeType,
      fileName: fileName,
      readBytes: readBytesFromFile,
      readStream: streamFromFile,
    );
  }

  /// Read the entire asset into memory.
  ///
  /// Convenient for small files (avatars, icons, thumbnails).
  /// For large files, use [readStream] instead to avoid OOM.
  Future<Uint8List> readBytes() => _readBytes();

  /// Stream the asset data. Constant memory regardless of file size.
  ///
  /// Use for large files (photos, videos, documents) or when piping
  /// directly into storage or upload without buffering.
  Stream<List<int>> readStream() => _readStream();
}
