// CHARTER — this file alone proves the PluginAssetPicker's mapping
// contract between the image_picker / file_picker plugins and the
// Outcome<PickedAsset> surface:
//   - option passthrough: maxWidth/maxHeight/imageQuality/limit/maxDuration and
//     the ImageSource arrive at the platform fake exactly as sent (recorded and
//     asserted), and each call routes to the RIGHT platform method;
//   - XFile → lazy PickedAsset: readBytes returns the picked file's declared
//     bytes, mimeType is inferred from fileName when the XFile has none and
//     passed through when it does;
//   - null / empty-selection → Cancelled (never an empty Success);
//   - captureImage/captureVideo are camera-gated on defaultTargetPlatform: iOS
//     proceeds (source == camera), macOS returns Unsupported WITHOUT
//     touching the fake;
//   - the four image_picker permission codes → PermissionDenied
//     (carrying the original exception + a stack trace); an unknown code → a
//     plain Failed that is NOT PermissionDenied; an Error (not
//     Exception) is RETHROWN, never swallowed;
//   - file picks route through file_picker's method channel with the extension
//     filter mapped to FileType.custom + allowedExtensions, null → Cancelled,
//     a path-less platform file → Failed, and a real path → a lazy
//     asset whose readBytes reads the file's declared bytes.
// Diet: patternedBytes/isPatterned from harness/bytes; fakes + TempWorkspace
// from harness; inline literals declared in this file.
//
// No io-exempt marker: this file does no file I/O. Temp files are created by
// TempWorkspace (test/harness, io-exempt) and file_picker maps are built here
// from the paths it returns.

import 'dart:typed_data';

import 'package:device_io/src/picker/image_options.dart';
import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/picker/plugin_asset_picker.dart';
import 'package:device_io/src/types/outcome.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
// device_io's ImageOptions is the public one here; hide the plugin's
// same-named type (this test fakes the image_picker platform interface).
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart'
    hide ImageOptions;

import '../harness/bytes.dart';
import '../harness/fake_file_picker.dart';
import '../harness/fake_image_picker_platform.dart';
import '../harness/timeouts.dart';

void main() {
  // Channel mocking (file_picker) needs the test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeImagePickerPlatform fakeIp;
  late FakeFilePicker fakeFp;
  late TempWorkspace tw;
  late PluginAssetPicker adapter;

  setUp(() {
    fakeIp = FakeImagePickerPlatform();
    ImagePickerPlatform.instance = fakeIp;
    fakeFp = FakeFilePicker()..install();
    tw = TempWorkspace();
    adapter = PluginAssetPicker();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    fakeFp.uninstall();
    tw.dispose();
  });

  // Unwrap a Success<T> or fail loudly with the actual variant.
  T supported<T>(Outcome<T> r) {
    expect(r, isA<Success<T>>(), reason: 'expected Success, got $r');
    return (r as Success<T>).value;
  }

  Future<void> expectBytes(PickedAsset asset, Uint8List declared) async {
    final read = await asset.readBytes();
    expect(read.length, declared.length);
    expect(isPatterned(read), isTrue, reason: 'asset bytes are not the pick');
  }

  // ── pickImage: passthrough, XFile mapping, mime inference, null ──

  test('pickImage passes options to getImageFromSource(gallery) and maps the '
      'XFile to a lazy asset with fileName-inferred mime', () async {
    final bytes = patternedBytes(37);
    fakeIp.single = tw.xFile('photo.png', bytes); // no mimeType on the XFile

    final r = await adapter.pickImage(
      options: const ImageOptions(maxWidth: 100, maxHeight: 200, quality: 80),
    );

    // request recorded exactly as sent
    expect(fakeIp.route, PickerRoute.getImageFromSource);
    expect(fakeIp.source, ImageSource.gallery);
    expect(fakeIp.maxWidth, 100.0);
    expect(fakeIp.maxHeight, 200.0);
    expect(fakeIp.imageQuality, 80);

    // mapped result
    final asset = supported(r);
    expect(asset.fileName, 'photo.png');
    expect(asset.mimeType, 'image/png'); // inferred from fileName
    await expectBytes(asset, bytes);
  }, timeout: t(5));

  test('pickImage passes through the XFile mimeType when present', () async {
    fakeIp.single = tw.xFile(
      'blob',
      patternedBytes(4),
      mimeType: 'image/x-odd',
    );
    final asset = supported(await adapter.pickImage());
    expect(asset.mimeType, 'image/x-odd');
  }, timeout: t(3));

  test('pickImage maps a null pick to Cancelled', () async {
    fakeIp.single = null;
    expect(await adapter.pickImage(), isA<Cancelled<PickedAsset>>());
  }, timeout: t(3));

  // ── pickImages: limit passthrough, order, empty → Cancelled ──

  test('pickImages passes limit to getMultiImageWithOptions and preserves '
      'order across N assets', () async {
    final a = patternedBytes(11);
    final b = patternedBytes(22);
    final c = patternedBytes(33);
    fakeIp.multi = [
      tw.xFile('a.png', a),
      tw.xFile('b.jpg', b),
      tw.xFile('c.webp', c),
    ];

    final r = await adapter.pickImages(
      limit: 3,
      options: const ImageOptions(maxWidth: 50),
    );

    expect(fakeIp.route, PickerRoute.getMultiImageWithOptions);
    expect(fakeIp.limit, 3);
    expect(fakeIp.maxWidth, 50.0);

    final assets = supported(r);
    expect(assets.map((x) => x.fileName), ['a.png', 'b.jpg', 'c.webp']);
    await expectBytes(assets[0], a);
    await expectBytes(assets[1], b);
    await expectBytes(assets[2], c);
  }, timeout: t(5));

  test(
    'pickImages maps an empty selection to Cancelled, never empty Success',
    () async {
      fakeIp.multi = const [];
      final r = await adapter.pickImages();
      expect(r, isA<Cancelled<List<PickedAsset>>>());
    },
    timeout: t(3),
  );

  // ── captureImage: camera source + camera gate ──

  test('captureImage on iOS routes to the camera source', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    fakeIp.single = tw.xFile('shot.jpg', patternedBytes(9));

    final r = await adapter.captureImage();

    expect(fakeIp.called, isTrue);
    expect(fakeIp.route, PickerRoute.getImageFromSource);
    expect(fakeIp.source, ImageSource.camera);
    expect(r, isA<Success<PickedAsset>>());
  }, timeout: t(3));

  test(
    'captureImage on macOS returns Unsupported without touching the plugin',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final r = await adapter.captureImage();
      expect(r, isA<Unsupported<PickedAsset>>());
      expect(fakeIp.called, isFalse);
    },
    timeout: t(3),
  );

  // ── pickVideo / captureVideo: maxDuration passthrough + gate ──

  test(
    'pickVideo passes maxDuration to getVideo(gallery) and maps the asset',
    () async {
      final bytes = patternedBytes(64);
      fakeIp.single = tw.xFile('clip.mp4', bytes);

      final r = await adapter.pickVideo(
        maxDuration: const Duration(seconds: 30),
      );

      expect(fakeIp.route, PickerRoute.getVideo);
      expect(fakeIp.source, ImageSource.gallery);
      expect(fakeIp.maxDuration, const Duration(seconds: 30));

      final asset = supported(r);
      expect(asset.mimeType, 'video/mp4');
      await expectBytes(asset, bytes);
    },
    timeout: t(5),
  );

  test('pickVideo maps a null pick to Cancelled', () async {
    fakeIp.single = null;
    expect(await adapter.pickVideo(), isA<Cancelled<PickedAsset>>());
  }, timeout: t(3));

  test(
    'captureVideo on iOS routes to the camera source with maxDuration',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      fakeIp.single = tw.xFile('rec.mp4', patternedBytes(8));

      final r = await adapter.captureVideo(
        maxDuration: const Duration(minutes: 1),
      );

      expect(fakeIp.called, isTrue);
      expect(fakeIp.route, PickerRoute.getVideo);
      expect(fakeIp.source, ImageSource.camera);
      expect(fakeIp.maxDuration, const Duration(minutes: 1));
      expect(r, isA<Success<PickedAsset>>());
    },
    timeout: t(3),
  );

  test(
    'captureVideo on macOS returns Unsupported without touching the plugin',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final r = await adapter.captureVideo();
      expect(r, isA<Unsupported<PickedAsset>>());
      expect(fakeIp.called, isFalse);
    },
    timeout: t(3),
  );

  // ── pickMedia / pickMultipleMedia: getMedia routing ──

  test('pickMedia routes to getMedia(allowMultiple:false), passes options, '
      'and returns the single asset', () async {
    final bytes = patternedBytes(15);
    fakeIp.multi = [tw.xFile('m.png', bytes)];

    final r = await adapter.pickMedia(
      options: const ImageOptions(maxWidth: 10, quality: 40),
    );

    expect(fakeIp.route, PickerRoute.getMedia);
    expect(fakeIp.allowMultiple, isFalse);
    expect(fakeIp.maxWidth, 10.0);
    expect(fakeIp.imageQuality, 40);

    final asset = supported(r);
    await expectBytes(asset, bytes);
  }, timeout: t(5));

  test('pickMedia maps an empty result to Cancelled', () async {
    fakeIp.multi = const [];
    expect(await adapter.pickMedia(), isA<Cancelled<PickedAsset>>());
  }, timeout: t(3));

  test('pickMultipleMedia routes to getMedia(allowMultiple:true), passes '
      'limit, and preserves order', () async {
    final a = patternedBytes(5);
    final b = patternedBytes(6);
    fakeIp.multi = [tw.xFile('a.mp4', a), tw.xFile('b.png', b)];

    final r = await adapter.pickMultipleMedia(limit: 4);

    expect(fakeIp.route, PickerRoute.getMedia);
    expect(fakeIp.allowMultiple, isTrue);
    expect(fakeIp.limit, 4);

    final assets = supported(r);
    expect(assets.map((x) => x.fileName), ['a.mp4', 'b.png']);
    await expectBytes(assets[0], a);
    await expectBytes(assets[1], b);
  }, timeout: t(5));

  test('pickMultipleMedia maps an empty selection to Cancelled', () async {
    fakeIp.multi = const [];
    final r = await adapter.pickMultipleMedia();
    expect(r, isA<Cancelled<List<PickedAsset>>>());
  }, timeout: t(3));

  // ── permission code mapping (table-driven) ──

  const permissionCodes = [
    'camera_access_denied',
    'camera_access_restricted',
    'photo_access_denied',
    'photo_access_restricted',
  ];

  for (final code in permissionCodes) {
    test('permission code "$code" maps to PermissionDenied carrying the '
        'exception + stack trace', () async {
      final ex = PlatformException(code: code, message: 'blocked: $code');
      fakeIp.error = ex;

      final r = await adapter.pickImage();

      expect(r, isA<PermissionDenied<PickedAsset>>());
      final failed = r as PermissionDenied<PickedAsset>;
      expect(failed.message, 'blocked: $code');
      expect(failed.error, same(ex));
      expect(failed.stackTrace, isNotNull);
    }, timeout: t(3));
  }

  test(
    'an unknown PlatformException code maps to a plain Failed that '
    'is NOT PermissionDenied, carrying the exception + stack trace',
    () async {
      final ex = PlatformException(code: 'weird_error', message: 'huh');
      fakeIp.error = ex;

      final r = await adapter.pickImage();

      expect(r, isA<Failed<PickedAsset>>());
      expect(r, isNot(isA<PermissionDenied<PickedAsset>>()));
      final failed = r as Failed<PickedAsset>;
      expect(failed.error, same(ex));
      expect(failed.stackTrace, isNotNull);
    },
    timeout: t(3),
  );

  // ── error physics: Errors rethrow, never convert ──

  test('an Error (not an Exception) thrown by the plugin is rethrown, never '
      'converted to Failed', () async {
    fakeIp.error = ArgumentError('programmer bug');
    await expectLater(adapter.pickImage(), throwsA(isA<ArgumentError>()));
  }, timeout: t(3));

  // ── file picks via the file_picker method channel ──

  test('pickFiles with an extension filter maps to FileType.custom + '
      'allowedExtensions, allowMultiple, native withData:false, and yields '
      'lazy assets over the returned paths', () async {
    final bytes = patternedBytes(48);
    final path = tw.writeFile('song.mp3', bytes);
    fakeFp.returnFiles([
      {'name': 'song.mp3', 'path': path, 'size': bytes.length},
    ]);

    final r = await adapter.pickFiles(allowedExtensions: ['mp3', 'wav']);

    // request recorded at the channel
    expect(fakeFp.called, isTrue);
    expect(fakeFp.method, 'custom');
    expect(fakeFp.allowedExtensions, ['mp3', 'wav']);
    expect(fakeFp.allowMultipleSelection, isTrue);
    expect(fakeFp.withData, isFalse); // native picks stay lazy

    final assets = supported(r);
    expect(assets, hasLength(1));
    expect(assets.first.fileName, 'song.mp3');
    expect(assets.first.mimeType, 'audio/mpeg');
    await expectBytes(assets.first, bytes);
  }, timeout: t(5));

  test('pickFile with no filter maps to FileType.any (no extensions, single '
      'selection) and returns one asset', () async {
    final bytes = patternedBytes(70);
    final path = tw.writeFile('doc.pdf', bytes);
    fakeFp.returnFiles([
      {'name': 'doc.pdf', 'path': path, 'size': bytes.length},
    ]);

    final r = await adapter.pickFile();

    expect(fakeFp.method, 'any');
    expect(fakeFp.allowedExtensions, isNull);
    expect(fakeFp.allowMultipleSelection, isFalse);

    final asset = supported(r);
    expect(asset.mimeType, 'application/pdf');
    await expectBytes(asset, bytes);
  }, timeout: t(5));

  test('pickFiles maps a null channel result to Cancelled', () async {
    fakeFp.returnCancelled();
    final r = await adapter.pickFiles();
    expect(r, isA<Cancelled<List<PickedAsset>>>());
  }, timeout: t(3));

  test('a returned platform file with no path fails the whole pick', () async {
    fakeFp.returnFiles([
      {'name': 'ghost.bin', 'path': null, 'size': 3},
    ]);
    final r = await adapter.pickFiles();
    expect(r, isA<Failed<List<PickedAsset>>>());
    expect(r, isNot(isA<Success<List<PickedAsset>>>()));
  }, timeout: t(3));
}
