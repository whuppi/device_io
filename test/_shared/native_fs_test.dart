import 'dart:io';

import 'package:device_io/src/_shared/native_fs.dart';
import 'package:test/test.dart';

void main() {
  group('sanitizeFileName', () {
    test('passes ordinary names through', () {
      expect(sanitizeFileName('report.pdf'), 'report.pdf');
      expect(sanitizeFileName('My Photo (1).jpg'), 'My Photo (1).jpg');
      expect(sanitizeFileName('.env'), '.env');
    });

    test('neutralizes path traversal', () {
      expect(sanitizeFileName('../../etc/passwd'), isNot(contains('/')));
      expect(sanitizeFileName(r'..\..\evil.exe'), isNot(contains(r'\')));
      expect(sanitizeFileName('..'), 'file');
      expect(sanitizeFileName('...'), 'file');
    });

    test('replaces separators and Windows-forbidden characters', () {
      expect(sanitizeFileName('a/b'), 'a_b');
      expect(sanitizeFileName(r'a\b'), 'a_b');
      expect(sanitizeFileName('a<b>c:d"e|f?g*h'), 'a_b_c_d_e_f_g_h');
    });

    test('strips control characters', () {
      expect(sanitizeFileName('a\x00b\nc.txt'), 'abc.txt');
    });

    test('trims whitespace and trailing dots', () {
      expect(sanitizeFileName('  report.pdf  '), 'report.pdf');
      expect(sanitizeFileName('report.pdf...'), 'report.pdf');
    });

    test('empty input becomes a usable name', () {
      expect(sanitizeFileName(''), 'file');
      expect(sanitizeFileName('   '), 'file');
      expect(sanitizeFileName('///'), '___');
    });

    test('prefixes Windows reserved device names', () {
      expect(sanitizeFileName('CON'), '_CON');
      expect(sanitizeFileName('con.txt'), '_con.txt');
      expect(sanitizeFileName('NUL.tar.gz'), '_NUL.tar.gz');
      expect(sanitizeFileName('lpt1.pdf'), '_lpt1.pdf');
      // Only the part before the FIRST dot counts.
      expect(sanitizeFileName('Console.txt'), 'Console.txt');
      expect(sanitizeFileName('xCON.txt'), 'xCON.txt');
    });

    test('truncates overlong names but keeps the extension', () {
      final long = '${'a' * 300}.pdf';
      final result = sanitizeFileName(long);
      expect(result.length, lessThanOrEqualTo(200));
      expect(result, endsWith('.pdf'));
    });
  });

  group('reserveFreshFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('native_fs_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('reserves the plain name when free', () async {
      final file = await reserveFreshFile(tempDir, 'a.txt');
      expect(file.path, '${tempDir.path}/a.txt');
      expect(await file.exists(), isTrue);
    });

    test('numbers taken names', () async {
      await reserveFreshFile(tempDir, 'a.txt');
      final second = await reserveFreshFile(tempDir, 'a.txt');
      final third = await reserveFreshFile(tempDir, 'a.txt');
      expect(second.path, '${tempDir.path}/a (1).txt');
      expect(third.path, '${tempDir.path}/a (2).txt');
    });

    test('concurrent reservations of the same name never collide', () async {
      final files = await Future.wait(
        List.generate(8, (_) => reserveFreshFile(tempDir, 'clash.bin')),
      );
      final paths = files.map((f) => f.path).toSet();
      expect(paths.length, 8, reason: 'every reservation got a unique path');
    });
  });
}
