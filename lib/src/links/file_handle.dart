import 'dart:async';

/// An open linked file, as the platform can hand it over.
///
/// [FilePathHandle] names a file the process can open itself; the
/// engine reads it by path. [FileDescriptorHandle] is a file the process
/// can only read — an open descriptor the engine reads through. Either
/// way, [readStream] reads the bytes (the copy path, or a header read)
/// and [close] releases what opening took (a security scope, the
/// descriptor); a caller closes when everything read from the handle is
/// finished with.
sealed class FileHandle {
  FileHandle._({
    required this.sizeBytes,
    required Future<void> Function() onClose,
    required Stream<List<int>> Function() read,
  }) : _onClose = onClose,
       _read = read;

  /// Size in bytes at open time.
  final int sizeBytes;

  final Future<void> Function() _onClose;
  final Stream<List<int>> Function() _read;
  bool _closed = false;

  /// Whether [close] has run.
  bool get isClosed => _closed;

  /// Reads the file from the start. Constant memory; each call is a
  /// fresh read. Only valid before [close].
  Stream<List<int>> readStream() {
    if (_closed) throw StateError('FileHandle is closed');
    return _read();
  }

  /// Releases the handle. Idempotent.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _onClose();
  }
}

/// A linked file the process can open by name for as long as the handle
/// is open.
final class FilePathHandle extends FileHandle {
  /// Creates a path handle. [onClose] ends whatever access made the path
  /// readable; [read] reads it while that access holds.
  FilePathHandle({
    required this.path,
    required super.sizeBytes,
    required super.onClose,
    required super.read,
  }) : super._();

  /// Absolute path, readable until [close].
  final String path;

  @override
  String toString() => 'FilePathHandle($path)';
}

/// A linked file reachable only through an open descriptor.
final class FileDescriptorHandle extends FileHandle {
  /// Creates a descriptor handle. [onClose] closes the descriptor; [read]
  /// reads through it.
  FileDescriptorHandle({
    required this.fd,
    required super.sizeBytes,
    required super.onClose,
    required super.read,
  }) : super._();

  /// The open, readable descriptor. Owned by this handle; the engine
  /// reads through a duplicate.
  final int fd;

  @override
  String toString() => 'FileDescriptorHandle($fd)';
}
