import 'package:meta/meta.dart';

/// A durable reference to a file the person picked and the app linked
/// in place — a path, a bookmark, or a content grant, sealed inside
/// [token].
///
/// The app stores [token], [displayName] and [sizeBytes] like any other
/// row and hands the ref back to `FileLinks.open` later. It never parses
/// the token: what a token is made of is the package's business and
/// differs per platform.
@immutable
final class FileRef {
  /// Rebuilds a ref from stored fields. The only way an app constructs
  /// one — fresh refs come from `FileLinks.link`.
  const FileRef.restore({
    required this.token,
    required this.displayName,
    this.sizeBytes,
  });

  /// Opaque, serialisable. Store it; never parse it.
  final String token;

  /// The file's name as the picker showed it.
  final String displayName;

  /// The file's size when it was linked, when the platform reported one.
  final int? sizeBytes;

  @override
  bool operator ==(Object other) =>
      other is FileRef &&
      other.token == token &&
      other.displayName == displayName &&
      other.sizeBytes == sizeBytes;

  @override
  int get hashCode => Object.hash(token, displayName, sizeBytes);

  @override
  String toString() => 'FileRef($displayName)';
}

/// A durable reference to a folder the person picked — ONE grant that
/// covers every file under it. `FileLinks.children` lists them; linking
/// a child costs nothing more.
@immutable
final class FolderRef {
  /// Rebuilds a ref from stored fields.
  const FolderRef.restore({required this.token, required this.displayName});

  /// Opaque, serialisable. Store it; never parse it.
  final String token;

  /// The folder's name as the picker showed it.
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is FolderRef &&
      other.token == token &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(token, displayName);

  @override
  String toString() => 'FolderRef($displayName)';
}
