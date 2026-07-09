// CHARTER — this file alone proves the native filesystem safety battery:
// sanitizeFileName neutralizes traversal, forbidden chars, control chars,
// trailing dots/whitespace, empty/dot-only names, Windows reserved device
// names (base-before-first-dot only, case-insensitive), and over-long names
// (extension-preserving truncation with the >15-char fake-extension rule),
// while preserving unicode; reserveFreshFile creates a zero-byte file, numbers
// collisions ((1)(2)(3)), splits on the LAST dot, treats a leading dot as
// stem, and never hands two concurrent callers the same path; stageFile writes
// the sanitized name into a fresh per-call directory with the exact bytes the
// write callback produced; stageFiles preserves order, dedupes same-name
// entries with numbered variants, and lands them all in ONE directory.
// Diet: inline table literals + patternedBytes/isPatterned from harness/bytes.

// io-exempt: the SUBJECT is the native world's dart:io wrapper — this
// suite exercises it against a real temp directory by design.
import 'dart:io';

import 'package:device_io/src/runtime/native/fs.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';

import '../../harness/bytes.dart';
import '../../harness/timeouts.dart';

// path_provider's getTemporaryDirectory() goes through this channel on the
// test VM (MethodChannelPathProvider). stageFile/stageFiles call into it, so
// the staging group points it at a real systemTemp dir it controls.
const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── sanitizeFileName: table-driven ──

  // (input, expected) declared truths.
  const cases = <(String, String)>[
    // Path traversal — separators become '_'; dots are NOT unsafe chars.
    (r'../../evil', '.._.._evil'),
    (r'a/b\c', 'a_b_c'),
    // Each forbidden char → '_'.
    ('a<b>c:d"e|f?g*h', 'a_b_c_d_e_f_g_h'),
    // Trailing dots + whitespace trimmed.
    ('report...', 'report'),
    ('  spaced  ', 'spaced'),
    // Empty / dot-only → 'file'.
    ('', 'file'),
    ('.', 'file'),
    ('..', 'file'),
    // Windows reserved (base before first dot), case-insensitive.
    ('CON', '_CON'),
    ('con.txt', '_con.txt'),
    ('COM1.log', '_COM1.log'),
    // NOT reserved — 'console' != 'con'.
    ('CONSOLE.txt', 'CONSOLE.txt'),
    // Unicode preserved.
    ('café–ünïcode.png', 'café–ünïcode.png'),
  ];

  for (final (input, expected) in cases) {
    test('sanitizeFileName(${_show(input)}) == ${_show(expected)}', () {
      expect(sanitizeFileName(input), expected);
    }, timeout: t(2));
  }

  test('sanitizeFileName strips control characters', () {
    // NUL, SOH, DEL embedded between letters — all stripped.
    expect(sanitizeFileName('a\u0000b\u0001c\u007f'), 'abc');
  }, timeout: t(2));

  test(
    'sanitizeFileName truncates long names, keeping a real extension',
    () {
      final name = '${'a' * 300}.txt';
      final out = sanitizeFileName(name);
      expect(out.length, 200);
      expect(out.endsWith('.txt'), isTrue);
      // Stem was truncated to make room for the 4-char extension.
      expect(out.substring(0, out.length - 4), 'a' * 196);
    },
    timeout: t(2),
  );

  test(
    'sanitizeFileName truncates a >15-char fake extension with the stem',
    () {
      // 300 'a', then a 19-char "extension" — not a real extension (>15 after
      // the dot), so the whole thing is cut to 200 with no extension carve-out.
      final name = '${'a' * 300}.${'b' * 19}';
      final out = sanitizeFileName(name);
      expect(out.length, 200);
      expect(out, 'a' * 200);
      expect(out.contains('.'), isFalse);
    },
    timeout: t(2),
  );

  // ── reserveFreshFile ──

  group('reserveFreshFile', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('device_io_fs_reserve_');
    });
    tearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    test('creates a fresh zero-byte file', () async {
      final file = await reserveFreshFile(tmp, 'report.pdf');
      expect(file.existsSync(), isTrue);
      expect(await file.length(), 0);
      expect(file.path, '${tmp.path}/report.pdf');
    }, timeout: t(3));

    test('numbers a taken name (1)(2)(3)', () async {
      final a = await reserveFreshFile(tmp, 'report.pdf');
      final b = await reserveFreshFile(tmp, 'report.pdf');
      final c = await reserveFreshFile(tmp, 'report.pdf');
      final d = await reserveFreshFile(tmp, 'report.pdf');
      expect(a.path, '${tmp.path}/report.pdf');
      expect(b.path, '${tmp.path}/report (1).pdf');
      expect(c.path, '${tmp.path}/report (2).pdf');
      expect(d.path, '${tmp.path}/report (3).pdf');
    }, timeout: t(3));

    test('splits on the LAST dot for multi-dot names', () async {
      await reserveFreshFile(tmp, 'a.b.c.txt');
      final second = await reserveFreshFile(tmp, 'a.b.c.txt');
      expect(second.path, '${tmp.path}/a.b.c (1).txt');
    }, timeout: t(3));

    test('treats a leading dot as stem (no extension)', () async {
      await reserveFreshFile(tmp, '.hidden');
      final second = await reserveFreshFile(tmp, '.hidden');
      expect(second.path, '${tmp.path}/.hidden (1)');
    }, timeout: t(3));

    test('is collision-free under concurrency', () async {
      final results = await Future.wait([
        for (var i = 0; i < 8; i++) reserveFreshFile(tmp, 'race.dat'),
      ]);
      final paths = results.map((f) => f.path).toSet();
      // All distinct.
      expect(paths.length, 8);
      // All exist on disk.
      for (final f in results) {
        expect(f.existsSync(), isTrue);
      }
    }, timeout: t(5));
  });

  // ── stageFile / stageFiles ──
  //
  // These call getTemporaryDirectory() internally; the group points the
  // path_provider channel at a real systemTemp dir it owns and cleans up.

  group('staging', () {
    late Directory stageRoot;

    setUp(() async {
      stageRoot = await Directory.systemTemp.createTemp('device_io_fs_stage_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, (call) async {
            if (call.method == 'getTemporaryDirectory') return stageRoot.path;
            return null;
          });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProviderChannel, null);
      if (stageRoot.existsSync()) await stageRoot.delete(recursive: true);
    });

    test(
      'stageFile writes the sanitized name into a fresh directory',
      () async {
        final file = await stageFile(
          purpose: 'test',
          fileName: '../evil name.bin',
          write: (f) async => f.writeAsBytes(patternedBytes(64)),
        );
        // Name sanitized: separators → '_' (dots untouched).
        expect(file.uri.pathSegments.last, '.._evil name.bin');
        expect(file.existsSync(), isTrue);
      },
      timeout: t(3),
    );

    test('stageFile puts two same-name stagings in DIFFERENT dirs', () async {
      final a = await stageFile(
        purpose: 'test',
        fileName: 'same.bin',
        write: (f) async => f.writeAsBytes(patternedBytes(16)),
      );
      final b = await stageFile(
        purpose: 'test',
        fileName: 'same.bin',
        write: (f) async => f.writeAsBytes(patternedBytes(16)),
      );
      expect(a.parent.path, isNot(b.parent.path));
      expect(a.uri.pathSegments.last, b.uri.pathSegments.last);
    }, timeout: t(3));

    test('stageFile writes exactly the callback bytes to disk', () async {
      final file = await stageFile(
        purpose: 'test',
        fileName: 'payload.bin',
        write: (f) async => f.writeAsBytes(patternedBytes(1024)),
      );
      final onDisk = await file.readAsBytes();
      expect(onDisk.length, 1024);
      expect(isPatterned(onDisk), isTrue);
    }, timeout: t(3));

    test('stageFiles preserves order and dedupes same-name entries', () async {
      final files = await stageFiles(
        purpose: 'test',
        entries: [
          (
            fileName: 'a.txt',
            write: (f) async => f.writeAsBytes(patternedBytes(10)),
          ),
          (
            fileName: 'dup.txt',
            write: (f) async => f.writeAsBytes(patternedBytes(20)),
          ),
          (
            fileName: 'dup.txt',
            write: (f) async => f.writeAsBytes(patternedBytes(30)),
          ),
          (
            fileName: 'dup.txt',
            write: (f) async => f.writeAsBytes(patternedBytes(40)),
          ),
        ],
      );
      final names = files.map((f) => f.uri.pathSegments.last).toList();
      expect(names, ['a.txt', 'dup.txt', 'dup (1).txt', 'dup (2).txt']);
    }, timeout: t(3));

    test('stageFiles lands every entry in ONE directory', () async {
      final files = await stageFiles(
        purpose: 'test',
        entries: [
          (
            fileName: 'x.bin',
            write: (f) async => f.writeAsBytes(patternedBytes(8)),
          ),
          (
            fileName: 'y.bin',
            write: (f) async => f.writeAsBytes(patternedBytes(8)),
          ),
        ],
      );
      final dirs = files.map((f) => f.parent.path).toSet();
      expect(dirs.length, 1);
    }, timeout: t(3));

    test('stageFiles writes correct contents per entry', () async {
      final files = await stageFiles(
        purpose: 'test',
        entries: [
          (
            fileName: 'small.bin',
            write: (f) async => f.writeAsBytes(patternedBytes(11)),
          ),
          (
            fileName: 'big.bin',
            write: (f) async => f.writeAsBytes(patternedBytes(333)),
          ),
        ],
      );
      final first = await files[0].readAsBytes();
      final second = await files[1].readAsBytes();
      expect(first.length, 11);
      expect(isPatterned(first), isTrue);
      expect(second.length, 333);
      expect(isPatterned(second), isTrue);
    }, timeout: t(3));
  });
}

// Renders inputs readably in test descriptions.
String _show(String s) => "'$s'";
