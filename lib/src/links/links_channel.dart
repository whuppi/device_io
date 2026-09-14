import 'package:flutter/services.dart';

/// The method channel the native halves serve, and its whole vocabulary.
///
/// One class owns every method name and payload key so the Kotlin and
/// Swift sides have exactly one Dart contract to mirror. Every call
/// returns plain maps and lists; the typed shapes are built by
/// `NativeFileLinks`.
///
/// Error codes the native halves raise as `PlatformException.code`:
/// `missing` (no such file), `permission` (access refused or revoked),
/// `notDownloaded` (an iCloud placeholder), `pipe` (a provider that
/// streams instead of handing over a file), `cancelled`.
final class LinksChannel {
  /// Creates the channel. Tests bind a fake through the binary messenger
  /// under [name]; production uses the default channel.
  LinksChannel({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(name);

  /// The channel name both native halves register.
  static const String name = 'device_io/links';

  final MethodChannel _channel;

  /// Which native half answers: `android`, `darwin`, or — when no plugin
  /// is registered (Linux, Windows) — `paths`.
  Future<String> mode() async {
    try {
      return await _channel.invokeMethod<String>('mode') ?? 'paths';
    } on MissingPluginException {
      return 'paths';
    }
  }

  /// Opens the platform's keep-access file picker.
  /// Each entry: `{id, name, size?, regular, persistable, downloaded?}`.
  Future<List<Map<String, Object?>>> pickFiles({
    required List<String>? allowedExtensions,
  }) => _list('pickFiles', {'extensions': allowedExtensions});

  /// Opens the platform's folder picker. `{id, name}`, or null when the
  /// person cancelled.
  Future<Map<String, Object?>?> pickFolder() => _map('pickFolder', const {});

  /// Darwin: describes a file the process can already name, in the same
  /// shape [pickFiles] answers — `{id, name, size?, regular, persistable,
  /// downloaded?}`. `missing` when nothing is at [path].
  Future<Map<String, Object?>> describe({required String path}) =>
      _mapOrThrow('describe', {'path': path});

  /// Lists a linked folder's files — its own, or every file under it when
  /// [recursive]. Each entry: `{id, name, size?, regular, relative}`, where
  /// `relative` is the file's path under the folder.
  Future<List<Map<String, Object?>>> children({
    required String folderId,
    required List<String>? allowedExtensions,
    required bool recursive,
  }) => _list('children', {
    'folder': folderId,
    'extensions': allowedExtensions,
    'recursive': recursive,
  });

  /// Android: takes the persistable grant for [id].
  Future<void> takeGrant(String id) =>
      _channel.invokeMethod<void>('takeGrant', {'id': id});

  /// Android: releases the persistable grant for [id]. No error when the
  /// grant is already gone.
  Future<void> releaseGrant(String id) =>
      _channel.invokeMethod<void>('releaseGrant', {'id': id});

  /// Android: the persisted grants held. Each `{id, persistedAt}`.
  Future<List<Map<String, Object?>>> grants() => _list('grants', const {});

  /// Android: the platform's grant cap (128, or 512 from Android 11).
  Future<int> grantCapacity() async =>
      await _channel.invokeMethod<int>('grantCapacity') ?? 128;

  /// Opens [id] for reading. Android answers `{fd, size}` — a detached
  /// descriptor this side owns until [closeHandle]. Darwin answers
  /// `{path, size, handle}` — a security scope held until [closeHandle].
  /// [relative] names a child under a folder id.
  Future<Map<String, Object?>> open({required String id, String? relative}) =>
      _mapOrThrow('open', {'id': id, 'relative': relative});

  /// Releases what [open] took — closes the descriptor, or ends the
  /// security scope.
  Future<void> closeHandle(Object handle) =>
      _channel.invokeMethod<void>('close', {'handle': handle});

  /// Darwin: asks the system to download an iCloud placeholder.
  Future<void> startDownload({required String id, String? relative}) => _channel
      .invokeMethod<void>('startDownload', {'id': id, 'relative': relative});

  /// Android: bytes of the object at [relativePath] under a linked
  /// [tree]. `null` when absent.
  Future<Uint8List?> folderRead({
    required String tree,
    required String relativePath,
  }) => _channel.invokeMethod<Uint8List>('folderRead', {
    'tree': tree,
    'relativePath': relativePath,
  });

  /// Android: writes the whole object at [relativePath] under a linked
  /// [tree], creating missing parent directories. Not atomic the way the
  /// other worlds are — Storage Access Framework has no rename-over, so
  /// the native side deletes any existing object only after the new one
  /// has landed at a temporary name, then renames it into place.
  Future<void> folderWrite({
    required String tree,
    required String relativePath,
    required Uint8List bytes,
  }) => _channel.invokeMethod<void>('folderWrite', {
    'tree': tree,
    'relativePath': relativePath,
    'bytes': bytes,
  });

  /// Android: relative paths of every object under [tree] whose path
  /// starts with [prefix], recursive, sorted. `''` lists everything.
  Future<List<String>> folderList({
    required String tree,
    required String prefix,
  }) async {
    final raw = await _channel.invokeListMethod<Object?>('folderList', {
      'tree': tree,
      'prefix': prefix,
    });
    return [for (final e in raw ?? const <Object?>[]) e! as String];
  }

  /// Android: deletes the object at [relativePath] under a linked [tree].
  /// A missing object is not an error.
  Future<void> folderDelete({
    required String tree,
    required String relativePath,
  }) => _channel.invokeMethod<void>('folderDelete', {
    'tree': tree,
    'relativePath': relativePath,
  });

  Future<List<Map<String, Object?>>> _list(
    String method,
    Map<String, Object?> args,
  ) async {
    final raw = await _channel.invokeListMethod<Object?>(method, args);
    return [
      for (final entry in raw ?? const <Object?>[])
        (entry! as Map<Object?, Object?>).cast<String, Object?>(),
    ];
  }

  Future<Map<String, Object?>?> _map(
    String method,
    Map<String, Object?> args,
  ) async {
    final raw = await _channel.invokeMapMethod<Object?, Object?>(method, args);
    return raw?.cast<String, Object?>();
  }

  Future<Map<String, Object?>> _mapOrThrow(
    String method,
    Map<String, Object?> args,
  ) async {
    final raw = await _map(method, args);
    if (raw == null) {
      throw PlatformException(
        code: 'missing',
        message: '$method answered nothing',
      );
    }
    return raw;
  }
}
