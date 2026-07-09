// CHARTER — this file alone proves NativeFileOpener.open(SaveLocation): a
// SavedAtPath routes to openPath and reaches open_filex's channel with that
// exact path (the save→open loop closed with no caller branching); a
// SavedByBrowser — which a native saver never emits but the sealed type spans
// both worlds — returns Unsupported rather than inventing a path. The web
// side (every location → Unsupported) is proven in test/platform/web. Diet:
// the open_filex channel is mocked to a success reply and its recorded path
// asserted; no real viewer.
//
// io-exempt: open() → openPath stages a real file (open_filex needs a path);
// the subject is the native opener.

import 'dart:convert' show jsonEncode;
import 'dart:io';

import 'package:device_io/src/opener/native/file_opener.dart';
import 'package:device_io/src/saver/save_location.dart';
import 'package:device_io/src/types/outcome.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_test/flutter_test.dart';

import '../../harness/timeouts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('open_file');
  final binding =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final opener = NativeFileOpener();
  MethodCall? lastCall;
  late Directory tmp;
  late File real;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('device_io_open_');
    real = File('${tmp.path}/report.pdf')..writeAsBytesSync(const [1, 2, 3]);
    lastCall = null;
    binding.setMockMethodCallHandler(channel, (call) async {
      lastCall = call;
      return jsonEncode({'type': 0, 'message': 'done'});
    });
  });
  tearDown(() {
    binding.setMockMethodCallHandler(channel, null);
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('SavedAtPath opens at its path (loop closed)', () async {
    final r = await opener.open(
      SavedAtPath(real.path),
      mimeType: 'application/pdf',
    );
    expect(r, isA<Success<void>>());
    expect((lastCall!.arguments as Map)['file_path'], real.path);
    expect((lastCall!.arguments as Map)['type'], 'application/pdf');
  }, timeout: t(3));

  test('SavedByBrowser has no path → Unsupported (no channel call)', () async {
    final r = await opener.open(const SavedByBrowser(fileName: 'x.pdf'));
    expect(r, isA<Unsupported<void>>());
    expect(lastCall, isNull);
  }, timeout: t(3));
}
