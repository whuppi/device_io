import 'package:device_io/src/picker/plugin_asset_picker_adapter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isCameraSupported', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('true on phones/tablets', () {
      final adapter = PluginAssetPickerAdapter();
      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(adapter.isCameraSupported, isTrue, reason: '$platform');
      }
    });

    test('false on desktop (no camera delegate wired)', () {
      final adapter = PluginAssetPickerAdapter();
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(adapter.isCameraSupported, isFalse, reason: '$platform');
      }
    });

    test(
      'captureImage on desktop is a typed Unsupported, not a crash',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final result = await PluginAssetPickerAdapter().captureImage();
        expect(result.isUnsupported, isTrue);
      },
    );
  });
}
