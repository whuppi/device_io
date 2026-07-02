import 'package:device_io/device_io.dart';
import 'package:test/test.dart';

void main() {
  group('mimeToExtension', () {
    test('maps common types', () {
      expect(mimeToExtension['image/png'], 'png');
      expect(mimeToExtension['image/jpeg'], 'jpg');
      expect(mimeToExtension['application/pdf'], 'pdf');
      expect(mimeToExtension['audio/mpeg'], 'mp3');
      expect(mimeToExtension['video/mp4'], 'mp4');
      expect(mimeToExtension['application/octet-stream'], 'bin');
    });
  });

  group('extensionToMime', () {
    test('reverses every mimeToExtension entry', () {
      for (final entry in mimeToExtension.entries) {
        expect(
          extensionToMime[entry.value],
          isNotNull,
          reason: 'extension "${entry.value}" has no reverse mapping',
        );
      }
    });

    test('carries aliases beyond the reverse map', () {
      expect(extensionToMime['jpeg'], 'image/jpeg');
      expect(extensionToMime['jpg'], 'image/jpeg');
      expect(extensionToMime['heif'], 'image/heic');
    });
  });

  group('mimeTypeFromFileName', () {
    test('resolves known extensions', () {
      expect(mimeTypeFromFileName('photo.png'), 'image/png');
      expect(mimeTypeFromFileName('report.pdf'), 'application/pdf');
      expect(mimeTypeFromFileName('song.mp3'), 'audio/mpeg');
    });

    test('is case-insensitive on the extension', () {
      expect(mimeTypeFromFileName('PHOTO.PNG'), 'image/png');
      expect(mimeTypeFromFileName('Report.Pdf'), 'application/pdf');
    });

    test('uses the last dot for multi-dot names', () {
      expect(mimeTypeFromFileName('notes.backup.txt'), 'text/plain');
    });

    test('falls back to octet-stream', () {
      expect(mimeTypeFromFileName('noextension'), 'application/octet-stream');
      expect(mimeTypeFromFileName('weird.xyzzy'), 'application/octet-stream');
      expect(mimeTypeFromFileName('trailingdot.'), 'application/octet-stream');
      expect(mimeTypeFromFileName(''), 'application/octet-stream');
    });
  });

  group('category sets', () {
    test('image set covers both jpg spellings', () {
      expect(imageExtensions, containsAll(['jpg', 'jpeg', 'png', 'webp']));
    });

    test('sets are disjoint', () {
      final all = [
        ...imageExtensions,
        ...audioExtensions,
        ...videoExtensions,
        ...documentExtensions,
        ...vectorExtensions,
      ];
      expect(
        all.toSet().length,
        all.length,
        reason: 'an extension appears in more than one category set',
      );
    });
  });
}
