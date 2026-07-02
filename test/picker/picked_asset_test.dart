// CHARTER — this file alone proves PickedAsset's laziness contract:
// PickedAsset.lazy runs NEITHER closure at construction; readBytes invokes
// only the bytes closure and a fresh invocation per call; readStream returns a
// FRESH stream each call (consumable more than once, identical content);
// mimeType and fileName are carried; and PickedAsset.fromBytes exposes the
// exact bytes through both readBytes and readStream.
// Diet: inline literals + patternedBytes/isPatterned from harness/bytes.

import 'dart:typed_data';

import 'package:device_io/src/picker/picked_asset.dart';
import 'package:test/test.dart';

import '../harness/bytes.dart';
import '../harness/timeouts.dart';

void main() {
  const kMime = 'image/png';
  const kName = 'avatar.png';

  // ── laziness ──

  test('lazy runs neither closure at construction', () {
    var bytesCalled = false;
    var streamCalled = false;
    PickedAsset.lazy(
      mimeType: kMime,
      readBytes: () async {
        bytesCalled = true;
        return Uint8List(0);
      },
      readStream: () {
        streamCalled = true;
        return const Stream.empty();
      },
    );
    // Neither flag flips until a read method is actually called.
    expect(bytesCalled, isFalse);
    expect(streamCalled, isFalse);
  }, timeout: t(2));

  test('readBytes invokes only the bytes closure, fresh each call', () async {
    var bytesCalls = 0;
    var streamCalls = 0;
    final asset = PickedAsset.lazy(
      mimeType: kMime,
      readBytes: () async {
        bytesCalls++;
        return patternedBytes(32);
      },
      readStream: () {
        streamCalls++;
        return Stream.value(patternedBytes(32));
      },
    );

    await asset.readBytes();
    await asset.readBytes();
    expect(bytesCalls, 2);
    expect(streamCalls, 0);
  }, timeout: t(2));

  // ── fresh stream per call ──

  test('readStream returns a fresh, re-consumable stream each call', () async {
    final asset = PickedAsset.lazy(
      mimeType: kMime,
      readBytes: () async => patternedBytes(256),
      // A fresh single-value stream per call — reusing one broadcast/single
      // stream instance would throw on the second consumption.
      readStream: () => Stream.value(patternedBytes(256)),
    );

    final first = await _drain(asset.readStream());
    final second = await _drain(asset.readStream());

    expect(first.length, 256);
    expect(second.length, 256);
    expect(isPatterned(first), isTrue);
    expect(isPatterned(second), isTrue);
  }, timeout: t(3));

  // ── carried metadata ──

  test('lazy carries mimeType and fileName', () {
    final asset = PickedAsset.lazy(
      mimeType: kMime,
      fileName: kName,
      readBytes: () async => Uint8List(0),
      readStream: () => const Stream.empty(),
    );
    expect(asset.mimeType, kMime);
    expect(asset.fileName, kName);
  }, timeout: t(2));

  // ── fromBytes ──

  test('fromBytes exposes exact bytes via readBytes and readStream', () async {
    final source = patternedBytes(100);
    final asset = PickedAsset.fromBytes(
      bytes: source,
      mimeType: kMime,
      fileName: kName,
    );

    final viaBytes = await asset.readBytes();
    expect(viaBytes.length, 100);
    expect(isPatterned(viaBytes), isTrue);

    final viaStream = await _drain(asset.readStream());
    expect(viaStream.length, 100);
    expect(isPatterned(viaStream), isTrue);

    expect(asset.mimeType, kMime);
    expect(asset.fileName, kName);
  }, timeout: t(3));
}

/// Fully consumes [stream] into a single Uint8List.
Future<Uint8List> _drain(Stream<List<int>> stream) async {
  final out = <int>[];
  await for (final chunk in stream) {
    out.addAll(chunk);
  }
  return Uint8List.fromList(out);
}
