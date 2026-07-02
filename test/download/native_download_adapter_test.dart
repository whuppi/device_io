import 'dart:io';
import 'dart:typed_data';

import 'package:device_io/device_io.dart';
import 'package:device_io/src/download/native/native_download_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Redirects path_provider lookups to a test-owned temp directory —
/// no platform channels involved.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider({this.downloadsPath, required this.documentsPath});

  final String? downloadsPath;
  final String documentsPath;

  @override
  Future<String?> getDownloadsPath() async => downloadsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('device_io_test_');
    PathProviderPlatform.instance = _FakePathProvider(
      downloadsPath: tempDir.path,
      documentsPath: tempDir.path,
    );
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  final bytes = Uint8List.fromList([10, 20, 30]);

  group('saveToDevice', () {
    test('writes bytes and returns the path', () async {
      final adapter = NativeDownloadAdapter();
      final result = await adapter.saveToDevice(
        bytes: bytes,
        fileName: 'report.pdf',
      );

      final path = (result as PlatformSupported<String?>).value!;
      expect(path, '${tempDir.path}/report.pdf');
      expect(await File(path).readAsBytes(), bytes);
    });

    test('never overwrites — numbered variants like a browser', () async {
      final adapter = NativeDownloadAdapter();
      final first = await adapter.saveToDevice(
        bytes: bytes,
        fileName: 'report.pdf',
      );
      final second = await adapter.saveToDevice(
        bytes: Uint8List.fromList([9, 9, 9]),
        fileName: 'report.pdf',
      );
      final third = await adapter.saveToDevice(
        bytes: Uint8List.fromList([7]),
        fileName: 'report.pdf',
      );

      expect(
        (first as PlatformSupported<String?>).value,
        '${tempDir.path}/report.pdf',
      );
      expect(
        (second as PlatformSupported<String?>).value,
        '${tempDir.path}/report (1).pdf',
      );
      expect(
        (third as PlatformSupported<String?>).value,
        '${tempDir.path}/report (2).pdf',
      );

      // The original is untouched.
      expect(await File('${tempDir.path}/report.pdf').readAsBytes(), bytes);
    });

    test('numbered variants for extension-less names', () async {
      final adapter = NativeDownloadAdapter();
      await adapter.saveToDevice(bytes: bytes, fileName: 'LICENSE');
      final second = await adapter.saveToDevice(
        bytes: bytes,
        fileName: 'LICENSE',
      );

      expect(
        (second as PlatformSupported<String?>).value,
        '${tempDir.path}/LICENSE (1)',
      );
    });

    test('dot-files keep the leading dot as part of the stem', () async {
      final adapter = NativeDownloadAdapter();
      await adapter.saveToDevice(bytes: bytes, fileName: '.env');
      final second = await adapter.saveToDevice(bytes: bytes, fileName: '.env');

      expect(
        (second as PlatformSupported<String?>).value,
        '${tempDir.path}/.env (1)',
      );
    });

    test('creates the app subfolder when configured', () async {
      final adapter = NativeDownloadAdapter(appSubfolder: 'MyApp');
      final result = await adapter.saveToDevice(
        bytes: bytes,
        fileName: 'export.csv',
      );

      final path = (result as PlatformSupported<String?>).value!;
      expect(path, '${tempDir.path}/MyApp/export.csv');
      expect(await File(path).exists(), isTrue);
    });

    test('falls back to documents when downloads dir is unavailable', () async {
      final docsDir = await Directory('${tempDir.path}/docs').create();
      PathProviderPlatform.instance = _FakePathProvider(
        downloadsPath: null, // mobile: no downloads directory
        documentsPath: docsDir.path,
      );

      final adapter = NativeDownloadAdapter();
      final result = await adapter.saveToDevice(
        bytes: bytes,
        fileName: 'export.csv',
      );

      expect(
        (result as PlatformSupported<String?>).value,
        '${docsDir.path}/export.csv',
      );
    });
  });

  group('saveStreamToDevice', () {
    test('writes streamed chunks in order', () async {
      final adapter = NativeDownloadAdapter();
      final result = await adapter.saveStreamToDevice(
        byteStream: Stream.fromIterable([
          [1, 2],
          [3, 4],
          [5],
        ]),
        fileName: 'big.bin',
      );

      final path = (result as PlatformSupported<String?>).value!;
      expect(await File(path).readAsBytes(), [1, 2, 3, 4, 5]);
    });

    test('a failing stream surfaces as PlatformFailed', () async {
      final adapter = NativeDownloadAdapter();
      final result = await adapter.saveStreamToDevice(
        byteStream: Stream.error(const FileSystemException('disk full')),
        fileName: 'big.bin',
      );

      expect(result, isA<PlatformFailed<String?>>());
    });

    test('stream saves also avoid clobbering', () async {
      final adapter = NativeDownloadAdapter();
      await adapter.saveToDevice(bytes: bytes, fileName: 'big.bin');
      final result = await adapter.saveStreamToDevice(
        byteStream: Stream.value([1]),
        fileName: 'big.bin',
      );

      expect(
        (result as PlatformSupported<String?>).value,
        '${tempDir.path}/big (1).bin',
      );
    });
  });
}
