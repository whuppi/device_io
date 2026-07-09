// CHARTER — this file alone proves the NativeFileOpener's MOBILE
// protocol against the open_filex method channel (the pinned-protocol
// watchlist row in docs/UPDATING.md):
//   - openPath on Android/iOS sends method 'open_file' with the EXACT map
//     {file_path, type, uti} — path passed through, type = provided mimeType
//     or null, uti always null;
//   - the plugin's JSON reply maps, table-driven, to typed results:
//       type 0  -> Success(null)
//       type -1 -> Failed('No app available to open this file type')
//       type -2 -> Failed('File not found: <path>')
//       type -3 -> PlatformPermissionDenied(message carried)
//       type -4 -> Failed(message carried)
//       unknown -> Failed(message carried)
//       null    -> Failed('File opener returned no response'), never a crash
//   - openBytes on mobile stages a REAL file (declared bytes, sanitized name)
//     and opens the captured file_path through the same channel.
//
// EXCLUDED, honestly: the DESKTOP branch (macOS `open`, Linux `xdg-open`,
// Windows `start`) launches real OS viewers via Process.run — invoking it in
// a unit test would spawn a real application. It is exercised by the example
// app, not here. No debugDefaultTargetPlatformOverride trick forces that path.
//
// Behavioral, not liveness: every claim reads the real recorded channel
// arguments and the real staged bytes off disk, comparing to bytes.dart
// declared truth and to result strings DECLARED in the switch under test.
//
// open_filex protocol (mirrored in the adapter's own source comment):
// channel `open_file`, method `open_file`, args
// {file_path, type, uti}, JSON `{type, message}`, codes 0/-1/-2/-3/-4.
//
// Diet: dart:io is legitimate — the SUBJECT wraps dart:io and this suite lives
// under test/opener/ (not a dart:io-guarded directory). No plugin barrels:
// open_filex is reached through its raw method channel, path_provider through
// the platform-interface fake.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:device_io/src/opener/native/file_opener.dart';
import 'package:device_io/src/types/platform_result.dart';

import '../../harness/bytes.dart';
import '../../harness/fake_path_provider.dart';
import '../../harness/timeouts.dart';

const _openFileChannel = MethodChannel('open_file');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory temp;
  MethodCall? lastCall;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dio_open_');
    temp = Directory('${root.path}/temp')..createSync();
    PathProviderPlatform.instance = FakePathProvider(temporaryPath: temp.path);
    lastCall = null;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    _binding.setMockMethodCallHandler(_openFileChannel, null);
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  final adapter = NativeFileOpener();

  // Scripts the channel to reply with the given open_filex code + message,
  // recording the outgoing MethodCall.
  void reply({required int type, String? message}) {
    _binding.setMockMethodCallHandler(_openFileChannel, (call) async {
      lastCall = call;
      return jsonEncode({'type': type, 'message': message});
    });
  }

  File existingFile(String name) {
    final f = File('${root.path}/$name')..writeAsBytesSync(utf8SampleBytes);
    return f;
  }

  group('openPath outgoing channel arguments', () {
    test('sends open_file with {file_path, type=mimeType, uti:null}', () async {
      final f = existingFile('doc.pdf');
      reply(type: 0);

      await adapter.openPath(filePath: f.path, mimeType: 'application/pdf');

      expect(lastCall, isNotNull);
      expect(lastCall!.method, 'open_file');
      final args = lastCall!.arguments as Map;
      expect(args, {
        'file_path': f.path,
        'type': 'application/pdf',
        'uti': null,
      });
    }, timeout: t(3));

    test('type is null when no mimeType is supplied', () async {
      final f = existingFile('doc.bin');
      reply(type: 0);

      await adapter.openPath(filePath: f.path);

      final args = lastCall!.arguments as Map;
      expect(args['type'], isNull);
      expect(args['uti'], isNull);
    }, timeout: t(3));
  });

  group('openPath result mapping (table-driven)', () {
    test('type 0 -> Success(null)', () async {
      final f = existingFile('a.pdf');
      reply(type: 0);
      final r = await adapter.openPath(filePath: f.path);
      expect(r, isA<PlatformSuccess<void>>());
    }, timeout: t(3));

    test('type -1 -> Failed(no app)', () async {
      final f = existingFile('a.pdf');
      reply(type: -1);
      final r = await adapter.openPath(filePath: f.path);
      expect(r, isA<PlatformFailed<void>>());
      expect(
        (r as PlatformFailed<void>).message,
        'No app available to open this file type',
      );
    }, timeout: t(3));

    test('type -2 -> Failed(not found, path echoed)', () async {
      final f = existingFile('a.pdf');
      reply(type: -2);
      final r = await adapter.openPath(filePath: f.path);
      expect(r, isA<PlatformFailed<void>>());
      expect((r as PlatformFailed<void>).message, 'File not found: ${f.path}');
    }, timeout: t(3));

    test('type -3 -> PermissionDenied(message carried)', () async {
      final f = existingFile('a.pdf');
      reply(type: -3, message: 'permission was refused');
      final r = await adapter.openPath(filePath: f.path);
      expect(r, isA<PlatformPermissionDenied<void>>());
      expect(
        (r as PlatformPermissionDenied<void>).message,
        'permission was refused',
      );
    }, timeout: t(3));

    test('type -4 -> Failed(message carried)', () async {
      final f = existingFile('a.pdf');
      reply(type: -4, message: 'boom');
      final r = await adapter.openPath(filePath: f.path);
      expect(r, isA<PlatformFailed<void>>());
      expect((r as PlatformFailed<void>).message, 'boom');
    }, timeout: t(3));

    test('unknown code -> Failed(message carried)', () async {
      final f = existingFile('a.pdf');
      reply(type: 99, message: 'weird outcome');
      final r = await adapter.openPath(filePath: f.path);
      expect(r, isA<PlatformFailed<void>>());
      expect((r as PlatformFailed<void>).message, 'weird outcome');
    }, timeout: t(3));

    test('null channel response -> Failed, never crashes', () async {
      final f = existingFile('a.pdf');
      // invokeMethod<String> can resolve to null (old plugin, odd native
      // state). It must surface as PlatformFailed, not a rethrown TypeError.
      _binding.setMockMethodCallHandler(_openFileChannel, (call) async => null);
      final r = await adapter.openPath(filePath: f.path);
      expect(r, isA<PlatformFailed<void>>());
      expect(
        (r as PlatformFailed<void>).message,
        'File opener returned no response',
      );
    }, timeout: t(3));

    test('iOS routes to the same mobile channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final f = existingFile('a.pdf');
      reply(type: 0);
      final r = await adapter.openPath(filePath: f.path);
      expect(r, isA<PlatformSuccess<void>>());
      expect(lastCall!.method, 'open_file');
    }, timeout: t(3));
  });

  test('openBytes stages a real sanitized file and opens its path', () async {
    reply(type: 0);

    final r = await adapter.openBytes(
      bytes: utf8SampleBytes,
      fileName: 'my:doc.pdf', // ':' -> '_' on sanitize
    );

    expect(r, isA<PlatformSuccess<void>>());
    expect(lastCall, isNotNull);
    final stagedPath = (lastCall!.arguments as Map)['file_path'] as String;

    // The path handed to the channel is the file we staged: sanitized name,
    // declared bytes, physically present.
    expect(stagedPath.split('/').last, 'my_doc.pdf');
    final staged = File(stagedPath);
    expect(staged.existsSync(), isTrue);
    expect(Uint8List.fromList(staged.readAsBytesSync()), utf8SampleBytes);
  }, timeout: t(3));
}

TestDefaultBinaryMessenger get _binding =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
