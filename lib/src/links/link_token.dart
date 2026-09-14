/// The wire between a [FileRef]'s opaque token and what the platform
/// layer needs to reopen it.
///
/// A token is `kind:payload`. The kinds are the four ways a platform can
/// keep a file: a path, an Android content URI (optionally a document
/// under a tree grant), an Apple bookmark (optionally a child path under a
/// folder bookmark). Two-part payloads are joined with a newline, which
/// no path, URI or base64 string contains. Apps store the string and never
/// look inside — this file is the only place that does.
library;

import 'package:device_io/src/links/file_ref.dart';

const String _sep = '\n';

/// A decoded token.
sealed class LinkToken {
  const LinkToken();

  /// Parses [token]; null when it is not one this package wrote.
  static LinkToken? decode(String token) {
    final colon = token.indexOf(':');
    if (colon <= 0) return null;
    final kind = token.substring(0, colon);
    final payload = token.substring(colon + 1);
    final parts = payload.split(_sep);
    final one = parts.length == 1 && payload.isNotEmpty;
    final two = parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty;
    return switch (kind) {
      'path' when one => PathToken(payload),
      'uri' when one => UriToken(payload),
      'tree' when two => UriToken(parts[1], treeUri: parts[0]),
      'folder-tree' when one => TreeToken(payload),
      'bookmark' when one => BookmarkToken(payload),
      'bookmark-child' when two => BookmarkToken(
        parts[0],
        relativePath: parts[1],
      ),
      _ => null,
    };
  }

  /// The string an app stores.
  String encode();
}

/// A file the process can name.
final class PathToken extends LinkToken {
  /// Creates a path token.
  const PathToken(this.path);

  /// Absolute path.
  final String path;

  @override
  String encode() => 'path:$path';
}

/// An Android document URI, optionally under a tree grant.
final class UriToken extends LinkToken {
  /// Creates a URI token.
  const UriToken(this.uri, {this.treeUri});

  /// The document URI.
  final String uri;

  /// The tree grant it was listed under, when it was.
  final String? treeUri;

  @override
  String encode() => treeUri == null ? 'uri:$uri' : 'tree:$treeUri$_sep$uri';
}

/// An Android tree grant — a linked folder.
final class TreeToken extends LinkToken {
  /// Creates a tree token.
  const TreeToken(this.treeUri);

  /// The tree URI.
  final String treeUri;

  @override
  String encode() => 'folder-tree:$treeUri';
}

/// An Apple bookmark, optionally a child under a folder bookmark.
final class BookmarkToken extends LinkToken {
  /// Creates a bookmark token.
  const BookmarkToken(this.bookmark, {this.relativePath});

  /// Base64 bookmark data.
  final String bookmark;

  /// The child's path relative to the bookmarked folder, when listed
  /// through a folder.
  final String? relativePath;

  @override
  String encode() => relativePath == null
      ? 'bookmark:$bookmark'
      : 'bookmark-child:$bookmark$_sep$relativePath';
}

/// Builds the ref an app stores for [token].
FileRef refFor(
  LinkToken token, {
  required String displayName,
  int? sizeBytes,
}) => FileRef.restore(
  token: token.encode(),
  displayName: displayName,
  sizeBytes: sizeBytes,
);
