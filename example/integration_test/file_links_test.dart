// Integration proof for the links door against the REAL native halves —
// the bookmark mint and resolve on Apple platforms (inside the sandbox,
// with the bookmarks entitlement), the path world on desktop, the app's
// own files on Android. What it proves: a file the app can name becomes a
// durable candidate, links, reopens through a handle that reads the same
// bytes, is readable on the copy path, and answers `LinkTargetMissing`
// once the file is gone.
//
// Honestly excluded: the pickers. A pick is a system dialog no headless
// run can drive; the candidate it produces is the same shape this test
// gets from `candidateForPath`, and the code after the pick is shared.

import 'dart:io' show Directory, File; // Guarded by kIsWeb at every use.

import 'package:device_io/device_io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FileLinks links;
  late Directory dir;
  final bytes = List<int>.generate(70000, (i) => (i * 31) & 0xFF);

  setUpAll(() async {
    links = DeviceIO().links;
    if (!kIsWeb) dir = await Directory.systemTemp.createTemp('links_proof');
  });

  tearDownAll(() async {
    if (!kIsWeb && dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('a file the app can name links in place and reopens', () async {
    if (kIsWeb) {
      expect(await links.candidateForPath('/x'), isA<Unsupported<Object?>>());
      return;
    }
    final file = File('${dir.path}/own.gguf')..writeAsBytesSync(bytes);

    final described = await links.candidateForPath(file.path);
    expect(described, isA<Success<LinkCandidate>>(), reason: '$described');
    final candidate = (described as Success<LinkCandidate>).value;
    expect(candidate.displayName, 'own.gguf');
    expect(candidate.sizeBytes, bytes.length);
    expect(
      candidate.strength,
      LinkStrength.durable,
      reason: candidate.reason ?? 'no reason given',
    );

    // The copy path reads the same bytes the platform described.
    expect(await candidate.readBytes(), bytes);

    final linked = await links.link(candidate);
    expect(linked, isA<Success<FileRef>>(), reason: '$linked');
    final ref = (linked as Success<FileRef>).value;
    expect(ref.token, isNotEmpty);

    // A token restored from storage — not the object link() handed back —
    // is what every later launch opens.
    final restored = FileRef.restore(
      token: ref.token,
      displayName: ref.displayName,
      sizeBytes: ref.sizeBytes,
    );
    final opened = await links.open(restored);
    expect(opened, isA<Success<FileHandle>>(), reason: '$opened');
    final handle = (opened as Success<FileHandle>).value;
    expect(handle.sizeBytes, bytes.length);
    final read = <int>[];
    await for (final chunk in handle.readStream()) {
      read.addAll(chunk);
    }
    expect(read, bytes);
    await handle.close();

    // Gone from disk: the open answers the typed refusal, and unlinking
    // what is already gone is still a success.
    file.deleteSync();
    expect(await links.open(restored), isA<LinkTargetMissing<FileHandle>>());
    expect(await links.unlink(restored), isA<Success<void>>());
  });

  test('nothing at the path is a missing target', () async {
    if (kIsWeb) return;
    expect(
      await links.candidateForPath('${dir.path}/never.gguf'),
      isA<LinkTargetMissing<LinkCandidate>>(),
    );
  });

  test('the budget is a typed ledger everywhere', () async {
    final budget = await links.budget();
    expect(budget.used, greaterThanOrEqualTo(0));
  });
}
