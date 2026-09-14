import 'dart:async';
import 'dart:io';

import 'package:device_io/src/links/file_ref.dart';
import 'package:device_io/src/links/folder_io.dart';
import 'package:device_io/src/links/link_token.dart';
import 'package:device_io/src/links/links_channel.dart';
import 'package:device_io/src/types/outcome.dart';
import 'package:flutter/services.dart';

/// [FolderIo] on the native platforms.
///
/// Reads a folder's token the way `NativeFileLinks.open` reads a file's: a
/// [PathToken] is a directory this process can already name — Linux and
/// Windows, and the paths world's `pickFolder` result — so every call goes
/// straight to `dart:io`. A [BookmarkToken] (Apple) is opened at the
/// FOLDER itself — the channel's `open` with no `relative`, the same call
/// a file uses — which resolves it to a local path inside a security
/// scope held for exactly the length of this one operation, then released.
/// A [TreeToken] (Android) has no local path at all: every call crosses
/// the channel, which resolves the relative path one Storage Access
/// Framework document at a time. Its write is NOT atomic the way the other two
/// worlds are — the provider has no rename-over, so the native side
/// deletes any existing object only after the replacement has landed at a
/// temporary name, then renames it into place; a crash between those two
/// steps can leave the object briefly absent, never torn. A grant taken
/// before this door could write (read-only) fails a write with
/// [PermissionDenied] — the caller re-picks, this door never re-prompts on
/// its own. [Unsupported] on the web, where folders carry no grant at all.
final class NativeFolderIo implements FolderIo {
  /// Creates the folder-IO door. [channel] is injectable for tests.
  NativeFolderIo({LinksChannel? channel})
    : _channel = channel ?? LinksChannel();

  final LinksChannel _channel;
  int _tempCounter = 0;

  @override
  Future<Outcome<Uint8List?>> read(FolderRef folder, String relativePath) =>
      _guard(() async {
        final rel = _validate(relativePath);
        if (rel == null) return const Failed('Not a legal relative path');
        return _dispatch(
          folder,
          onRoot: (root) async {
            final file = File(_join(root, rel));
            if (!file.existsSync()) return const Success(null);
            return Success(await file.readAsBytes());
          },
          onTree: (tree) async =>
              Success(await _channel.folderRead(tree: tree, relativePath: rel)),
        );
      });

  @override
  Future<Outcome<void>> write(
    FolderRef folder,
    String relativePath,
    Uint8List bytes,
  ) => _guard(() async {
    final rel = _validate(relativePath);
    if (rel == null) return const Failed('Not a legal relative path');
    return _dispatch(
      folder,
      onRoot: (root) async {
        final target = File(_join(root, rel));
        await target.parent.create(recursive: true);
        final tmp = File(
          '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}-${_tempCounter++}',
        );
        await tmp.writeAsBytes(bytes, flush: true);
        await tmp.rename(target.path);
        return const Success(null);
      },
      onTree: (tree) async {
        await _channel.folderWrite(tree: tree, relativePath: rel, bytes: bytes);
        return const Success(null);
      },
    );
  });

  @override
  Future<Outcome<List<String>>> list(FolderRef folder, String prefix) =>
      _guard(() async {
        final pfx = _validate(prefix, allowEmpty: true);
        if (pfx == null) return const Failed('Not a legal prefix');
        return _dispatch(
          folder,
          onRoot: (root) async {
            final dir = Directory(root);
            if (!dir.existsSync()) return const Success(<String>[]);
            final out = <String>[];
            await for (final entry in dir.list(
              recursive: true,
              followLinks: false,
            )) {
              if (entry is! File) continue;
              final rel = _relativeOf(root, entry.path);
              if (rel.startsWith(pfx)) out.add(rel);
            }
            out.sort();
            return Success(out);
          },
          onTree: (tree) async =>
              Success(await _channel.folderList(tree: tree, prefix: pfx)),
        );
      });

  @override
  Future<Outcome<void>> delete(FolderRef folder, String relativePath) =>
      _guard(() async {
        final rel = _validate(relativePath);
        if (rel == null) return const Failed('Not a legal relative path');
        return _dispatch(
          folder,
          onRoot: (root) async {
            final file = File(_join(root, rel));
            if (file.existsSync()) await file.delete();
            return const Success(null);
          },
          onTree: (tree) async {
            await _channel.folderDelete(tree: tree, relativePath: rel);
            return const Success(null);
          },
        );
      });

  /// Resolves [folder] and runs the matching callback: [onRoot] against a
  /// local directory path (a [PathToken], or a [BookmarkToken] opened at
  /// the folder itself for exactly the call), [onTree] against a tree URI
  /// (a [TreeToken] — every call crosses the channel, there is no local
  /// path).
  Future<Outcome<T>> _dispatch<T>(
    FolderRef folder, {
    required Future<Outcome<T>> Function(String root) onRoot,
    required Future<Outcome<T>> Function(String treeUri) onTree,
  }) async {
    switch (LinkToken.decode(folder.token)) {
      case PathToken(:final path):
        return await onRoot(path);
      case BookmarkToken(:final bookmark):
        final opened = await _channel.open(id: bookmark);
        final root = opened['path']! as String;
        final handle = opened['handle']!;
        try {
          return await onRoot(root);
        } finally {
          await _channel.closeHandle(handle);
        }
      case TreeToken(:final treeUri):
        return await onTree(treeUri);
      case UriToken():
      case null:
        return const Unsupported('Not a folder link');
    }
  }

  Future<Outcome<T>> _guard<T>(Future<Outcome<T>> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (e, st) {
      final message = e.message ?? e.code;
      return e.code == 'permission'
          ? PermissionDenied(message: message, error: e, stackTrace: st)
          : Failed(message, error: e, stackTrace: st);
    } on FileSystemException catch (e, st) {
      return Failed('File system: ${e.message}', error: e, stackTrace: st);
    } catch (e, st) {
      if (e is Error) rethrow;
      return Failed('Folder operation failed', error: e, stackTrace: st);
    }
  }

  /// Normalizes [path] to the forward-slash form this door stores objects
  /// under, refusing a leading slash or a `..` segment. [allowEmpty] lets
  /// `list`'s prefix be `''` (everything); a read/write/delete target
  /// never is.
  static String? _validate(String path, {bool allowEmpty = false}) {
    if (path.isEmpty) return allowEmpty ? '' : null;
    if (path.startsWith('/')) return null;
    if (path.split('/').any((segment) => segment == '..')) return null;
    return path;
  }

  static String _join(String root, String relative) {
    final native = relative.split('/').join(Platform.pathSeparator);
    final base = root.endsWith(Platform.pathSeparator)
        ? root
        : '$root${Platform.pathSeparator}';
    return '$base$native';
  }

  static String _relativeOf(String root, String fullPath) {
    final base = root.endsWith(Platform.pathSeparator)
        ? root
        : '$root${Platform.pathSeparator}';
    final relative = fullPath.startsWith(base)
        ? fullPath.substring(base.length)
        : fullPath;
    return relative.replaceAll(Platform.pathSeparator, '/');
  }
}
