// CHARTER — this file alone proves PluginAssetPicker.pickDirectory over
// file_picker's `dir` method channel: a scripted path → Success(path); a
// null channel reply → Cancelled (file_picker swallows PlatformException to
// null internally, so a permission error and a cancel both arrive as null —
// a documented plugin collapse); a non-PlatformException the plugin does NOT
// swallow (MissingPluginException, when no platform impl is present) → Failed.
// The web branch (kIsWeb → Unsupported) can't run on the VM and is proven in
// test/platform/web (world-quarantined). Diet: FakeFilePicker records the
// invoked method + returns a scripted path; no filesystem — a directory path
// is a string, nothing is read.
//
// io-exempt: none needed — this suite touches no dart:io.

import 'package:device_io/src/picker/plugin_asset_picker.dart';
import 'package:device_io/src/types/outcome.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness/fake_file_picker.dart';
import '../harness/timeouts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFilePicker fakeFp;
  late PluginAssetPicker adapter;

  setUp(() {
    fakeFp = FakeFilePicker()..install();
    adapter = PluginAssetPicker();
  });

  tearDown(() => fakeFp.uninstall());

  test('a chosen directory → Success(path)', () async {
    fakeFp.returnDirectory('/Users/x/Exports');
    final r = await adapter.pickDirectory();
    expect(r, isA<Success<String>>());
    expect((r as Success<String>).value, '/Users/x/Exports');
    expect(fakeFp.method, 'dir');
  }, timeout: t(3));

  test('a cancelled dialog (null reply) → Cancelled', () async {
    fakeFp.returnDirectory(null);
    expect(await adapter.pickDirectory(), isA<Cancelled<String>>());
  }, timeout: t(3));

  test('an unswallowed channel error (no platform impl) → Failed', () async {
    // file_picker eats PlatformException to null; a MissingPluginException is
    // not a PlatformException, so it propagates to the adapter. Reproduce it
    // by removing the mock so the `dir` call finds no handler.
    fakeFp.uninstall();
    final r = await adapter.pickDirectory();
    expect(r, isA<Failed<String>>());
  }, timeout: t(3));
}
