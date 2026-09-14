// The Android world of NativeFileLinks, driven through a scripted method
// channel: the grant ledger, the strength verdict, the budget refusal,
// the typed refusals on open, and the /proc/self/fd read path's shape.
//
// io-exempt: the android stream reads `/proc/self/fd/N` through dart:io;
// on the VM the test hands the channel a descriptor-free open so the
// shape (open → stream → close) is exercised without a real fd.
import 'dart:io';

import 'package:device_io/device_io.dart';
import 'package:device_io/src/links/links_channel.dart';
import 'package:device_io/src/links/native/file_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Channel {
  _Channel(this.mode);
  final String mode;
  final List<MethodCall> calls = [];
  final Set<String> granted = {};
  int capacity = 512;
  List<Map<String, Object?>> picked = const [];
  Map<String, Object?>? folder;
  List<Map<String, Object?>> tree = const [];
  Object? Function(String id)? onOpen;
  int closes = 0;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(LinksChannel.name), (
          call,
        ) async {
          calls.add(call);
          final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
          switch (call.method) {
            case 'mode':
              return mode;
            case 'pickFiles':
              return picked;
            case 'pickFolder':
              return folder;
            case 'children':
              return tree;
            case 'takeGrant':
              granted.add(args['id']! as String);
              return null;
            case 'releaseGrant':
              granted.remove(args['id']);
              return null;
            case 'grants':
              return [
                for (final g in granted) {'id': g, 'persistedAt': 1},
              ];
            case 'grantCapacity':
              return capacity;
            case 'open':
              final open = onOpen;
              if (open == null) return {'fd': 42, 'size': 10};
              return open(args['id']! as String);
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
  late _Channel channel;
  late NativeFileLinks links;

  setUp(() {
    channel = _Channel('android')..install();
    links = NativeFileLinks();
  });
  tearDown(() => channel.uninstall());

  const local =
      'content://com.android.externalstorage.documents/document/primary%3Aq.gguf';

  group('the verdict', () {
    test('a regular file with a persistable grant is durable', () async {
      channel.picked = [
        {
          'id': local,
          'name': 'q.gguf',
          'size': 9,
          'regular': true,
          'persistable': true,
        },
      ];
      final picked = await links.pickFiles(allowedExtensions: ['gguf']);
      final candidate = (picked as Success<List<LinkCandidate>>).value.single;
      expect(candidate.strength, LinkStrength.durable);
      expect(candidate.reason, isNull);
      expect(candidate.mimeType, isNotEmpty);
      expect(candidate.sizeBytes, 9);
    });

    test(
      'a regular file without a persistable grant is session-only',
      () async {
        channel.picked = [
          {
            'id': local,
            'name': 'q.gguf',
            'regular': true,
            'persistable': false,
          },
        ];
        final picked = await links.pickFiles();
        final candidate = (picked as Success<List<LinkCandidate>>).value.single;
        expect(candidate.strength, LinkStrength.session);
        expect(candidate.reason, contains('persistable'));
      },
    );

    test('a pipe cannot be linked at all', () async {
      channel.picked = [
        {
          'id': 'content://cloud/doc',
          'name': 'q.gguf',
          'regular': false,
          'persistable': true,
        },
      ];
      final picked = await links.pickFiles();
      final candidate = (picked as Success<List<LinkCandidate>>).value.single;
      expect(candidate.strength, LinkStrength.none);
      expect(await links.link(candidate), isA<LinkNotDurable<FileRef>>());
    });

    test('an empty selection is Cancelled, never an empty list', () async {
      channel.picked = const [];
      expect(await links.pickFiles(), isA<Cancelled<List<LinkCandidate>>>());
    });
  });

  group('the ledger', () {
    test('linking takes the grant; unlinking releases it', () async {
      channel.picked = [
        {'id': local, 'name': 'q.gguf', 'regular': true, 'persistable': true},
      ];
      final candidate =
          ((await links.pickFiles()) as Success<List<LinkCandidate>>)
              .value
              .single;
      final linked = await links.link(candidate);
      final ref = (linked as Success<FileRef>).value;
      expect(channel.granted, {local});
      expect(ref.token, 'uri:$local');
      expect(ref.displayName, 'q.gguf');
      expect(await links.budget(), const LinkBudget(used: 1, capacity: 512));

      expect(await links.unlink(ref), isA<Success<void>>());
      expect(channel.granted, isEmpty);
      expect(await links.budget(), const LinkBudget(used: 0, capacity: 512));
    });

    test('refuses a new per-file link at the reserve, and says so', () async {
      channel.capacity = 128;
      for (var i = 0; i < 128 - LinkBudget.reserve; i++) {
        channel.granted.add('content://a/$i');
      }
      channel.picked = [
        {'id': local, 'name': 'q.gguf', 'regular': true, 'persistable': true},
      ];
      final candidate =
          ((await links.pickFiles()) as Success<List<LinkCandidate>>)
              .value
              .single;
      final linked = await links.link(candidate);
      expect(linked, isA<LinkBudgetFull<FileRef>>());
      expect((linked as LinkBudgetFull<FileRef>).budget.used, 120);
      expect(channel.granted, isNot(contains(local)));
    });

    test('a folder is one grant; its children cost nothing more', () async {
      const treeUri =
          'content://com.android.externalstorage.documents/tree/primary%3Amodels';
      channel.folder = {'id': treeUri, 'name': 'models'};
      channel.tree = [
        {
          'id': '$treeUri/document/a',
          'name': 'a.gguf',
          'size': 1,
          'regular': true,
        },
        {
          'id': '$treeUri/document/b',
          'name': 'b.txt',
          'size': 1,
          'regular': true,
        },
      ];
      final folder = ((await links.pickFolder()) as Success<FolderRef>).value;
      expect(folder.token, 'folder-tree:$treeUri');
      expect(folder.displayName, 'models');

      final kids =
          ((await links.children(folder, allowedExtensions: ['gguf']))
                  as Success<List<LinkCandidate>>)
              .value;
      expect(kids.map((k) => k.displayName), ['a.gguf']);
      expect(kids.single.strength, LinkStrength.durable);

      final before = channel.calls.length;
      final ref = ((await links.link(kids.single)) as Success<FileRef>).value;
      expect(
        channel.calls.skip(before).map((c) => c.method),
        isNot(contains('takeGrant')),
      );
      expect(ref.token, startsWith('tree:$treeUri\n'));

      expect(await links.unlinkFolder(folder), isA<Success<void>>());
      expect(channel.calls.last.method, 'releaseGrant');
    });
  });

  group('opening', () {
    final ref = FileRef.restore(token: 'uri:$local', displayName: 'q.gguf');

    test('hands over a descriptor handle and closes it once', () async {
      channel.onOpen = (_) => {'fd': 17, 'size': 2048};
      final opened = await links.open(ref);
      final handle = (opened as Success<FileHandle>).value;
      expect(handle, isA<FileDescriptorHandle>());
      expect((handle as FileDescriptorHandle).fd, 17);
      expect(handle.sizeBytes, 2048);
      await handle.close();
      await handle.close();
      expect(channel.closes, 1);
    });

    test('maps the channel codes to the typed refusals', () async {
      channel.onOpen = (_) => throw PlatformException(code: 'missing');
      expect(await links.open(ref), isA<LinkTargetMissing<FileHandle>>());
      channel.onOpen = (_) => throw PlatformException(code: 'permission');
      expect(await links.open(ref), isA<LinkPermissionGone<FileHandle>>());
      channel.onOpen = (_) => throw PlatformException(code: 'pipe');
      final pipe = await links.open(ref);
      expect(pipe, isA<Failed<FileHandle>>());
      expect(pipe, isNot(isA<LinkTargetMissing<FileHandle>>()));
    });

    test('a folder token is not a file', () async {
      final folderAsFile = FileRef.restore(
        token: 'folder-tree:content://a/tree/t',
        displayName: 't',
      );
      expect(await links.open(folderAsFile), isA<Failed<FileHandle>>());
    });

    test('a token this package never wrote is refused', () async {
      final foreign = FileRef.restore(token: 'garbage', displayName: 'x');
      expect(await links.open(foreign), isA<Failed<FileHandle>>());
    });

    // Catches: a raw channel exception escaping from readStream on the
    // copy path.
    test('a refused copy-path read fails with the typed refusal', () async {
      channel.picked = [
        {'id': local, 'name': 'q.gguf', 'regular': true, 'persistable': false},
      ];
      channel.onOpen = (_) => throw PlatformException(code: 'permission');
      final picked = await links.pickFiles();
      final candidate = (picked as Success<List<LinkCandidate>>).value.single;
      await expectLater(
        candidate.readStream().toList(),
        throwsA(
          isA<LinkReadError>().having(
            (e) => e.refusal,
            'refusal',
            isA<LinkPermissionGone<void>>(),
          ),
        ),
      );
    });
  });

  group('a file the process can name', () {
    test('an own file is a durable path candidate', () async {
      final dir = await Directory.systemTemp.createTemp('links');
      final file = File('${dir.path}/own.gguf')..writeAsBytesSync([1, 2, 3]);
      final got = await links.candidateForPath(file.path);
      final candidate = (got as Success<LinkCandidate>).value;
      expect(candidate.strength, LinkStrength.durable);
      expect(candidate.sizeBytes, 3);
      expect(await candidate.readBytes(), [1, 2, 3]);
      dir.deleteSync(recursive: true);
    });

    test('nothing at the path is a missing target', () async {
      expect(
        await links.candidateForPath('/nowhere/at/all.gguf'),
        isA<LinkTargetMissing<LinkCandidate>>(),
      );
    });
  });

  test('a darwin world answers an uncounted budget', () async {
    channel.uninstall();
    channel = _Channel('darwin')..install();
    links = NativeFileLinks();
    expect(await links.budget(), const LinkBudget.uncounted());
  });
}
