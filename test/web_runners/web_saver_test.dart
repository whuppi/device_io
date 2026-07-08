// CHARTER — this file alone proves, in a REAL browser, the WebFileSaver's
// behavior against an instrumented JS surface: save builds a Blob with
// the declared mimeType (explicit passthrough AND inferred-from-fileName) and
// returns Success(SavedByBrowser()); saveAs, with showSaveFilePicker OVERRIDDEN to resolve
// a fake handle, receives suggestedName == fileName, writes the EXACT declared
// bytes to the writable, closes it, and returns Success(SavedByBrowser(name)); saveAs
// with the picker REJECTING as AbortError → Cancelled AND no download fallback
// (createObjectURL untouched); rejecting as SecurityError → falls back to the
// download path (createObjectURL WAS called) → Success(SavedByBrowser()); the picker
// DELETED from window → straight to download fallback → Success(SavedByBrowser());
// saveStream buffers a patterned multi-chunk stream into ONE Blob whose
// size equals the total and whose full content round-trips as patterned.
// This is also the file that PROVES the override mechanism (resolve, record,
// reject-as-DOMException) end to end — see the first two tests.
// Diet: declared byte fixtures from ../harness/bytes.dart; inline literals here.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:device_io/src/saver/save_location.dart';
import 'package:device_io/src/saver/web/web_file_saver.dart';
import 'package:device_io/src/types/platform_result.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../harness/bytes.dart';
import '../harness/timeouts.dart';
import 'js_overrides.dart';

void main() {
  final adapter = WebFileSaver();
  final overrides = <PropOverride>[];

  // What an instrumented URL.createObjectURL recorded.
  var createObjectUrlCalls = 0;
  web.Blob? lastBlob;

  // Wraps URL.createObjectURL: records the Blob, returns a fake URL so no
  // real blob resource leaks. The adapter only feeds the URL to an <a>.
  void instrumentCreateObjectUrl() {
    createObjectUrlCalls = 0;
    lastBlob = null;
    overrides.add(
      PropOverride.install(
        urlCtor,
        'createObjectURL',
        ((JSObject blob) {
          createObjectUrlCalls++;
          lastBlob = blob as web.Blob;
          return 'blob:recorded-$createObjectUrlCalls'.toJS;
        }).toJS,
      ),
    );
  }

  tearDown(() {
    restoreAll(overrides);
    overrides.clear();
  });

  // ── save: Blob carries the declared/inferred mimeType ──

  test(
    'save returns Success(SavedByBrowser()) with an explicit mimeType',
    () async {
      instrumentCreateObjectUrl();
      final result = await adapter.save(
        bytes: utf8SampleBytes,
        fileName: 'note.bin',
        mimeType: 'application/x-custom',
      );
      expect(result, isA<PlatformSuccess<SaveLocation>>());
      expect(
        (result as PlatformSuccess<SaveLocation>).value,
        isA<SavedByBrowser>(),
      );
      expect(createObjectUrlCalls, 1);
      expect(lastBlob!.type, 'application/x-custom');
    },
    timeout: t(4),
  );

  test('save infers the Blob type from the fileName when null', () async {
    instrumentCreateObjectUrl();
    final result = await adapter.save(
      bytes: utf8SampleBytes,
      fileName: 'photo.png',
    );
    expect(result, isA<PlatformSuccess<SaveLocation>>());
    expect(createObjectUrlCalls, 1);
    expect(lastBlob!.type, 'image/png');
  }, timeout: t(4));

  // ── saveAs: picker resolves a fake handle (records + writes) ──
  // PROVES: resolve a scripted JSPromise, record the passed options, capture
  // the bytes handed to the writable.

  test(
    'saveAs writes exact bytes to the picker handle and returns its name',
    () async {
      String? recordedSuggestedName;
      JSUint8Array? written;
      var closed = false;

      // A writable that records the bytes and the close().
      final writable = JSObject()
        ..setProperty(
          'write'.toJS,
          ((JSUint8Array data) {
            written = data;
            return jsResolve<JSAny?>(null);
          }).toJS,
        )
        ..setProperty(
          'close'.toJS,
          (() {
            closed = true;
            return jsResolve<JSAny?>(null);
          }).toJS,
        );

      // A handle exposing name + createWritable().
      final handle = JSObject()
        ..setProperty('name'.toJS, 'saved-as.bin'.toJS)
        ..setProperty(
          'createWritable'.toJS,
          (() => jsResolve<JSObject>(writable)).toJS,
        );

      overrides.add(
        PropOverride.install(
          windowObj,
          'showSaveFilePicker',
          ((JSObject options) {
            recordedSuggestedName = readString(options, 'suggestedName');
            return jsResolve<JSObject>(handle);
          }).toJS,
        ),
      );
      instrumentCreateObjectUrl();

      final payload = patternedBytes(4096);
      final result = await adapter.saveAs(
        bytes: payload,
        fileName: 'report.bin',
      );

      expect(recordedSuggestedName, 'report.bin');
      expect(written, isNotNull);
      expect(written!.toDart, orderedEquals(payload));
      expect(closed, isTrue);
      expect(result, isA<PlatformSuccess<SaveLocation>>());
      expect(
        ((result as PlatformSuccess<SaveLocation>).value as SavedByBrowser)
            .fileName,
        'saved-as.bin',
      );
      // The dialog path succeeded — no download fallback.
      expect(createObjectUrlCalls, 0);
    },
    timeout: t(5),
  );

  // ── saveAs: picker rejects as AbortError → Cancelled, no fallback ──
  // PROVES: a real Promise.reject(DOMException) surfaces to the adapter as an
  // AbortError whose toString the adapter matches.

  test(
    'saveAs picker AbortError → Cancelled and NO download fallback',
    () async {
      overrides.add(
        PropOverride.install(
          windowObj,
          'showSaveFilePicker',
          ((JSObject options) => jsReject<JSObject>(
            domException('AbortError', 'user aborted'),
          )).toJS,
        ),
      );
      instrumentCreateObjectUrl();

      final result = await adapter.saveAs(
        bytes: utf8SampleBytes,
        fileName: 'report.bin',
      );

      expect(result, isA<PlatformCancelled<SaveLocation>>());
      expect(createObjectUrlCalls, 0); // fallback must NOT have run
    },
    timeout: t(5),
  );

  // ── saveAs: picker rejects as SecurityError → download fallback ──

  test(
    'saveAs picker SecurityError → download fallback → Success(SavedByBrowser())',
    () async {
      overrides.add(
        PropOverride.install(
          windowObj,
          'showSaveFilePicker',
          ((JSObject options) => jsReject<JSObject>(
            domException('SecurityError', 'no gesture'),
          )).toJS,
        ),
      );
      instrumentCreateObjectUrl();

      final result = await adapter.saveAs(
        bytes: utf8SampleBytes,
        fileName: 'report.png',
      );

      expect(result, isA<PlatformSuccess<SaveLocation>>());
      expect(
        (result as PlatformSuccess<SaveLocation>).value,
        isA<SavedByBrowser>(),
      );
      expect(createObjectUrlCalls, 1); // fallback DID run
      expect(lastBlob!.type, 'image/png');
    },
    timeout: t(5),
  );

  // ── saveAs: picker DELETED → straight to download fallback ──

  test('saveAs with showSaveFilePicker absent → download fallback', () async {
    overrides.add(PropOverride.remove(windowObj, 'showSaveFilePicker'));
    instrumentCreateObjectUrl();

    final result = await adapter.saveAs(
      bytes: utf8SampleBytes,
      fileName: 'doc.pdf',
    );

    expect(result, isA<PlatformSuccess<SaveLocation>>());
    expect(createObjectUrlCalls, 1);
    expect(lastBlob!.type, 'application/pdf');
  }, timeout: t(4));

  // ── saveStream: multi-chunk → ONE Blob of the full size ──

  test(
    'saveStream buffers a patterned multi-chunk stream into one Blob',
    () async {
      instrumentCreateObjectUrl();

      const total = 5000;
      final source = patternedBytes(total);
      Stream<List<int>> chunks() async* {
        // Irregular chunk sizes — a dropped/reordered chunk breaks isPatterned.
        var offset = 0;
        for (final size in const [1000, 1, 2499, 1500]) {
          yield source.sublist(offset, offset + size);
          offset += size;
        }
      }

      final result = await adapter.saveStream(
        byteStream: chunks(),
        fileName: 'video.mp4',
      );

      expect(result, isA<PlatformSuccess<SaveLocation>>());
      expect(createObjectUrlCalls, 1); // exactly one blob
      expect(lastBlob!.size, total);
      expect(lastBlob!.type, 'video/mp4');
      // Full-content integrity over the assembled blob.
      final roundTrip = await blobBytes(lastBlob!);
      expect(isPatterned(roundTrip), isTrue);
    },
    timeout: t(6),
  );
}
