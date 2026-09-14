import 'package:device_io/src/links/link_token.dart';
import 'package:test/test.dart';

void main() {
  group('LinkToken', () {
    test('every kind round-trips through encode / decode', () {
      const tokens = <LinkToken>[
        PathToken('/models/q.gguf'),
        UriToken('content://com.android.externalstorage.documents/document/x'),
        UriToken(
          'content://a/tree/t/document/t%2Fq.gguf',
          treeUri: 'content://a/tree/t',
        ),
        TreeToken('content://a/tree/t'),
        BookmarkToken('Ym9va21hcms='),
        BookmarkToken('Ym9va21hcms=', relativePath: 'sub/q.gguf'),
      ];
      for (final token in tokens) {
        final decoded = LinkToken.decode(token.encode());
        expect(decoded, isNotNull, reason: token.encode());
        expect(decoded!.encode(), token.encode());
        expect(decoded.runtimeType, token.runtimeType);
      }
    });

    test('a tree document keeps both the tree and the document', () {
      final decoded =
          LinkToken.decode(
                const UriToken(
                  'content://a/doc',
                  treeUri: 'content://a/tree',
                ).encode(),
              )
              as UriToken;
      expect(decoded.treeUri, 'content://a/tree');
      expect(decoded.uri, 'content://a/doc');
    });

    test(
      'a bookmark child keeps the folder bookmark and the relative path',
      () {
        final decoded =
            LinkToken.decode(
                  const BookmarkToken(
                    'Zm9sZGVy',
                    relativePath: 'q.gguf',
                  ).encode(),
                )
                as BookmarkToken;
        expect(decoded.bookmark, 'Zm9sZGVy');
        expect(decoded.relativePath, 'q.gguf');
      },
    );

    test('a path with a colon survives — only the FIRST colon splits', () {
      final decoded =
          LinkToken.decode(const PathToken(r'C:\models\q.gguf').encode())
              as PathToken;
      expect(decoded.path, r'C:\models\q.gguf');
    });

    test('refuses what this package never wrote', () {
      expect(LinkToken.decode(''), isNull);
      expect(LinkToken.decode('nonsense'), isNull);
      expect(LinkToken.decode('path:'), isNull);
      expect(LinkToken.decode('file:///x'), isNull);
      expect(LinkToken.decode('tree:only-one-part'), isNull);
      expect(LinkToken.decode('bookmark-child:\nq'), isNull);
    });

    test('refFor carries the stored fields', () {
      final ref = refFor(
        const PathToken('/a.gguf'),
        displayName: 'a.gguf',
        sizeBytes: 12,
      );
      expect(ref.token, 'path:/a.gguf');
      expect(ref.displayName, 'a.gguf');
      expect(ref.sizeBytes, 12);
    });
  });
}
