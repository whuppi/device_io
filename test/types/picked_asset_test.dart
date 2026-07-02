import 'dart:async';
import 'dart:typed_data';

import 'package:device_io/device_io.dart';
import 'package:test/test.dart';

void main() {
  group('PickedAsset', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

    group('fromBytes', () {
      test('stores mimeType and fileName', () {
        final asset = PickedAsset.fromBytes(
          bytes: bytes,
          mimeType: 'image/png',
          fileName: 'photo.png',
        );
        expect(asset.mimeType, 'image/png');
        expect(asset.fileName, 'photo.png');
      });

      test('fileName is optional', () {
        final asset = PickedAsset.fromBytes(
          bytes: bytes,
          mimeType: 'image/png',
        );
        expect(asset.fileName, isNull);
      });

      test('readBytes returns the bytes', () async {
        final asset = PickedAsset.fromBytes(
          bytes: bytes,
          mimeType: 'image/png',
        );
        expect(await asset.readBytes(), bytes);
      });

      test('readStream yields the bytes', () async {
        final asset = PickedAsset.fromBytes(
          bytes: bytes,
          mimeType: 'image/png',
        );
        final collected = await asset.readStream().expand((c) => c).toList();
        expect(collected, bytes);
      });

      test('readBytes can be called multiple times', () async {
        final asset = PickedAsset.fromBytes(
          bytes: bytes,
          mimeType: 'image/png',
        );
        expect(await asset.readBytes(), bytes);
        expect(await asset.readBytes(), bytes);
      });
    });

    group('fromFile', () {
      test('is lazy — closures not invoked until read', () async {
        var bytesReads = 0;
        var streamReads = 0;
        final asset = PickedAsset.fromFile(
          mimeType: 'video/mp4',
          fileName: 'clip.mp4',
          readBytesFromFile: () async {
            bytesReads++;
            return bytes;
          },
          streamFromFile: () {
            streamReads++;
            return Stream.value(bytes);
          },
        );

        // Construction alone must not touch the file.
        expect(bytesReads, 0);
        expect(streamReads, 0);

        await asset.readBytes();
        expect(bytesReads, 1);
        expect(streamReads, 0);

        await asset.readStream().drain<void>();
        expect(streamReads, 1);
      });

      test('readBytes delegates to the file closure', () async {
        final asset = PickedAsset.fromFile(
          mimeType: 'application/pdf',
          readBytesFromFile: () async => bytes,
          streamFromFile: () => Stream.value(bytes),
        );
        expect(await asset.readBytes(), bytes);
      });

      test('readStream delegates to the file closure', () async {
        final chunks = [
          [1, 2],
          [3, 4],
          [5],
        ];
        final asset = PickedAsset.fromFile(
          mimeType: 'application/pdf',
          readBytesFromFile: () async => bytes,
          streamFromFile: () => Stream.fromIterable(chunks),
        );
        final collected = await asset.readStream().toList();
        expect(collected, chunks);
      });

      test('read errors propagate to the caller', () {
        final asset = PickedAsset.fromFile(
          mimeType: 'application/pdf',
          readBytesFromFile: () async => throw StateError('gone'),
          streamFromFile: () => Stream.error(StateError('gone')),
        );
        expect(asset.readBytes(), throwsStateError);
        expect(asset.readStream().drain<void>(), throwsStateError);
      });
    });
  });
}
