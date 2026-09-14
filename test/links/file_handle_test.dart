import 'package:device_io/device_io.dart';
import 'package:test/test.dart';

void main() {
  group('FileHandle', () {
    test('close runs the release exactly once', () async {
      var closes = 0;
      final handle = FilePathHandle(
        path: '/x',
        sizeBytes: 1,
        onClose: () async => closes++,
        read: () => const Stream.empty(),
      );
      expect(handle.isClosed, isFalse);
      await handle.close();
      await handle.close();
      expect(closes, 1);
      expect(handle.isClosed, isTrue);
    });

    test('the two shapes are told apart by a switch', () {
      String kind(FileHandle h) => switch (h) {
        FilePathHandle(:final path) => 'path:$path',
        FileDescriptorHandle(:final fd) => 'fd:$fd',
      };
      expect(
        kind(
          FilePathHandle(
            path: '/a',
            sizeBytes: 0,
            onClose: () async {},
            read: () => const Stream.empty(),
          ),
        ),
        'path:/a',
      );
      expect(
        kind(
          FileDescriptorHandle(
            fd: 7,
            sizeBytes: 0,
            onClose: () async {},
            read: () => const Stream.empty(),
          ),
        ),
        'fd:7',
      );
    });
  });

  test('readStream reads until close, then refuses', () async {
    final handle = FilePathHandle(
      path: '/a',
      sizeBytes: 3,
      onClose: () async {},
      read: () => Stream.value([1, 2, 3]),
    );
    expect(await handle.readStream().first, [1, 2, 3]);
    await handle.close();
    expect(handle.readStream, throwsStateError);
  });
}
