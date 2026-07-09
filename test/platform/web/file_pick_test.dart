// CHARTER — this file alone proves, in a REAL browser, lazyWebFilePick (the
// File System Access path, reached through the web_file_pick.dart platform
// seam) against an instrumented showOpenFilePicker: with the picker DELETED it
// returns null (falls through to the file_picker ladder); overridden to resolve
// real File-backed handles it returns Success assets that are LAZY (readBytes
// yields the exact declared bytes; readStream is fresh per call and completes
// twice), derive mimeType from file.type and, when type is empty, from the
// fileName; the recorded options carry multiple:false/true and, for
// allowedExtensions ['png','jpg'], an `accept` object grouping dot-prefixed
// extensions under their MIMEs; an AbortError rejection → Cancelled and a
// non-abort rejection → Failed (never null — no second-dialog fallthrough).
// Diet: declared byte fixtures from ../harness/bytes.dart; inline literals here.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:device_io/src/picker/picked_asset.dart';
import 'package:device_io/src/picker/web_file_pick.dart';
import 'package:device_io/src/types/platform_result.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../harness/bytes.dart';
import '../../harness/timeouts.dart';
import 'js_overrides.dart';

void main() {
  final overrides = <PropOverride>[];

  // The options object the adapter handed to showOpenFilePicker.
  JSObject? recordedOptions;

  /// Builds a real File-backed handle from declared [bytes] + name + type.
  JSObject fileHandle({
    required Uint8List bytes,
    required String name,
    required String type,
  }) {
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: type));
    final file = web.File([blob].toJS, name, web.FilePropertyBag(type: type));
    return JSObject()
      ..setProperty('getFile'.toJS, (() => jsResolve<web.File>(file)).toJS);
  }

  /// Installs showOpenFilePicker resolving [handles]; records the options.
  void installResolve(List<JSObject> handles) {
    recordedOptions = null;
    overrides.add(
      PropOverride.install(
        windowObj,
        'showOpenFilePicker',
        ((JSObject options) {
          recordedOptions = options;
          return jsResolve<JSArray<JSObject>>(handles.toJS);
        }).toJS,
      ),
    );
  }

  /// Installs showOpenFilePicker rejecting with [reason].
  void installReject(JSAny reason) {
    recordedOptions = null;
    overrides.add(
      PropOverride.install(
        windowObj,
        'showOpenFilePicker',
        ((JSObject options) => jsReject<JSArray<JSObject>>(reason)).toJS,
      ),
    );
  }

  tearDown(() {
    restoreAll(overrides);
    overrides.clear();
  });

  // ── picker absent → null (fall through to file_picker) ──

  test(
    'lazyWebFilePick returns null when showOpenFilePicker is absent',
    () async {
      overrides.add(PropOverride.remove(windowObj, 'showOpenFilePicker'));
      final result = await lazyWebFilePick(allowMultiple: false);
      expect(result, isNull);
    },
    timeout: t(4),
  );

  // ── resolve real handles → Success, lazy, exact bytes ──

  test(
    'resolves lazy assets whose readBytes yields the exact declared bytes',
    () async {
      final declared = patternedBytes(3000);
      installResolve([
        fileHandle(bytes: declared, name: 'shot.png', type: 'image/png'),
      ]);

      final result = await lazyWebFilePick(allowMultiple: false);
      expect(result, isA<PlatformSuccess<List<PickedAsset>>>());
      final assets = (result! as PlatformSuccess<List<PickedAsset>>).value;
      expect(assets.length, 1);

      final asset = assets.first;
      expect(asset.fileName, 'shot.png');
      expect(asset.mimeType, 'image/png'); // from file.type

      // readBytes → exact declared bytes.
      final bytes = await asset.readBytes();
      expect(bytes, orderedEquals(declared));

      // readStream is fresh per call — consume it twice, both complete.
      final first = <int>[];
      await for (final chunk in asset.readStream()) {
        first.addAll(chunk);
      }
      final second = <int>[];
      await for (final chunk in asset.readStream()) {
        second.addAll(chunk);
      }
      expect(first, orderedEquals(declared));
      expect(second, orderedEquals(declared));
    },
    timeout: t(6),
  );

  test('mimeType is inferred from fileName when file.type is empty', () async {
    installResolve([
      fileHandle(bytes: utf8SampleBytes, name: 'note.txt', type: ''),
    ]);
    final result = await lazyWebFilePick(allowMultiple: false);
    final assets = (result! as PlatformSuccess<List<PickedAsset>>).value;
    expect(assets.single.mimeType, 'text/plain'); // inferred from '.txt'
  }, timeout: t(4));

  // ── options pass-through: multiple + accept shape ──

  test(
    'records multiple:false and no types when no extensions given',
    () async {
      installResolve([
        fileHandle(bytes: utf8SampleBytes, name: 'a.txt', type: 'text/plain'),
      ]);
      await lazyWebFilePick(allowMultiple: false);
      expect(recordedOptions, isNotNull);
      expect(
        recordedOptions!.getProperty<JSBoolean>('multiple'.toJS).toDart,
        isFalse,
      );
      expect(recordedOptions!.hasProperty('types'.toJS).toDart, isFalse);
    },
    timeout: t(4),
  );

  test(
    'records multiple:true and the exact accept shape for [png, jpg]',
    () async {
      installResolve([
        fileHandle(bytes: utf8SampleBytes, name: 'a.png', type: 'image/png'),
      ]);
      await lazyWebFilePick(
        allowMultiple: true,
        allowedExtensions: const ['png', 'jpg'],
      );

      expect(
        recordedOptions!.getProperty<JSBoolean>('multiple'.toJS).toDart,
        isTrue,
      );

      final types = recordedOptions!
          .getProperty<JSArray<JSObject>>('types'.toJS)
          .toDart;
      expect(types.length, 1);
      final accept = types.first.getProperty<JSObject>('accept'.toJS);

      // png → image/png : ['.png']; jpg → image/jpeg : ['.jpg'].
      final png = accept
          .getProperty<JSArray<JSString>>('image/png'.toJS)
          .toDart;
      final jpg = accept
          .getProperty<JSArray<JSString>>('image/jpeg'.toJS)
          .toDart;
      expect(png.map((e) => e.toDart), ['.png']);
      expect(jpg.map((e) => e.toDart), ['.jpg']);
      expect(readString(types.first, 'description'), 'Allowed files');
    },
    timeout: t(4),
  );

  // ── rejection mapping — never null ──

  test('AbortError rejection → Cancelled', () async {
    installReject(domException('AbortError'));
    final result = await lazyWebFilePick(allowMultiple: false);
    expect(result, isA<PlatformCancelled<List<PickedAsset>>>());
  }, timeout: t(4));

  test(
    'non-abort rejection → Failed (never null — no second dialog)',
    () async {
      installReject(domException('NotAllowedError'));
      final result = await lazyWebFilePick(allowMultiple: false);
      expect(result, isA<PlatformFailed<List<PickedAsset>>>());
      expect(result, isNotNull);
    },
    timeout: t(4),
  );
}
