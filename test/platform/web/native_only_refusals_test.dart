// CHARTER — this file alone proves, in a REAL browser, that the web
// implementations refuse the native-only capabilities honestly rather than
// pretending: WebFileSaver.saveInto → Unsupported (no directory paths in the
// browser), and WebFileOpener.open(SaveLocation) → Unsupported for both a
// SavedAtPath (unconstructible on web anyway) and a SavedByBrowser download
// (the browser owns that file, no handle to reopen). The native halves live
// in test/saver/native and test/opener/native. Diet: type asserts on the
// verdicts; no JS surface is touched.

@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:device_io/src/opener/web/file_opener.dart';
import 'package:device_io/src/saver/save_location.dart';
import 'package:device_io/src/saver/web/file_saver.dart';
import 'package:device_io/src/types/outcome.dart';
import 'package:test/test.dart';

import '../../harness/timeouts.dart';

void main() {
  test('saveInto is Unsupported on web', () async {
    final r = await WebFileSaver().saveInto(
      directory: '/anything',
      bytes: Uint8List.fromList(const [1, 2, 3]),
      fileName: 'x.bin',
    );
    expect(r, isA<Unsupported<SaveLocation>>());
    expect((r as Unsupported<SaveLocation>).reason, isNotEmpty);
  }, timeout: t(3));

  test('open(SavedAtPath) is Unsupported on web', () async {
    final r = await WebFileOpener().open(const SavedAtPath('/x/y.pdf'));
    expect(r, isA<Unsupported<void>>());
  }, timeout: t(3));

  test('open(SavedByBrowser) is Unsupported on web', () async {
    final r = await WebFileOpener().open(
      const SavedByBrowser(fileName: 'y.pdf'),
    );
    expect(r, isA<Unsupported<void>>());
  }, timeout: t(3));
}
