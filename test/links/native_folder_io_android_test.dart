// The Android world of NativeFolderIo, driven through a scripted method
// channel: a tree token has no local path at all — every call crosses the
// channel, which resolves the relative path through Storage Access
// Framework document lookups on the native side.
import 'package:device_io/device_io.dart';
import 'package:device_io/src/links/links_channel.dart';
import 'package:device_io/src/links/native/folder_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Channel {
  final List<String> methods = [];
  String? lastTree;
  String? lastRelativePath;
  String? lastPrefix;
  Uint8List? lastBytes;
  Uint8List? readAnswer;
  List<String> listAnswer = const [];
  Object? Function(String method)? onThrow;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(LinksChannel.name), (
          call,
        ) async {
          methods.add(call.method);
          final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
          final thrown = onThrow?.call(call.method);
          if (thrown != null) throw thrown;
          lastTree = args['tree'] as String?;
          lastRelativePath = args['relativePath'] as String?;
          lastPrefix = args['prefix'] as String?;
          switch (call.method) {
            case 'folderRead':
              return readAnswer;
            case 'folderWrite':
              lastBytes = args['bytes'] as Uint8List?;
              return null;
            case 'folderList':
              return listAnswer;
            case 'folderDelete':
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

  const treeUri =
      'content://com.android.externalstorage.documents/tree/primary%3Amodels';
  late _Channel channel;
  late NativeFolderIo folders;
  late FolderRef folder;

  setUp(() {
    channel = _Channel()..install();
    folders = NativeFolderIo();
    folder = FolderRef.restore(
      token: 'folder-tree:$treeUri',
      displayName: 'models',
    );
  });
  tearDown(() => channel.uninstall());

  test(
    'read crosses the channel with the tree and the relative path',
    () async {
      channel.readAnswer = Uint8List.fromList([1, 2, 3]);
      final result = await folders.read(folder, 'manifest.json');
      expect((result as Success<Uint8List?>).value, [1, 2, 3]);
      expect(channel.methods, ['folderRead']);
      expect(channel.lastTree, treeUri);
      expect(channel.lastRelativePath, 'manifest.json');
    },
  );

  test('read of an absent document is a Success(null)', () async {
    channel.readAnswer = null;
    final result = await folders.read(folder, 'gone.json');
    expect((result as Success<Uint8List?>).value, isNull);
  });

  test('write crosses the channel with the bytes', () async {
    final bytes = Uint8List.fromList([9, 9, 9]);
    expect(await folders.write(folder, 'a/b.bin', bytes), isA<Success<void>>());
    expect(channel.methods, ['folderWrite']);
    expect(channel.lastTree, treeUri);
    expect(channel.lastRelativePath, 'a/b.bin');
    expect(channel.lastBytes, bytes);
  });

  test('list crosses the channel with the tree and the prefix', () async {
    channel.listAnswer = ['a.txt', 'z/b.txt'];
    final result = await folders.list(folder, 'z/');
    expect((result as Success<List<String>>).value, ['a.txt', 'z/b.txt']);
    expect(channel.methods, ['folderList']);
    expect(channel.lastTree, treeUri);
    expect(channel.lastPrefix, 'z/');
  });

  test(
    'delete crosses the channel; a missing document is still a Success',
    () async {
      expect(await folders.delete(folder, 'nope.txt'), isA<Success<void>>());
      expect(channel.methods, ['folderDelete']);
      expect(channel.lastRelativePath, 'nope.txt');
    },
  );

  test('a grant with no write half fails write with PermissionDenied — this '
      'door never re-prompts on its own', () async {
    channel.onThrow = (method) =>
        method == 'folderWrite' ? PlatformException(code: 'permission') : null;
    expect(
      await folders.write(folder, 'x.bin', Uint8List(0)),
      isA<PermissionDenied<void>>(),
    );
    expect(channel.methods, ['folderWrite']);
  });

  group('the path refusal — never reaches the channel', () {
    test('refuses a leading slash', () async {
      expect(
        await folders.write(folder, '/abs.txt', Uint8List(0)),
        isA<Failed<void>>(),
      );
      expect(channel.methods, isEmpty);
    });

    test('refuses a .. segment, anywhere in the path', () async {
      expect(
        await folders.read(folder, 'a/../../escape.txt'),
        isA<Failed<Uint8List?>>(),
      );
      expect(channel.methods, isEmpty);
    });

    test('an empty relative path names no object', () async {
      expect(await folders.delete(folder, ''), isA<Failed<void>>());
      expect(channel.methods, isEmpty);
    });
  });
}
