// CHARTER — this file alone proves, in a REAL browser, the WebSharer's
// behavior against an instrumented navigator.share/canShare: shareText passes
// title (subject) + text through to the ShareData and maps a resolved share()
// to Success(null); shareFile/shareFiles build N File objects with the right
// names/types (one file's bytes read back via File.arrayBuffer match the
// declared bytes); rejection name-mapping — AbortError → Cancelled,
// NotAllowedError → PermissionDenied, an unlisted DOMException → Failed,
// NotSupportedError → Unsupported; the feature-detection path with `share`
// DELETED → Unsupported; shareFiles([]) throws ArgumentError before any JS is
// touched; shareFileStream buffers a multi-chunk stream then shares one File
// whose size equals the stream total.
// Diet: declared byte fixtures from ../harness/bytes.dart; inline literals here.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:device_io/src/sharer/share_file.dart';
import 'package:device_io/src/sharer/web/sharer.dart';
import 'package:device_io/src/types/platform_result.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../harness/bytes.dart';
import '../../harness/timeouts.dart';
import 'js_overrides.dart';

void main() {
  final adapter = WebSharer();
  final overrides = <PropOverride>[];

  // What an instrumented navigator.share recorded.
  web.ShareData? recorded;

  /// Installs share() (resolving) + canShare()→true, recording the ShareData.
  void installShare({JSAny? rejectWith}) {
    recorded = null;
    overrides.add(
      PropOverride.install(
        navigatorObj,
        'share',
        ((JSObject data) {
          recorded = data as web.ShareData;
          return rejectWith == null
              ? jsResolve<JSAny?>(null)
              : jsReject<JSAny?>(rejectWith);
        }).toJS,
      ),
    );
    overrides.add(
      PropOverride.install(
        navigatorObj,
        'canShare',
        ((JSObject data) => true).toJS,
      ),
    );
  }

  tearDown(() {
    restoreAll(overrides);
    overrides.clear();
    // Tests that never install a share (the empty-list guard) assert that
    // nothing was recorded — don't let a previous test's recording leak in.
    recorded = null;
  });

  // ── shareText: title + text pass-through ──

  test(
    'shareText passes subject as title and text through → Success',
    () async {
      installShare();
      final result = await adapter.shareText(
        text: 'hello body',
        subject: 'the title',
      );

      expect(result, isA<PlatformSuccess<void>>());
      expect(recorded, isNotNull);
      expect(readString(recorded! as JSObject, 'title'), 'the title');
      expect(readString(recorded! as JSObject, 'text'), 'hello body');
    },
    timeout: t(4),
  );

  // ── shareFile / shareFiles: File objects with names/types + content ──

  test(
    'shareFiles records N Files with correct names/types and bytes',
    () async {
      installShare();
      final result = await adapter.shareFiles(
        files: [
          ShareFile(bytes: patternedBytes(2048), fileName: 'chart.png'),
          ShareFile(bytes: utf8SampleBytes, fileName: 'data.csv'),
        ],
        subject: 'two files',
      );

      expect(result, isA<PlatformSuccess<void>>());
      final files = (recorded! as JSObject)
          .getProperty<JSArray<web.File>>('files'.toJS)
          .toDart;
      expect(files.length, 2);

      expect(files[0].name, 'chart.png');
      expect(files[0].type, 'image/png'); // inferred from name
      expect(files[1].name, 'data.csv');
      expect(files[1].type, 'text/csv');

      // Read one file's content back and check it against the declared bytes.
      final firstBytes = await blobBytes(files[0]);
      expect(isPatterned(firstBytes), isTrue);
    },
    timeout: t(5),
  );

  test('shareFile records a single File and passes text alongside', () async {
    installShare();
    final result = await adapter.shareFile(
      bytes: utf8SampleBytes,
      fileName: 'note.txt',
      text: 'see attached',
    );

    expect(result, isA<PlatformSuccess<void>>());
    final files = (recorded! as JSObject)
        .getProperty<JSArray<web.File>>('files'.toJS)
        .toDart;
    expect(files.length, 1);
    expect(files[0].name, 'note.txt');
    expect(files[0].type, 'text/plain');
    expect(readString(recorded! as JSObject, 'text'), 'see attached');
  }, timeout: t(5));

  // ── rejection name-mapping ──

  test('share() AbortError → Cancelled', () async {
    installShare(rejectWith: domException('AbortError'));
    final result = await adapter.shareText(text: 'x');
    expect(result, isA<PlatformCancelled<void>>());
  }, timeout: t(4));

  test('share() NotAllowedError → PermissionDenied', () async {
    installShare(rejectWith: domException('NotAllowedError'));
    final result = await adapter.shareText(text: 'x');
    expect(result, isA<PlatformPermissionDenied<void>>());
  }, timeout: t(4));

  test('share() NotSupportedError → Unsupported', () async {
    installShare(rejectWith: domException('NotSupportedError'));
    final result = await adapter.shareText(text: 'x');
    expect(result, isA<PlatformUnsupported<void>>());
  }, timeout: t(4));

  test('share() unlisted DOMException → Failed', () async {
    installShare(rejectWith: domException('DataError'));
    final result = await adapter.shareText(text: 'x');
    expect(result, isA<PlatformFailed<void>>());
    // Not the PermissionDenied subtype — a plain Failed.
    expect(result, isNot(isA<PlatformPermissionDenied<void>>()));
  }, timeout: t(4));

  // ── feature detection: share absent → Unsupported ──

  test('shareText with navigator.share absent → Unsupported', () async {
    overrides.add(PropOverride.remove(navigatorObj, 'share'));
    final result = await adapter.shareText(text: 'x');
    expect(result, isA<PlatformUnsupported<void>>());
  }, timeout: t(4));

  // ── shareFiles([]) throws before any JS ──

  test('shareFiles([]) throws ArgumentError before touching JS', () async {
    // No share installed — the empty-list guard must fire first.
    await expectLater(
      adapter.shareFiles(files: const []),
      throwsA(isA<ArgumentError>()),
    );
    expect(recorded, isNull);
  }, timeout: t(4));

  // ── shareFileStream: buffered fully then shared ──

  test(
    'shareFileStream buffers a multi-chunk stream then shares one File',
    () async {
      installShare();

      const total = 3000;
      final source = patternedBytes(total);
      Stream<List<int>> chunks() async* {
        var offset = 0;
        for (final size in const [500, 2000, 500]) {
          yield source.sublist(offset, offset + size);
          offset += size;
        }
      }

      final result = await adapter.shareFileStream(
        byteStream: chunks(),
        fileName: 'clip.mp4',
      );

      expect(result, isA<PlatformSuccess<void>>());
      final files = (recorded! as JSObject)
          .getProperty<JSArray<web.File>>('files'.toJS)
          .toDart;
      expect(files.length, 1);
      expect(files[0].name, 'clip.mp4');
      expect(files[0].size, total);
      expect(files[0].type, 'video/mp4');
    },
    timeout: t(6),
  );
}
