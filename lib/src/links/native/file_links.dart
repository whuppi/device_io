import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import 'package:device_io/src/links/file_handle.dart';
import 'package:device_io/src/links/file_links.dart';
import 'package:device_io/src/links/file_ref.dart';
import 'package:device_io/src/links/link_budget.dart';
import 'package:device_io/src/links/link_candidate.dart';
import 'package:device_io/src/links/link_failures.dart';
import 'package:device_io/src/links/link_strength.dart';
import 'package:device_io/src/links/link_token.dart';
import 'package:device_io/src/links/links_channel.dart';
import 'package:device_io/src/types/mime_types.dart';
import 'package:device_io/src/types/outcome.dart';

/// [FileLinks] on the native platforms.
///
/// Three worlds, chosen by what the plugin channel answers — never by
/// asking the OS:
///
/// - `paths` (Linux, Windows — no native half is registered): file_picker
///   hands out paths, a path is its own durable link, and a handle is the
///   path itself.
/// - `android`: the Kotlin half runs the document picker with a
///   persistable grant, keeps the grant ledger, and opens documents to
///   detached descriptors; a linked file is read through `/proc/self/fd`.
/// - `darwin`: the Swift half runs the in-place document picker (iOS) or
///   the open panel (macOS), mints bookmarks, and holds a security scope
///   while a handle is open; a handle is the scoped path.
///
/// Every failure the channel raises is mapped once, in [_failure], to the
/// typed refusals callers switch on.
final class NativeFileLinks implements FileLinks {
  /// Creates the links door. [channel] is injectable for tests.
  NativeFileLinks({LinksChannel? channel})
    : _channel = channel ?? LinksChannel();

  final LinksChannel _channel;
  Future<String>? _mode;

  Future<String> get _world => _mode ??= _channel.mode();

  // ── Picking ──

  @override
  Future<Outcome<List<LinkCandidate>>> pickFiles({
    List<String>? allowedExtensions,
  }) => _guard(() async {
    switch (await _world) {
      case 'paths':
        return _pickPaths(allowedExtensions);
      case 'android':
        final entries = await _channel.pickFiles(
          allowedExtensions: allowedExtensions,
        );
        if (entries.isEmpty) return const Cancelled();
        return Success([for (final e in entries) _androidCandidate(e)]);
      default:
        final entries = await _channel.pickFiles(
          allowedExtensions: allowedExtensions,
        );
        if (entries.isEmpty) return const Cancelled();
        return Success([for (final e in entries) _darwinCandidate(e)]);
    }
  });

  /// The paths world's picker: file_picker hands out paths, and a path
  /// is its own durable link.
  Future<Outcome<List<LinkCandidate>>> _pickPaths(
    List<String>? allowedExtensions,
  ) async {
    final picked = await FilePicker.pickFiles(
      type: allowedExtensions == null ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    final files = picked?.files ?? const <PlatformFile>[];
    final out = <LinkCandidate>[];
    for (final file in files) {
      final path = file.path;
      if (path == null) continue;
      out.add(_pathCandidate(path, file.name, sizeBytes: file.size));
    }
    if (out.isEmpty) return const Cancelled();
    return Success(out);
  }

  @override
  Future<Outcome<FolderRef>> pickFolder() => _guard(() async {
    switch (await _world) {
      case 'paths':
        final path = await FilePicker.getDirectoryPath();
        if (path == null) return const Cancelled();
        return Success(
          FolderRef.restore(
            token: PathToken(path).encode(),
            displayName: _lastSegment(path),
          ),
        );
      case 'android':
        final picked = await _channel.pickFolder();
        if (picked == null) return const Cancelled();
        return Success(
          FolderRef.restore(
            token: TreeToken(picked['id']! as String).encode(),
            displayName: picked['name'] as String? ?? 'Folder',
          ),
        );
      default:
        final picked = await _channel.pickFolder();
        if (picked == null) return const Cancelled();
        return Success(
          FolderRef.restore(
            token: BookmarkToken(picked['id']! as String).encode(),
            displayName: picked['name'] as String? ?? 'Folder',
          ),
        );
    }
  });

  @override
  Future<Outcome<LinkCandidate>> candidateForPath(String path) => _guard(
    () async {
      switch (await _world) {
        case 'paths':
        case 'android':
          // A path this process can name is its own durable link; on
          // Android that is only ever one of the app's own files.
          final file = File(path);
          if (!file.existsSync()) return const LinkTargetMissing();
          return Success(
            _pathCandidate(
              path,
              _lastSegment(path),
              sizeBytes: await file.length(),
            ),
          );
        default:
          return Success(_darwinCandidate(await _channel.describe(path: path)));
      }
    },
  );

  @override
  Future<Outcome<List<LinkCandidate>>> children(
    FolderRef folder, {
    List<String>? allowedExtensions,
    bool recursive = false,
  }) => _guard(() async {
    final token = LinkToken.decode(folder.token);
    final wanted = allowedExtensions?.map((e) => e.toLowerCase()).toSet();
    bool allowed(String name) =>
        wanted == null || wanted.contains(_extensionOf(name));
    switch (token) {
      case PathToken(:final path):
        final dir = Directory(path);
        if (!dir.existsSync()) return const LinkTargetMissing();
        final root = dir.path.endsWith(Platform.pathSeparator)
            ? dir.path
            : '${dir.path}${Platform.pathSeparator}';
        final out = <LinkCandidate>[];
        await for (final entry in dir.list(
          recursive: recursive,
          followLinks: false,
        )) {
          if (entry is! File) continue;
          final name = _lastSegment(entry.path);
          if (!allowed(name)) continue;
          out.add(
            _pathCandidate(
              entry.path,
              name,
              sizeBytes: await entry.length(),
              relativeDirectory: _directoryOf(
                entry.path.startsWith(root)
                    ? entry.path
                          .substring(root.length)
                          .replaceAll(Platform.pathSeparator, '/')
                    : name,
              ),
            ),
          );
        }
        out.sort((a, b) => a.displayName.compareTo(b.displayName));
        return Success(out);
      case TreeToken(:final treeUri):
        final entries = await _channel.children(
          folderId: treeUri,
          allowedExtensions: allowedExtensions,
          recursive: recursive,
        );
        return Success([
          for (final e in entries)
            if (allowed(e['name'] as String? ?? ''))
              _androidCandidate(e, treeUri: treeUri),
        ]);
      case BookmarkToken(:final bookmark):
        final entries = await _channel.children(
          folderId: bookmark,
          allowedExtensions: allowedExtensions,
          recursive: recursive,
        );
        return Success([
          for (final e in entries)
            if (allowed(e['name'] as String? ?? ''))
              _darwinCandidate(e, folderBookmark: bookmark),
        ]);
      case UriToken():
      case null:
        return const Failed('Not a folder link');
    }
  });

  /// The directory part of a `/`-joined relative path — empty when the
  /// file sits at the top.
  static String _directoryOf(String relative) {
    final cut = relative.lastIndexOf('/');
    return cut < 0 ? '' : relative.substring(0, cut);
  }

  // ── Linking ──

  @override
  Future<Outcome<FileRef>> link(LinkCandidate candidate) => _guard(() async {
    if (candidate.strength != LinkStrength.durable) {
      return LinkNotDurable(
        message: candidate.reason ?? 'This file cannot be linked in place',
      );
    }
    final LinkToken token;
    switch (candidate.origin) {
      case PathOrigin(:final path):
        token = PathToken(path);
      case UriOrigin(:final uri, :final treeUri):
        if (treeUri != null) {
          // A document under a linked tree rides the tree's grant.
          token = UriToken(uri, treeUri: treeUri);
        } else {
          final ledger = await budget();
          if (!ledger.canLink) return LinkBudgetFull(budget: ledger);
          await _channel.takeGrant(uri);
          token = UriToken(uri);
        }
      case BookmarkOrigin(:final bookmark, :final relativePath):
        token = BookmarkToken(bookmark, relativePath: relativePath);
      case BlobOrigin():
        return const LinkNotDurable(
          message: 'A browser file cannot be linked in place',
        );
    }
    return Success(
      refFor(
        token,
        displayName: candidate.displayName,
        sizeBytes: candidate.sizeBytes,
      ),
    );
  });

  // ── Opening ──

  @override
  Future<Outcome<FileHandle>> open(FileRef ref) => _guard(() async {
    switch (LinkToken.decode(ref.token)) {
      case PathToken(:final path):
        final file = File(path);
        if (!file.existsSync()) return const LinkTargetMissing();
        return Success(
          FilePathHandle(
            path: path,
            sizeBytes: await file.length(),
            onClose: () async {},
            read: file.openRead,
          ),
        );
      case UriToken(:final uri):
        final opened = await _channel.open(id: uri);
        final fd = opened['fd']! as int;
        return Success(
          FileDescriptorHandle(
            fd: fd,
            sizeBytes: opened['size'] as int? ?? 0,
            onClose: () => _channel.closeHandle(fd),
            read: () => File('/proc/self/fd/$fd').openRead(),
          ),
        );
      case BookmarkToken(:final bookmark, :final relativePath):
        final opened = await _channel.open(
          id: bookmark,
          relative: relativePath,
        );
        final path = opened['path']! as String;
        final handle = opened['handle']!;
        return Success(
          FilePathHandle(
            path: path,
            sizeBytes: opened['size'] as int? ?? 0,
            onClose: () => _channel.closeHandle(handle),
            read: () => File(path).openRead(),
          ),
        );
      case TreeToken():
        return const Failed('A folder link is not a file');
      case null:
        return const Failed('Not a link this app made');
    }
  });

  // ── Releasing ──

  @override
  Future<Outcome<void>> unlink(FileRef ref) => _guard(() async {
    // Only a per-file grant was taken by [link]; a path, a bookmark and a
    // document under a tree took nothing that needs giving back.
    if (LinkToken.decode(ref.token) case UriToken(:final uri, treeUri: null)) {
      await _channel.releaseGrant(uri);
    }
    return const Success(null);
  });

  @override
  Future<Outcome<void>> unlinkFolder(FolderRef folder) => _guard(() async {
    if (LinkToken.decode(folder.token) case TreeToken(:final treeUri)) {
      await _channel.releaseGrant(treeUri);
    }
    return const Success(null);
  });

  @override
  Future<LinkBudget> budget() async {
    if (await _world != 'android') return const LinkBudget.uncounted();
    final held = await _channel.grants();
    return LinkBudget(
      used: held.length,
      capacity: await _channel.grantCapacity(),
    );
  }

  LinkCandidate _pathCandidate(
    String path,
    String name, {
    int? sizeBytes,
    String? relativeDirectory,
  }) => LinkCandidate(
    displayName: name,
    mimeType: mimeTypeFromFileName(name),
    sizeBytes: sizeBytes,
    strength: LinkStrength.durable,
    origin: PathOrigin(path),
    relativeDirectory: relativeDirectory,
    readStream: () => File(path).openRead(),
  );

  LinkCandidate _androidCandidate(
    Map<String, Object?> entry, {
    String? treeUri,
  }) {
    final uri = entry['id']! as String;
    final name = entry['name'] as String? ?? 'file';
    final regular = entry['regular'] as bool? ?? false;
    // A document reached through a tree is covered by the tree's grant.
    final persistable =
        treeUri != null || (entry['persistable'] as bool? ?? false);
    final (strength, reason) = switch ((regular, persistable)) {
      (true, true) => (LinkStrength.durable, null),
      (true, false) => (
        LinkStrength.session,
        'The provider offers no persistable access to this file',
      ),
      (false, _) => (
        LinkStrength.none,
        'The provider streams this file instead of handing it over',
      ),
    };
    final relative = entry['relative'] as String?;
    return LinkCandidate(
      displayName: name,
      mimeType: mimeTypeFromFileName(name),
      sizeBytes: entry['size'] as int?,
      strength: strength,
      reason: reason,
      origin: UriOrigin(uri, treeUri: treeUri),
      relativeDirectory: treeUri == null
          ? null
          : _directoryOf(relative ?? name),
      readStream: () => _androidStream(uri),
    );
  }

  /// Reads an Android document through a detached descriptor — the
  /// descriptor is a real file on Linux, so `/proc/self/fd/N` re-opens
  /// it for `dart:io`, and it is closed when the stream is done.
  Stream<List<int>> _androidStream(String uri) async* {
    final opened = await _openForRead(id: uri);
    final fd = opened['fd']! as int;
    try {
      yield* File('/proc/self/fd/$fd').openRead();
    } finally {
      await _channel.closeHandle(fd);
    }
  }

  /// The copy path's open. A channel refusal becomes a [LinkReadError]
  /// carrying the same typed answer [open] would give, so a stream never
  /// fails with a raw channel exception.
  Future<Map<String, Object?>> _openForRead({
    required String id,
    String? relative,
  }) async {
    try {
      return await _channel.open(id: id, relative: relative);
    } on PlatformException catch (e, st) {
      final refusal = _failure<void>(e, st);
      throw LinkReadError(
        refusal is Failed<void>
            ? refusal
            : Failed(e.message ?? e.code, error: e, stackTrace: st),
      );
    }
  }

  LinkCandidate _darwinCandidate(
    Map<String, Object?> entry, {
    String? folderBookmark,
  }) {
    final name = entry['name'] as String? ?? 'file';
    final relative = entry['relative'] as String?;
    final bookmark = folderBookmark ?? entry['id']! as String;
    final regular = entry['regular'] as bool? ?? true;
    // A child of a linked folder rides the folder's bookmark. A file picked
    // on its own is durable only when the system minted a bookmark for it;
    // a sandboxed app without the bookmark entitlement gets none, and a
    // link made anyway would be a URL nothing can reopen after this launch.
    final persistable =
        folderBookmark != null || (entry['persistable'] as bool? ?? false);
    final (strength, reason) = switch ((regular, persistable)) {
      (true, true) => (LinkStrength.durable, null),
      (true, false) => (
        LinkStrength.session,
        'The system did not hand out lasting access to this file',
      ),
      (false, _) => (LinkStrength.none, 'This is not a regular file'),
    };
    return LinkCandidate(
      displayName: name,
      mimeType: mimeTypeFromFileName(name),
      sizeBytes: entry['size'] as int?,
      strength: strength,
      reason: reason,
      origin: BookmarkOrigin(bookmark, relativePath: relative),
      relativeDirectory: folderBookmark == null
          ? null
          : _directoryOf(relative ?? name),
      readStream: () => _darwinStream(bookmark, relative),
    );
  }

  /// Reads an Apple file inside a security scope the Swift half holds
  /// for exactly the length of the stream.
  Stream<List<int>> _darwinStream(String bookmark, String? relative) async* {
    final opened = await _openForRead(id: bookmark, relative: relative);
    final handle = opened['handle']!;
    try {
      yield* File(opened['path']! as String).openRead();
    } finally {
      await _channel.closeHandle(handle);
    }
  }

  // ── The wall ──

  Future<Outcome<T>> _guard<T>(Future<Outcome<T>> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (e, st) {
      return _failure<T>(e, st);
    } on FileSystemException catch (e, st) {
      return Failed('File system: ${e.message}', error: e, stackTrace: st);
    } catch (e, st) {
      if (e is Error) rethrow;
      return Failed('Link operation failed', error: e, stackTrace: st);
    }
  }

  Outcome<T> _failure<T>(PlatformException e, StackTrace st) {
    final message = e.message ?? e.code;
    return switch (e.code) {
      'cancelled' => const Cancelled(),
      'missing' => LinkTargetMissing(
        message: message,
        error: e,
        stackTrace: st,
      ),
      'permission' => LinkPermissionGone(
        message: message,
        error: e,
        stackTrace: st,
      ),
      'notDownloaded' => LinkNotDownloaded(
        message: message,
        error: e,
        stackTrace: st,
        startDownload: () async {
          final details = e.details;
          if (details is Map) {
            await _channel.startDownload(
              id: details['id']! as String,
              relative: details['relative'] as String?,
            );
          }
        },
      ),
      _ => Failed(message, error: e, stackTrace: st),
    };
  }

  static String _lastSegment(String path) {
    final trimmed = path.endsWith('/') || path.endsWith(r'\')
        ? path.substring(0, path.length - 1)
        : path;
    final i = trimmed.lastIndexOf(RegExp(r'[/\\]'));
    return i < 0 ? trimmed : trimmed.substring(i + 1);
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}
