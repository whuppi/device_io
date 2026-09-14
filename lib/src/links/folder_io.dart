import 'dart:typed_data';

import 'package:device_io/src/links/file_ref.dart';
import 'package:device_io/src/types/outcome.dart';

/// Read, write, list, and delete objects inside a linked folder — a
/// content-addressed store built on the grant `FileLinks.pickFolder`
/// already holds.
///
/// Everything is relative to `folder`. `relativePath` is a forward-slash
/// path with no `..` segment and no leading slash; anything else is a
/// typed [Failed]. A write creates any missing parent directories and
/// lands atomically on most native platforms — the object holds either
/// its old bytes or its new ones, never a partial write. An Android
/// folder grant is the one exception: Storage Access Framework has no
/// atomic replace, so a crash mid-write can briefly leave the object
/// absent (never torn) — see `write`. [Unsupported] only on the web,
/// where folders carry no grant at all.
///
/// ```dart
/// final folder = await deviceIO.links.pickFolder();
/// if (folder case Success(:final value)) {
///   await deviceIO.folders.write(value, 'manifest.json', bytes);
///   final read = await deviceIO.folders.read(value, 'manifest.json');
///   final labels = await deviceIO.folders.list(value, '');
/// }
/// ```
abstract interface class FolderIo {
  /// Bytes of the object at [relativePath] under [folder]; null when
  /// absent.
  Future<Outcome<Uint8List?>> read(FolderRef folder, String relativePath);

  /// Writes the whole object at [relativePath], replacing what was there.
  /// Creates missing parent directories. Atomic on most native platforms:
  /// the bytes land at a temporary name in the same directory first, then
  /// a rename puts them at [relativePath] — a reader never observes a
  /// partial write. On an Android folder grant the same shape runs over
  /// Storage Access Framework, which has no atomic replace — the existing
  /// object is deleted only after the new one has landed at a temporary
  /// name, then the temporary name is renamed into place, so a crash
  /// between those two steps can briefly leave the object absent, never
  /// torn.
  Future<Outcome<void>> write(
    FolderRef folder,
    String relativePath,
    Uint8List bytes,
  );

  /// Relative paths of every object under [prefix], recursive, sorted.
  /// `''` lists everything under [folder].
  Future<Outcome<List<String>>> list(FolderRef folder, String prefix);

  /// Deletes the object at [relativePath]. A missing object is a
  /// [Success], not an error.
  Future<Outcome<void>> delete(FolderRef folder, String relativePath);
}
