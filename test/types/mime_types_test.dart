// CHARTER — this file alone proves: mimeTypeFromFileName resolves curated
// extensions to their declared MIME types, falls back to package:mime for
// extensions outside the curated set, and returns application/octet-stream for
// garbage / extensionless names; case handling matches the source (extensions
// lowercased before lookup); extensionFromMimeType hits the curated map,
// falls back to package:mime, and returns the fallback parameter for unknowns;
// and extensionToMime is unmodifiable.
// Diet: inline literals declared against the curated maps read from source.

import 'package:device_io/src/types/mime_types.dart';
import 'package:test/test.dart';

import '../harness/timeouts.dart';

void main() {
  // ── mimeTypeFromFileName: curated hits ──

  test('curated extensions resolve to their declared MIME types', () {
    // Declared truths — pairs picked by reading the curated mimeToExtension.
    expect(mimeTypeFromFileName('photo.png'), 'image/png');
    expect(mimeTypeFromFileName('scan.jpg'), 'image/jpeg');
    expect(mimeTypeFromFileName('doc.pdf'), 'application/pdf');
    expect(mimeTypeFromFileName('data.json'), 'application/json');
    expect(mimeTypeFromFileName('clip.mp4'), 'video/mp4');
    // Alias added on top of the reverse map.
    expect(mimeTypeFromFileName('photo.jpeg'), 'image/jpeg');
  }, timeout: t(2));

  test(
    'extension lookup is case-insensitive (lowercased before lookup)',
    () {
      expect(mimeTypeFromFileName('PHOTO.PNG'), 'image/png');
      expect(mimeTypeFromFileName('Doc.Pdf'), 'application/pdf');
    },
    timeout: t(2),
  );

  // ── mimeTypeFromFileName: package:mime fallback + default ──

  test(
    'an extension outside the curated set falls back to package:mime',
    () {
      // .mov is not in the curated map but is in package:mime's database.
      expect(mimeTypeFromFileName('movie.mov'), 'video/quicktime');
    },
    timeout: t(2),
  );

  test('a garbage extension falls back to application/octet-stream', () {
    expect(mimeTypeFromFileName('file.zzznotreal'), 'application/octet-stream');
  }, timeout: t(2));

  test('a name with no extension is application/octet-stream', () {
    expect(mimeTypeFromFileName('READMEnoext'), 'application/octet-stream');
  }, timeout: t(2));

  // ── extensionFromMimeType ──

  test('curated MIME types resolve to their declared extensions', () {
    expect(extensionFromMimeType('image/png'), 'png');
    expect(extensionFromMimeType('image/jpeg'), 'jpg');
    expect(extensionFromMimeType('application/pdf'), 'pdf');
    expect(extensionFromMimeType('text/csv'), 'csv');
  }, timeout: t(2));

  test(
    'a MIME type outside the curated set falls back to package:mime',
    () {
      // video/quicktime is not a curated key; package:mime knows .mov.
      expect(extensionFromMimeType('video/quicktime'), 'mov');
    },
    timeout: t(2),
  );

  test('an unknown MIME type returns the fallback (default "bin")', () {
    expect(extensionFromMimeType('application/x-not-real'), 'bin');
  }, timeout: t(2));

  test('an unknown MIME type returns a caller-supplied fallback', () {
    expect(
      extensionFromMimeType('application/x-not-real', fallback: 'dat'),
      'dat',
    );
  }, timeout: t(2));

  // ── extensionToMime immutability ──

  test('extensionToMime is unmodifiable — mutation throws', () {
    expect(() => extensionToMime['png'] = 'image/lies', throwsUnsupportedError);
  }, timeout: t(2));

  test('extensionToMime carries the declared alias entries', () {
    // Aliases the source adds on top of the reverse map.
    expect(extensionToMime['jpeg'], 'image/jpeg');
    expect(extensionToMime['png'], 'image/png');
  }, timeout: t(2));
}
