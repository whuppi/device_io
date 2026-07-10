// CHARTER — this file alone proves NativeFileSaver.saveInto's on-disk
// behavior against a REAL temp directory: bytes land in the chosen directory
// under the sanitized fileName with the EXACT declared bytes; a second save
// of the same name gets no-clobber numbering (a `(1)` sibling), never an
// overwrite; a name with traversal/separators is sanitized before it touches
// the path. The web side (→ Unsupported) is proven in test/platform/web.
// Diet: patternedBytes from harness/bytes; a systemTemp workspace.
//
// io-exempt: the SUBJECT writes real files by design; this asserts the real
// on-disk effect.

import 'dart:io';

import 'package:device_io/src/saver/native/file_saver.dart';
import 'package:device_io/src/saver/save_location.dart';
import 'package:device_io/src/types/outcome.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../harness/bytes.dart';
import '../../harness/timeouts.dart';

void main() {
  late Directory target;
  final saver = NativeFileSaver();

  setUp(() {
    target = Directory.systemTemp.createTempSync('device_io_saveinto_');
  });
  tearDown(() {
    if (target.existsSync()) target.deleteSync(recursive: true);
  });

  test('writes the exact bytes into the chosen directory', () async {
    final bytes = patternedBytes(4096);
    final r = await saver.saveInto(
      directory: target.path,
      bytes: bytes,
      fileName: 'report.bin',
    );
    expect(r, isA<Success<SaveLocation>>());
    final path = ((r as Success<SaveLocation>).value as SavedAtPath).path;
    expect(File(path).parent.path, target.path);
    expect(File(path).readAsBytesSync(), bytes);
    expect(path.endsWith('report.bin'), isTrue);
  }, timeout: t(5));

  test('a second same-named save is numbered, never clobbers', () async {
    final a = patternedBytes(512);
    final b = patternedBytes(1024);
    final r1 = await saver.saveInto(
      directory: target.path,
      bytes: a,
      fileName: 'dup.bin',
    );
    final r2 = await saver.saveInto(
      directory: target.path,
      bytes: b,
      fileName: 'dup.bin',
    );
    final p1 = ((r1 as Success<SaveLocation>).value as SavedAtPath).path;
    final p2 = ((r2 as Success<SaveLocation>).value as SavedAtPath).path;
    expect(p1, isNot(p2));
    expect(p2, contains('(1)'));
    expect(File(p1).readAsBytesSync(), a);
    expect(File(p2).readAsBytesSync(), b);
  }, timeout: t(5));

  test(
    'a traversal-laden name is sanitized before touching the path',
    () async {
      final r = await saver.saveInto(
        directory: target.path,
        bytes: patternedBytes(64),
        fileName: '../../etc/passwd',
      );
      final path = ((r as Success<SaveLocation>).value as SavedAtPath).path;
      // The real safety property: the write stays inside the chosen directory.
      // Separators in the name are replaced, so it can never climb out — the
      // file's parent is exactly the target, never an ancestor.
      expect(File(path).parent.path, target.path);
      final name = path.substring(target.path.length + 1);
      expect(name.contains(Platform.pathSeparator), isFalse);
    },
    timeout: t(5),
  );
}
