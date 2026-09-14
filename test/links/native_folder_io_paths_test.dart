// The paths world of NativeFolderIo — Linux and Windows, and the paths
// world's own folder token: a directory this process can already name, so
// every call goes straight to dart:io.
//
// io-exempt: this world IS dart:io — the subject reads and writes real
// temp files.
import 'dart:io';
import 'dart:typed_data';

import 'package:device_io/device_io.dart';
import 'package:device_io/src/links/native/folder_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late NativeFolderIo folders;
  late FolderRef folder;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('device_io_folder_io');
    folders = NativeFolderIo();
    folder = FolderRef.restore(token: 'path:${dir.path}', displayName: 'root');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('read of an absent object is a Success(null)', () async {
    final result = await folders.read(folder, 'missing.txt');
    expect((result as Success<Uint8List?>).value, isNull);
  });

  test('write then read round trips, creating parent directories', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    expect(
      await folders.write(folder, 'labels/manifest.bin', bytes),
      isA<Success<void>>(),
    );
    final result = await folders.read(folder, 'labels/manifest.bin');
    expect((result as Success<Uint8List?>).value, bytes);
  });

  test('a rewrite replaces the object wholesale', () async {
    await folders.write(folder, 'x.bin', Uint8List.fromList([1, 1]));
    final replaced = Uint8List.fromList([2, 2, 2]);
    await folders.write(folder, 'x.bin', replaced);
    final result = await folders.read(folder, 'x.bin');
    expect((result as Success<Uint8List?>).value, replaced);
  });

  test('list finds every object under a prefix, recursive, sorted', () async {
    await folders.write(folder, 'a.txt', Uint8List(0));
    await folders.write(folder, 'other.txt', Uint8List(0));
    await folders.write(folder, 'z/b.txt', Uint8List(0));
    await folders.write(folder, 'z/a.txt', Uint8List(0));

    final all = await folders.list(folder, '');
    expect((all as Success<List<String>>).value, [
      'a.txt',
      'other.txt',
      'z/a.txt',
      'z/b.txt',
    ]);

    final scoped = await folders.list(folder, 'z/');
    expect((scoped as Success<List<String>>).value, ['z/a.txt', 'z/b.txt']);

    final none = await folders.list(folder, 'nowhere/');
    expect((none as Success<List<String>>).value, isEmpty);
  });

  test('delete of a missing object is not an error', () async {
    expect(await folders.delete(folder, 'nope.txt'), isA<Success<void>>());
  });

  test('delete removes the object', () async {
    await folders.write(folder, 'gone.txt', Uint8List.fromList([9]));
    expect(await folders.delete(folder, 'gone.txt'), isA<Success<void>>());
    final result = await folders.read(folder, 'gone.txt');
    expect((result as Success<Uint8List?>).value, isNull);
  });

  group('the path refusal', () {
    test('refuses a leading slash', () async {
      expect(
        await folders.write(folder, '/abs.txt', Uint8List(0)),
        isA<Failed<void>>(),
      );
      expect(await folders.read(folder, '/abs.txt'), isA<Failed<Uint8List?>>());
      expect(await folders.delete(folder, '/abs.txt'), isA<Failed<void>>());
    });

    test('refuses a .. segment, anywhere in the path', () async {
      expect(
        await folders.write(folder, '../escape.txt', Uint8List(0)),
        isA<Failed<void>>(),
      );
      expect(
        await folders.read(folder, 'a/../../escape.txt'),
        isA<Failed<Uint8List?>>(),
      );
    });

    test('an empty relative path names no object', () async {
      expect(
        await folders.write(folder, '', Uint8List(0)),
        isA<Failed<void>>(),
      );
      expect(await folders.read(folder, ''), isA<Failed<Uint8List?>>());
    });

    test('an empty prefix lists everything', () async {
      await folders.write(folder, 'a.txt', Uint8List(0));
      final result = await folders.list(folder, '');
      expect((result as Success<List<String>>).value, ['a.txt']);
    });
  });

  group('the atomic write', () {
    test('a target that never existed stays absent if only a temp sibling '
        'lands', () async {
      final crashed = File('${dir.path}/staged.bin.tmp-crash')
        ..writeAsBytesSync(Uint8List.fromList([9, 9, 9]));
      addTearDown(() => crashed.deleteSync());
      final result = await folders.read(folder, 'staged.bin');
      expect((result as Success<Uint8List?>).value, isNull);
    });

    test('an existing target keeps its old bytes if only a temp sibling '
        'lands', () async {
      final old = Uint8List.fromList([1, 1, 1]);
      await folders.write(folder, 'staged.bin', old);
      final crashed = File('${dir.path}/staged.bin.tmp-crash')
        ..writeAsBytesSync(Uint8List.fromList([9, 9, 9]));
      addTearDown(() => crashed.deleteSync());
      final result = await folders.read(folder, 'staged.bin');
      expect((result as Success<Uint8List?>).value, old);
    });
  });
}
