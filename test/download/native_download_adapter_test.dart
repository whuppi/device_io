// CHARTER — this file alone proves the NativeDownloadAdapter's on-disk
// contract:
//   - saveToDevice writes the EXACT declared bytes to a file INSIDE the
//     downloads directory, under a sanitized name that cannot escape it;
//   - a second save of the same name never clobbers the first — both files
//     survive with intact contents, the second numbered "(1)";
//   - appSubfolder is created and used;
//   - a null downloads path falls back to the documents directory;
//   - saveStreamToDevice reassembles a multi-chunk patterned stream byte-for
//     -byte and leaves NO `.part` sibling behind (browser two-phase write);
//   - a FAILING stream leaves NEITHER a `.part` file NOR the reserved final
//     name with partial content — the placeholder is cleaned too;
//   - saveAs maps the file_picker `save` method-channel result: null ->
//     Cancelled, a path -> Supported(path), the outgoing fileName argument is
//     SANITIZED, a PlatformException -> Failed carrying it;
//   - an Error thrown from the path provider is RETHROWN, not wrapped.
//
// Behavioral, not liveness: every claim reads the real bytes back off disk (or
// the real recorded channel argument) and compares to test/harness/bytes.dart
// declared truth, never to values re-derived from the subject.
//
// file_picker save channel verified in file_picker-11.0.2:
//   lib/src/platform/file_picker_method_channel.dart:16 channel name
//   `miguelruivo.flutter.plugins.filepicker`; :161 method `save`; :162-166
//   args `{fileName, fileType, initialDirectory, allowedExtensions, bytes}`;
//   returns String? path (null == cancelled). Default instance is
//   MethodChannelFilePicker (file_picker_platform_interface.dart:21), so
//   mocking the channel intercepts FilePicker.saveFile without importing it.
//
// Diet: dart:io here is legitimate — the SUBJECT wraps dart:io, and this suite
// lives under test/download/ (not a dart:io-guarded directory). No plugin
// barrels: file_picker is reached through its method channel, path_provider
// through the platform-interface fake.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart'
    show MethodCall, MethodChannel, PlatformException, StandardMethodCodec;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:device_io/src/download/native/native_download_adapter.dart';
import 'package:device_io/src/types/platform_result.dart';

import '../harness/bytes.dart';
import '../harness/fake_path_provider.dart';
import '../harness/timeouts.dart';

// The file_picker method channel (name verified above). StandardMethodCodec
// matches the plugin's own channel construction.
const _filePickerChannel = MethodChannel(
  'miguelruivo.flutter.plugins.filepicker',
  StandardMethodCodec(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory downloads;
  late Directory documents;
  late Directory temp;
  late FakePathProvider provider;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dio_dl_');
    downloads = Directory('${root.path}/downloads')..createSync();
    documents = Directory('${root.path}/documents')..createSync();
    temp = Directory('${root.path}/temp')..createSync();
    provider = FakePathProvider(
      downloadsPath: downloads.path,
      documentsPath: documents.path,
      temporaryPath: temp.path,
    );
    PathProviderPlatform.instance = provider;
  });

  tearDown(() {
    _binding.setMockMethodCallHandler(_filePickerChannel, null);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  final adapter = NativeDownloadAdapter();

  group('saveToDevice', () {
    test(
      'writes exact declared bytes inside the downloads directory',
      () async {
        final result = await adapter.saveToDevice(
          bytes: utf8SampleBytes,
          fileName: 'export.txt',
        );

        expect(result, isA<PlatformSupported<String?>>());
        final path = (result as PlatformSupported<String?>).value!;
        expect(path, '${downloads.path}/export.txt');

        final onDisk = File(path);
        expect(onDisk.existsSync(), isTrue);
        expect(onDisk.parent.path, downloads.path);
        expect(Uint8List.fromList(onDisk.readAsBytesSync()), utf8SampleBytes);
      },
      timeout: t(3),
    );

    test('sanitizes a traversal name into the downloads dir', () async {
      // '../esc:ape.txt' -> '/' and ':' become '_' -> no separator remains,
      // so the file is a plain child of downloads, not an escape.
      final result = await adapter.saveToDevice(
        bytes: utf8SampleBytes,
        fileName: '../esc:ape.txt',
      );

      final path = (result as PlatformSupported<String?>).value!;
      expect(path, '${downloads.path}/.._esc_ape.txt');
      final onDisk = File(path);
      expect(onDisk.existsSync(), isTrue);
      expect(onDisk.parent.path, downloads.path);
    }, timeout: t(3));

    test('never clobbers: second same-name save numbers "(1)"', () async {
      final second = patternedBytes(100);

      final r1 = await adapter.saveToDevice(
        bytes: utf8SampleBytes,
        fileName: 'report.txt',
      );
      final r2 = await adapter.saveToDevice(
        bytes: second,
        fileName: 'report.txt',
      );

      final p1 = (r1 as PlatformSupported<String?>).value!;
      final p2 = (r2 as PlatformSupported<String?>).value!;
      expect(p1, '${downloads.path}/report.txt');
      expect(p2, '${downloads.path}/report (1).txt');

      expect(Uint8List.fromList(File(p1).readAsBytesSync()), utf8SampleBytes);
      expect(Uint8List.fromList(File(p2).readAsBytesSync()), second);
    }, timeout: t(3));

    test('appSubfolder is created and used', () async {
      final scoped = NativeDownloadAdapter(appSubfolder: 'MyApp');

      final result = await scoped.saveToDevice(
        bytes: utf8SampleBytes,
        fileName: 'note.txt',
      );

      final path = (result as PlatformSupported<String?>).value!;
      expect(path, '${downloads.path}/MyApp/note.txt');
      final onDisk = File(path);
      expect(onDisk.existsSync(), isTrue);
      expect(onDisk.parent.path, '${downloads.path}/MyApp');
      expect(Directory('${downloads.path}/MyApp').existsSync(), isTrue);
    }, timeout: t(3));

    test('null downloads path falls back to documents', () async {
      provider.downloadsPath = null;

      final result = await adapter.saveToDevice(
        bytes: utf8SampleBytes,
        fileName: 'fallback.txt',
      );

      final path = (result as PlatformSupported<String?>).value!;
      expect(path, '${documents.path}/fallback.txt');
      expect(File(path).parent.path, documents.path);
      expect(Uint8List.fromList(File(path).readAsBytesSync()), utf8SampleBytes);
    }, timeout: t(3));
  });

  group('saveStreamToDevice', () {
    test('reassembles a multi-chunk patterned stream, no .part left', () async {
      final full = patternedBytes(300 * 1024);

      final result = await adapter.saveStreamToDevice(
        byteStream: _unevenChunks(full),
        fileName: 'stream.bin',
      );

      final path = (result as PlatformSupported<String?>).value!;
      expect(path, '${downloads.path}/stream.bin');

      final onDisk = Uint8List.fromList(File(path).readAsBytesSync());
      expect(onDisk.length, full.length);
      expect(isPatterned(onDisk), isTrue);

      // No `.part` sibling survives the rename.
      final leftovers = downloads
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.part'))
          .toList();
      expect(leftovers, isEmpty);
    }, timeout: t(5));

    test(
      'failing stream leaves NEITHER a .part NOR the reserved name',
      () async {
        final result = await adapter.saveStreamToDevice(
          byteStream: _failingStream(),
          fileName: 'stream.bin',
        );

        expect(result, isA<PlatformFailed<String?>>());

        // The reserved placeholder was cleaned, and no `.part` remains — the
        // directory holds no trace of the aborted write.
        expect(File('${downloads.path}/stream.bin').existsSync(), isFalse);
        final anyLeft = downloads.listSync().whereType<File>().toList();
        expect(anyLeft, isEmpty);
      },
      timeout: t(3),
    );
  });

  group('saveAs (file_picker save channel)', () {
    test('null path -> Cancelled', () async {
      _mockSave((call) => null);

      final result = await adapter.saveAs(
        bytes: utf8SampleBytes,
        fileName: 'report.pdf',
      );

      expect(result, isA<PlatformCancelled<String?>>());
    }, timeout: t(3));

    test('a path -> Supported(path)', () async {
      _mockSave((call) => '/chosen/report.pdf');

      final result = await adapter.saveAs(
        bytes: utf8SampleBytes,
        fileName: 'report.pdf',
      );

      expect(result, isA<PlatformSupported<String?>>());
      expect(
        (result as PlatformSupported<String?>).value,
        '/chosen/report.pdf',
      );
    }, timeout: t(3));

    test('outgoing fileName argument is sanitized', () async {
      MethodCall? seen;
      _mockSave((call) {
        seen = call;
        return '/chosen/out.txt';
      });

      await adapter.saveAs(bytes: utf8SampleBytes, fileName: '../bad:name.txt');

      expect(seen, isNotNull);
      expect(seen!.method, 'save');
      final args = seen!.arguments as Map;
      expect(args['fileName'], '.._bad_name.txt');
      // The bytes we asked to write are the ones handed to the channel.
      expect(Uint8List.fromList(args['bytes'] as List<int>), utf8SampleBytes);
    }, timeout: t(3));

    test('PlatformException from the channel -> Failed carrying it', () async {
      _mockSave(
        (call) => throw PlatformException(code: 'io', message: 'disk full'),
      );

      final result = await adapter.saveAs(
        bytes: utf8SampleBytes,
        fileName: 'report.pdf',
      );

      expect(result, isA<PlatformFailed<String?>>());
      final failed = result as PlatformFailed<String?>;
      expect(failed.error, isA<PlatformException>());
      expect((failed.error! as PlatformException).code, 'io');
    }, timeout: t(3));
  });

  test('Error from the path provider is rethrown, not wrapped', () async {
    provider.downloadsError = StateError('provider exploded');

    await expectLater(
      adapter.saveToDevice(bytes: utf8SampleBytes, fileName: 'x.txt'),
      throwsA(isA<StateError>()),
    );
  }, timeout: t(3));
}

TestDefaultBinaryMessenger get _binding =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void _mockSave(Object? Function(MethodCall call) respond) {
  _binding.setMockMethodCallHandler(_filePickerChannel, (call) async {
    return respond(call);
  });
}

/// A patterned payload streamed in deliberately uneven chunks so any dropped,
/// duplicated, or reordered chunk breaks isPatterned.
Stream<List<int>> _unevenChunks(Uint8List bytes) async* {
  const sizes = [7000, 13, 65536, 1, 40000, 123, 100000];
  var offset = 0;
  var i = 0;
  while (offset < bytes.length) {
    final size = sizes[i % sizes.length];
    final end = (offset + size).clamp(0, bytes.length);
    yield bytes.sublist(offset, end);
    offset = end;
    i++;
  }
}

/// Yields a couple of chunks, then throws mid-stream.
Stream<List<int>> _failingStream() async* {
  yield patternedBytes(4096);
  yield patternedBytes(4096);
  throw const _StreamBroke();
}

final class _StreamBroke implements Exception {
  const _StreamBroke();
  @override
  String toString() => 'stream broke';
}
