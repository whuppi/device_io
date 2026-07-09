// CHARTER — this file alone proves, in a REAL browser, the WebFileOpener's
// behavior against an instrumented window.open + URL.createObjectURL: openBytes
// calls window.open with a `blob:` URL and the '_blank' target and, when the
// returned window is non-null, maps to Success(null); when window.open returns
// null (popup blocked), it revokes the URL and returns the documented
// Failed; openPath is always Unsupported on web (no override needed).
// Diet: declared byte fixtures from ../harness/bytes.dart; inline literals here.
@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:device_io/src/opener/web/file_opener.dart';
import 'package:device_io/src/types/outcome.dart';
import 'package:test/test.dart';

import '../../harness/bytes.dart';
import '../../harness/timeouts.dart';
import 'js_overrides.dart';

void main() {
  final adapter = WebFileOpener();
  final overrides = <PropOverride>[];

  String? openedUrl;
  String? openedTarget;

  /// Installs URL.createObjectURL (records the blob, returns a `blob:` URL)
  /// and window.open (records url+target, returns [win] — null = popup block).
  void install({required JSObject? win}) {
    openedUrl = null;
    openedTarget = null;
    overrides.add(
      PropOverride.install(
        urlCtor,
        'createObjectURL',
        ((JSObject blob) => 'blob:opener-fake'.toJS).toJS,
      ),
    );
    overrides.add(
      PropOverride.install(
        windowObj,
        'open',
        ((JSString url, JSString target) {
          openedUrl = url.toDart;
          openedTarget = target.toDart;
          return win;
        }).toJS,
      ),
    );
  }

  tearDown(() {
    restoreAll(overrides);
    overrides.clear();
  });

  test('openBytes opens a blob: URL in _blank and returns Success', () async {
    install(win: JSObject()); // non-null fake window
    final result = await adapter.openBytes(
      bytes: utf8SampleBytes,
      fileName: 'doc.pdf',
    );

    expect(result, isA<Success<void>>());
    expect(openedUrl, 'blob:opener-fake');
    expect(openedTarget, '_blank');
  }, timeout: t(4));

  test(
    'openBytes with window.open returning null → Failed (popup blocked)',
    () async {
      install(win: null); // popup blocked
      final result = await adapter.openBytes(
        bytes: utf8SampleBytes,
        fileName: 'doc.pdf',
      );

      expect(result, isA<Failed<void>>());
      expect((result as Failed<void>).message, contains('popup'));
      expect(openedTarget, '_blank'); // it did attempt the open
    },
    timeout: t(4),
  );

  test('openPath is always Unsupported on web', () async {
    final result = await adapter.openPath(filePath: '/tmp/whatever.pdf');
    expect(result, isA<Unsupported<void>>());
  }, timeout: t(3));
}
