import 'dart:typed_data';

import 'package:device_io/src/links/file_ref.dart';
import 'package:device_io/src/links/folder_io.dart';
import 'package:device_io/src/types/outcome.dart';

/// [FolderIo] in the browser: [Unsupported] for every method.
///
/// A browser hands out no folder grant at all — `FileLinks.pickFolder`
/// already answers `Unsupported` on the web, so no [FolderRef] a caller
/// holds could ever have come from this platform.
final class WebFolderIo implements FolderIo {
  /// Creates the web folder-IO door.
  const WebFolderIo();

  static const String _reason = 'Browsers expose no folder grants';

  @override
  Future<Outcome<Uint8List?>> read(FolderRef folder, String relativePath) =>
      _unsupported();

  @override
  Future<Outcome<void>> write(
    FolderRef folder,
    String relativePath,
    Uint8List bytes,
  ) => _unsupported();

  @override
  Future<Outcome<List<String>>> list(FolderRef folder, String prefix) =>
      _unsupported();

  @override
  Future<Outcome<void>> delete(FolderRef folder, String relativePath) =>
      _unsupported();

  Future<Outcome<T>> _unsupported<T>() async => const Unsupported(_reason);
}
