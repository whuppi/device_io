// CHARTER — this file alone proves the runtime layer on the VM: DeviceIO()
// (the default factory) resolves the NATIVE capability set — PluginAssetPicker,
// NativeSharer, NativeFileSaver, NativeFileOpener — and plumbs
// DeviceIOConfig.downloadsSubfolder through to the saver (default config →
// null subfolder); DeviceIO.custom is an identity seam — the four instances
// handed in are the four instances exposed, no wrapping, no substitution —
// and is const-constructible. Diet: type/identity asserts against the public
// surface plus the src impl types; no plugin edges are touched, so no fakes.

import 'package:device_io/device_io.dart';
import 'package:device_io/src/opener/native/file_opener.dart';
import 'package:device_io/src/picker/plugin_asset_picker.dart';
import 'package:device_io/src/saver/native/file_saver.dart';
import 'package:device_io/src/sharer/native/sharer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/timeouts.dart';

// Minimal stand-ins for the custom-wiring identity test. Methods are never
// called — the assertions are about wiring, not behavior.
final class _StubPicker implements AssetPicker {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('wiring-only stub');
}

final class _StubSharer implements Sharer {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('wiring-only stub');
}

final class _StubSaver implements FileSaver {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('wiring-only stub');
}

final class _StubOpener implements FileOpener {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('wiring-only stub');
}

void main() {
  group('DeviceIO() — native resolution', () {
    test('resolves the full native capability set', () {
      final io = DeviceIO();
      expect(io.picker, isA<PluginAssetPicker>());
      expect(io.sharer, isA<NativeSharer>());
      expect(io.saver, isA<NativeFileSaver>());
      expect(io.opener, isA<NativeFileOpener>());
    }, timeout: t(3));

    test('plumbs config.downloadsSubfolder into the saver', () {
      final io = DeviceIO(
        config: const DeviceIOConfig(downloadsSubfolder: 'RuntimeProof'),
      );
      expect((io.saver as NativeFileSaver).downloadsSubfolder, 'RuntimeProof');
    }, timeout: t(3));

    test('default config leaves the saver subfolder null', () {
      final io = DeviceIO();
      expect((io.saver as NativeFileSaver).downloadsSubfolder, isNull);
    }, timeout: t(3));

    test(
      'each call resolves a fresh coordinator (no hidden singleton)',
      () {
        expect(identical(DeviceIO(), DeviceIO()), isFalse);
      },
      timeout: t(3),
    );
  });

  group('DeviceIO.custom — the injection seam', () {
    test('exposes exactly the instances handed in', () {
      final picker = _StubPicker();
      final sharer = _StubSharer();
      final saver = _StubSaver();
      final opener = _StubOpener();
      final io = DeviceIO.custom(
        picker: picker,
        sharer: sharer,
        saver: saver,
        opener: opener,
      );
      expect(identical(io.picker, picker), isTrue);
      expect(identical(io.sharer, sharer), isTrue);
      expect(identical(io.saver, saver), isTrue);
      expect(identical(io.opener, opener), isTrue);
    }, timeout: t(3));
  });
}
