import 'dart:typed_data' show BytesBuilder, Uint8List;

import 'package:meta/meta.dart';

import 'package:device_io/src/links/link_strength.dart';

/// One file the person picked through `FileLinks.pickFiles` (or listed
/// through `FileLinks.children`), not yet linked.
///
/// It carries the verdict — [strength] — and both ways forward: hand it
/// to `FileLinks.link` to keep it in place, or read it through
/// [readStream] to copy it. Neither is chosen for the caller.
@immutable
final class LinkCandidate {
  /// Creates a candidate. Package-internal: the platform implementations
  /// build these; apps only receive them.
  @internal
  const LinkCandidate({
    required this.displayName,
    required this.mimeType,
    required this.strength,
    required this.origin,
    required Stream<List<int>> Function() readStream,
    this.sizeBytes,
    this.reason,
    this.relativeDirectory,
  }) : _readStream = readStream;

  /// The file's name as the picker showed it.
  final String displayName;

  /// MIME type, from the platform or the name.
  final String mimeType;

  /// Size in bytes when the platform reported one.
  final int? sizeBytes;

  /// For a file listed through `FileLinks.children`: the directory it sits
  /// in, relative to the linked folder, with `/` between segments — empty
  /// for a file directly inside the folder. Null for a picked file, which
  /// was not listed under anything.
  final String? relativeDirectory;

  /// How durable a link to this file would be.
  final LinkStrength strength;

  /// Why [strength] is not [LinkStrength.durable], in the platform's own
  /// words (diagnostic, not localized). Null when it is durable.
  final String? reason;

  /// What the platform layer needs to link or open this file. Opaque to
  /// callers by design.
  @internal
  final LinkOrigin origin;

  final Stream<List<int>> Function() _readStream;

  /// Reads the file — the copy path. Constant memory; each call is a
  /// fresh read. When the platform refuses the read the stream fails with
  /// a `LinkReadError` carrying the typed refusal.
  Stream<List<int>> readStream() => _readStream();

  /// Reads the whole file into memory. For small files only. Fails the
  /// way [readStream] does.
  Future<Uint8List> readBytes() async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in _readStream()) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  @override
  String toString() => 'LinkCandidate($displayName, $strength)';
}

/// Where a candidate came from, in the platform's own vocabulary.
///
/// Package-internal. Apps never construct or inspect one.
@internal
sealed class LinkOrigin {
  const LinkOrigin();
}

/// A file the process can name.
@internal
final class PathOrigin extends LinkOrigin {
  /// Creates a path origin.
  const PathOrigin(this.path);

  /// Absolute path.
  final String path;
}

/// An Android content URI, optionally reached through a tree grant.
@internal
final class UriOrigin extends LinkOrigin {
  /// Creates a URI origin.
  const UriOrigin(this.uri, {this.treeUri});

  /// The document URI.
  final String uri;

  /// The tree grant this document was listed under, when it was.
  final String? treeUri;
}

/// An Apple bookmark, optionally a path relative to a folder bookmark.
@internal
final class BookmarkOrigin extends LinkOrigin {
  /// Creates a bookmark origin.
  const BookmarkOrigin(this.bookmark, {this.relativePath});

  /// Base64 bookmark data.
  final String bookmark;

  /// The child's path relative to the bookmarked folder, when listed
  /// through a folder.
  final String? relativePath;
}

/// A browser blob — readable now, never linkable.
@internal
final class BlobOrigin extends LinkOrigin {
  /// Creates a blob origin.
  const BlobOrigin();
}
