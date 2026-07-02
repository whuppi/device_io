// Integration smoke — the programmatic surfaces against REAL plugins on a
// real target (macOS/iOS/Android/Windows/Linux devices, or Chrome via
// flutter drive). What it proves: initDeviceIO resolves the right adapter
// set; silent saves write real bytes to the real filesystem with the
// no-clobber contract (native), or trigger the download path (web);
// streamed saves arrive complete; PickedAsset round-trips.
//
// Honestly excluded: pickers, share sheets, saveAs, and openers — every
// one summons a real dialog, sheet, or viewer that no headless run can
// drive. Those surfaces are covered by the package suites (fakes +
// instrumented Chrome) and by the journey tests through the example UI.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show File; // Guarded by kIsWeb at every use.

import 'package:device_io/device_io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DeviceIO deviceIO;

  setUpAll(() async {
    deviceIO = await initDeviceIO(
      config: const DeviceIOConfig(downloadSubfolder: 'DeviceIOSmoke'),
    );
  });

  test(
    'saveToDevice writes real bytes; second save numbers the name',
    () async {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final name = 'smoke_$stamp.txt';
      const body = 'device_io smoke — real save';

      final first = await deviceIO.download.saveToDevice(
        bytes: Uint8List.fromList(utf8.encode(body)),
        fileName: name,
      );
      expect(first, isA<PlatformSupported<String?>>());
      final firstPath = (first as PlatformSupported<String?>).value;

      if (kIsWeb) {
        // A browser download has no observable path.
        expect(firstPath, isNull);
        return;
      }

      expect(firstPath, isNotNull);
      expect(File(firstPath!).readAsStringSync(), body);

      final second = await deviceIO.download.saveToDevice(
        bytes: Uint8List.fromList(utf8.encode(body)),
        fileName: name,
      );
      final secondPath = (second as PlatformSupported<String?>).value!;
      expect(secondPath, isNot(firstPath));
      expect(secondPath, contains('(1)'));
      expect(File(secondPath).readAsStringSync(), body);
    },
  );

  test('saveStreamToDevice lands the complete patterned stream', () async {
    const total = 300 * 1024;
    Stream<List<int>> chunks() async* {
      var offset = 0;
      // Uneven, prime-misaligned chunk sizes — a dropped or reordered
      // chunk cannot produce the full pattern.
      for (final size in const [70003, 130001, 99996, total - 300000]) {
        yield [for (var i = 0; i < size; i++) (offset + i) % 251];
        offset += size;
      }
    }

    final result = await deviceIO.download.saveStreamToDevice(
      byteStream: chunks(),
      fileName: 'smoke_stream_${DateTime.now().microsecondsSinceEpoch}.bin',
    );
    expect(result, isA<PlatformSupported<String?>>());

    if (kIsWeb) return; // Buffered download; no path to read back.

    final path = (result as PlatformSupported<String?>).value!;
    final bytes = File(path).readAsBytesSync();
    expect(bytes.length, total);
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] != i % 251) {
        fail('pattern broken at byte $i');
      }
    }
  });

  test('PickedAsset.fromBytes round-trips through both read modes', () async {
    final source = Uint8List.fromList(List.generate(2048, (i) => i % 251));
    final asset = PickedAsset.fromBytes(
      bytes: source,
      mimeType: 'application/octet-stream',
      fileName: 'roundtrip.bin',
    );

    expect(await asset.readBytes(), source);
    final streamed = <int>[
      for (final chunk in await asset.readStream().toList()) ...chunk,
    ];
    expect(streamed, source);
  });
}
