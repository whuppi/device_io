// The Apple world of NativeFolderIo, driven through a scripted method
// channel: a bookmark opens at the FOLDER itself (`open` with no
// `relative`) to resolve a local path inside a security scope held for
// exactly the length of one operation, then released.
//
// io-exempt: the channel's `open` resolves to a real temp directory this
// test writes/reads through dart:io to prove what landed on disk.
import 'dart:io';

import 'package:device_io/device_io.dart';
import 'package:device_io/src/links/links_channel.dart';
import 'package:device_io/src/links/native/folder_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Channel {
  _Channel(this.root);
  final String root;
  int opens = 0;
  int closes = 0;
  Object? Function(String id)? onOpen;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(LinksChannel.name), (
          call,
        ) async {
          final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
          switch (call.method) {
            case 'open':
              opens++;
              final open = onOpen;
              if (open != null) return open(args['id']! as String);
              return {'path': root, 'handle': opens};
            case 'close':
              closes++;
              return null;
          }
          return null;
        });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(LinksChannel.name), null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const bookmark = 'Ym9va21hcms=';
  late Directory dir;
  late _Channel channel;
  late NativeFolderIo folders;
  late FolderRef folder;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('device_io_folder_io_darwin');
    channel = _Channel(dir.path)..install();
    folders = NativeFolderIo();
    folder = FolderRef.restore(
      token: 'bookmark:$bookmark',
      displayName: 'Models',
    );
  });
  tearDown(() {
    channel.uninstall();
    dir.deleteSync(recursive: true);
  });

  test('write opens the folder\'s security scope and closes it once', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(
      await folders.write(folder, 'manifest.json', bytes),
      isA<Success<void>>(),
    );
    expect(channel.opens, 1);
    expect(channel.closes, 1);
    expect(File('${dir.path}/manifest.json').readAsBytesSync(), bytes);
  });

  test('read opens and closes the scope for exactly the one call', () async {
    File('${dir.path}/existing.txt').writeAsStringSync('hi');
    final result = await folders.read(folder, 'existing.txt');
    expect((result as Success<Uint8List?>).value, 'hi'.codeUnits);
    expect(channel.opens, 1);
    expect(channel.closes, 1);
  });

  test('a bookmark that no longer resolves fails typed, opening nothing '
      'to close', () async {
    channel.onOpen = (_) => throw PlatformException(code: 'missing');
    final result = await folders.read(folder, 'x.txt');
    expect(result, isA<Failed<Uint8List?>>());
    expect(channel.closes, 0);
  });

  test('a refused scope maps to PermissionDenied', () async {
    channel.onOpen = (_) => throw PlatformException(code: 'permission');
    expect(
      await folders.list(folder, ''),
      isA<PermissionDenied<List<String>>>(),
    );
  });

  // The Android `folder-tree:` world has no local root to open at all — it
  // crosses the channel directly instead. See
  // native_folder_io_android_test.dart.
  test('a UriToken names no folder', () async {
    final notAFolder = FolderRef.restore(
      token: 'uri:content://a',
      displayName: 'x',
    );
    expect(
      await folders.read(notAFolder, 'x.txt'),
      isA<Unsupported<Uint8List?>>(),
    );
    expect(channel.opens, 0);
  });
}
