// CHARTER — this file alone proves the NativeSharer's request
// contract, by inspecting the ShareParams it hands the platform AND the real
// files it staged on disk:
//   - shareText records exact text / subject / sharePositionOrigin and, on a
//     success ShareResult, returns Success;
//   - shareFile stages a REAL file whose bytes equal the declared payload,
//     under the sanitized fileName; an explicit mimeType passes through, a
//     null one is inferred from the name to the exact declared value;
//   - a dismissed ShareResult -> Cancelled; an unavailable one -> Success
//     (the sheet was shown, the outcome is just unknowable);
//   - shareFileStream stages a byte-for-byte patterned multi-chunk stream;
//   - shareFiles stages N files into ONE directory, preserves order,
//     dedupes duplicate names on disk AND in the params, infers per-file
//     mimeType, and passes sharePositionOrigin through;
//   - an empty file list throws ArgumentError BEFORE the platform is touched;
//   - a caught Exception -> Failed with a stackTrace; a caught Error is
//     rethrown.
//
// Behavioral, not liveness: every claim reads the staged bytes back off disk
// and the recorded ShareParams object graph, comparing to bytes.dart declared
// truth and to mimeType values DECLARED here (image/png, text/csv, ...).
//
// ShareResult / ShareResultStatus / ShareParams / SharePlatform.instance
// mechanism is documented in test/harness/fake_share_platform.dart.
//
// Diet: dart:io is legitimate — the SUBJECT stages via dart:io and this suite
// lives under test/sharing/ (not a dart:io-guarded directory). No plugin
// barrels: SharePlatform via the interface fake, path_provider via the
// interface fake.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'package:device_io/src/sharer/native/native_sharer.dart';
import 'package:device_io/src/sharer/share_file.dart';
import 'package:device_io/src/sharer/share_origin.dart';
import 'package:device_io/src/types/platform_result.dart';

import '../harness/bytes.dart';
import '../harness/fake_path_provider.dart';
import '../harness/fake_share_platform.dart';
import '../harness/timeouts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory temp;
  late FakeSharePlatform share;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dio_share_');
    temp = Directory('${root.path}/temp')..createSync();
    PathProviderPlatform.instance = FakePathProvider(temporaryPath: temp.path);
    share = FakeSharePlatform();
    SharePlatform.instance = share;
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  final adapter = NativeSharer();

  test(
    'shareText records exact text/subject/origin and returns Success',
    () async {
      const origin = ShareOrigin.fromLTWH(1, 2, 3, 4);

      final result = await adapter.shareText(
        text: 'hello world',
        subject: 'greeting',
        sharePositionOrigin: origin,
      );

      expect(result, isA<PlatformSuccess<void>>());
      expect(share.callCount, 1);
      final params = share.lastParams!;
      expect(params.text, 'hello world');
      expect(params.subject, 'greeting');
      // The adapter maps ShareOrigin → share_plus's dart:ui Rect at the seam.
      expect(params.sharePositionOrigin, const Rect.fromLTWH(1, 2, 3, 4));
      expect(params.files, anyOf(isNull, isEmpty));
    },
    timeout: t(3),
  );

  group('shareFile', () {
    test(
      'stages a real file with declared bytes and explicit mimeType',
      () async {
        final result = await adapter.shareFile(
          bytes: utf8SampleBytes,
          fileName: 'note.txt',
          mimeType: 'text/plain',
        );

        expect(result, isA<PlatformSuccess<void>>());
        final xfile = share.lastParams!.files!.single;
        expect(_basename(xfile.path), 'note.txt');
        expect(File(xfile.path).existsSync(), isTrue);
        expect(
          Uint8List.fromList(File(xfile.path).readAsBytesSync()),
          utf8SampleBytes,
        );
        expect(xfile.mimeType, 'text/plain');
      },
      timeout: t(3),
    );

    test(
      'null mimeType is inferred from the name (chart.png -> image/png)',
      () async {
        await adapter.shareFile(bytes: utf8SampleBytes, fileName: 'chart.png');

        final xfile = share.lastParams!.files!.single;
        expect(_basename(xfile.path), 'chart.png');
        expect(xfile.mimeType, 'image/png');
      },
      timeout: t(3),
    );

    test('dismissed ShareResult -> Cancelled', () async {
      share.result = const ShareResult('', ShareResultStatus.dismissed);

      final result = await adapter.shareFile(
        bytes: utf8SampleBytes,
        fileName: 'a.txt',
      );

      expect(result, isA<PlatformCancelled<void>>());
    }, timeout: t(3));

    test('unavailable ShareResult -> Success(null)', () async {
      share.result = ShareResult.unavailable;

      final result = await adapter.shareFile(
        bytes: utf8SampleBytes,
        fileName: 'a.txt',
      );

      expect(result, isA<PlatformSuccess<void>>());
    }, timeout: t(3));
  });

  test(
    'shareFileStream stages a patterned multi-chunk stream intact',
    () async {
      final full = patternedBytes(200 * 1024);

      final result = await adapter.shareFileStream(
        byteStream: _unevenChunks(full),
        fileName: 'stream.bin',
      );

      expect(result, isA<PlatformSuccess<void>>());
      final xfile = share.lastParams!.files!.single;
      final onDisk = Uint8List.fromList(File(xfile.path).readAsBytesSync());
      expect(onDisk.length, full.length);
      expect(isPatterned(onDisk), isTrue);
    },
    timeout: t(5),
  );

  group('shareFiles', () {
    test('stages N files in ONE dir, order + dedupe + per-file mime', () async {
      final a = patternedBytes(64);
      final b = utf8SampleBytes;
      final c = patternedBytes(128);
      const origin = ShareOrigin.fromLTWH(5, 6, 7, 8);

      final result = await adapter.shareFiles(
        files: [
          ShareFile(bytes: a, fileName: 'a.png'),
          ShareFile(bytes: b, fileName: 'b.csv'),
          ShareFile(bytes: c, fileName: 'a.png'), // duplicate name
        ],
        sharePositionOrigin: origin,
      );

      expect(result, isA<PlatformSuccess<void>>());
      final files = share.lastParams!.files!;
      expect(files.length, 3);

      // Order preserved; duplicate deduped on disk to "a (1).png".
      expect(_basename(files[0].path), 'a.png');
      expect(_basename(files[1].path), 'b.csv');
      expect(_basename(files[2].path), 'a (1).png');

      // All three staged into the same directory.
      expect(File(files[0].path).parent.path, File(files[1].path).parent.path);
      expect(File(files[1].path).parent.path, File(files[2].path).parent.path);

      // Contents intact per file.
      expect(Uint8List.fromList(File(files[0].path).readAsBytesSync()), a);
      expect(Uint8List.fromList(File(files[1].path).readAsBytesSync()), b);
      expect(Uint8List.fromList(File(files[2].path).readAsBytesSync()), c);

      // mimeType inferred from each original name.
      expect(files[0].mimeType, 'image/png');
      expect(files[1].mimeType, 'text/csv');
      expect(files[2].mimeType, 'image/png');

      expect(
        share.lastParams!.sharePositionOrigin,
        const Rect.fromLTWH(5, 6, 7, 8),
      );
    }, timeout: t(3));

    test(
      'empty list throws ArgumentError before the platform is touched',
      () async {
        expect(
          () => adapter.shareFiles(files: const []),
          throwsA(isA<ArgumentError>()),
        );
        expect(share.callCount, 0);
      },
      timeout: t(3),
    );
  });

  group('error physics', () {
    test('caught Exception -> Failed with a stackTrace', () async {
      share.throwError = Exception('sheet crashed');

      final result = await adapter.shareText(text: 'hi');

      expect(result, isA<PlatformFailed<void>>());
      expect((result as PlatformFailed<void>).stackTrace, isNotNull);
    }, timeout: t(3));

    test('caught Error is rethrown', () async {
      share.throwError = StateError('bug');

      await expectLater(
        adapter.shareText(text: 'hi'),
        throwsA(isA<StateError>()),
      );
    }, timeout: t(3));
  });
}

// The subject joins staged paths with '/' (see _shared/native_fs.dart), so
// the basename is the last '/'-delimited segment regardless of host OS.
String _basename(String path) => path.split('/').last;

Stream<List<int>> _unevenChunks(Uint8List bytes) async* {
  const sizes = [5000, 7, 65536, 1, 30000, 99];
  var offset = 0;
  var i = 0;
  while (offset < bytes.length) {
    final end = (offset + sizes[i % sizes.length]).clamp(0, bytes.length);
    yield bytes.sublist(offset, end);
    offset = end;
    i++;
  }
}
