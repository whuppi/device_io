// The Apple world of NativeFileLinks, driven through a scripted method
// channel: the strength verdict a pick earns from what the system minted
// for it, and the folder-child case that rides its folder's bookmark.
import 'package:device_io/device_io.dart';
import 'package:device_io/src/links/link_token.dart';
import 'package:device_io/src/links/links_channel.dart';
import 'package:device_io/src/links/native/file_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Channel {
  List<Map<String, Object?>> picked = const [];
  Map<String, Object?>? folder;
  List<Map<String, Object?>> tree = const [];
  Map<String, Object?>? described;
  Object? Function(String id)? onOpen;
  int closes = 0;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(LinksChannel.name), (
          call,
        ) async {
          final args = (call.arguments as Map?)?.cast<String, Object?>() ?? {};
          switch (call.method) {
            case 'mode':
              return 'darwin';
            case 'pickFiles':
              return picked;
            case 'pickFolder':
              return folder;
            case 'children':
              return tree;
            case 'describe':
              final d = described;
              if (d == null) throw PlatformException(code: 'missing');
              return d;
            case 'open':
              final open = onOpen;
              if (open == null) return {'path': '/tmp/q', 'handle': 1};
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
    channel = _Channel()..install();
    links = NativeFileLinks();
  });
  tearDown(() => channel.uninstall());

  const bookmark = 'Ym9va21hcms=';

  group('the verdict on a pick', () {
    test('a file the system bookmarked is durable', () async {
      channel.picked = const [
        {
          'id': bookmark,
          'name': 'q.gguf',
          'size': 7,
          'regular': true,
          'persistable': true,
        },
      ];
      final picked = await links.pickFiles();
      final candidate = (picked as Success<List<LinkCandidate>>).value.single;
      expect(candidate.strength, LinkStrength.durable);
      expect(candidate.reason, isNull);
    });

    // Catches the bug this test was written for: a sandboxed app without
    // the bookmarks entitlement gets a bare URL as the id, and a link made
    // from it can never be reopened. It must be a session candidate.
    test('a file the system could not bookmark is session-only', () async {
      channel.picked = const [
        {
          'id': 'file:///Users/someone/Models/q.gguf',
          'name': 'q.gguf',
          'size': 7,
          'regular': true,
          'persistable': false,
        },
      ];
      final picked = await links.pickFiles();
      final candidate = (picked as Success<List<LinkCandidate>>).value.single;
      expect(candidate.strength, LinkStrength.session);
      expect(candidate.reason, contains('lasting access'));
      expect(await links.link(candidate), isA<LinkNotDurable<FileRef>>());
    });

    test(
      'something that is not a regular file cannot be linked at all',
      () async {
        channel.picked = const [
          {'id': bookmark, 'name': 'q', 'regular': false, 'persistable': true},
        ];
        final picked = await links.pickFiles();
        final candidate = (picked as Success<List<LinkCandidate>>).value.single;
        expect(candidate.strength, LinkStrength.none);
      },
    );
  });

  group('a file the process can name', () {
    test('is described by the platform and carries its verdict', () async {
      channel.described = const {
        'id': bookmark,
        'name': 'own.gguf',
        'size': 3,
        'regular': true,
        'persistable': true,
      };
      final got = await links.candidateForPath('/container/own.gguf');
      final candidate = (got as Success<LinkCandidate>).value;
      expect(candidate.displayName, 'own.gguf');
      expect(candidate.strength, LinkStrength.durable);
    });

    test('nothing at the path is a missing target', () async {
      channel.described = null;
      expect(
        await links.candidateForPath('/nowhere'),
        isA<LinkTargetMissing<LinkCandidate>>(),
      );
    });
  });

  group('the copy path', () {
    // Catches: a raw channel exception escaping from readStream. The copy
    // path is the one door with no Outcome to return, so its refusal is a
    // typed error the caller can still switch on.
    test('a refused read fails with the typed refusal', () async {
      channel.picked = const [
        {
          'id': 'file:///Users/someone/Models/q.gguf',
          'name': 'q.gguf',
          'regular': true,
          'persistable': false,
        },
      ];
      channel.onOpen = (_) => throw PlatformException(code: 'missing');
      final picked = await links.pickFiles();
      final candidate = (picked as Success<List<LinkCandidate>>).value.single;
      await expectLater(
        candidate.readStream().toList(),
        throwsA(
          isA<LinkReadError>().having(
            (e) => e.refusal,
            'refusal',
            isA<LinkTargetMissing<void>>(),
          ),
        ),
      );
    });
  });

  group('a linked folder', () {
    test('its children ride the folder bookmark and are durable', () async {
      channel.folder = const {'id': bookmark, 'name': 'Models'};
      channel.tree = const [
        {
          'id': bookmark,
          'relative': 'a.gguf',
          'name': 'a.gguf',
          'size': 1,
          'regular': true,
        },
      ];
      final folder = await links.pickFolder();
      final ref = (folder as Success<FolderRef>).value;
      final children = await links.children(ref);
      final child = (children as Success<List<LinkCandidate>>).value.single;
      expect(child.strength, LinkStrength.durable);
      final linked = await links.link(child);
      final token = LinkToken.decode((linked as Success<FileRef>).value.token);
      expect(token, isA<BookmarkToken>());
      expect((token as BookmarkToken).relativePath, 'a.gguf');
    });
  });
}
