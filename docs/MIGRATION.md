# Migrating from the workspace v0 API

The pre-release workspace version (consumed by path before 1.0.0) had a
different surface. Every breaking change, old → new. Delete this file
once no consumer is on the v0 shape.

---

## Results: null-means-cancelled is gone

Payloads are non-null; dismissal is a variant.

```dart
// v0 — cancelled arrived as Supported(null)
final result = await deviceIO.assetPicker.pickImage();   // PlatformResult<PickedAsset?>
if (result case PlatformSupported(:final value)) {
  if (value == null) return; // cancelled…
  use(value);
}

// v1 — cancelled is a named outcome, value is non-null
final result = await deviceIO.assetPicker.pickImage();   // PlatformResult<PickedAsset>
switch (result) {
  case PlatformSupported(:final value): use(value);
  case PlatformCancelled(): break;
  case PlatformPermissionDenied(): promptForSettings();
  case PlatformUnsupported(:final reason): hideFeature(reason);
  case PlatformFailed(:final message): showError(message);
}
```

`when()` gained a required `cancelled` callback:

```dart
// v0
result.when(supported: …, unsupported: …, failed: …);
// v1
result.when(supported: …, cancelled: …, unsupported: …, failed: …);
```

`PlatformFailed` now carries `stackTrace` alongside `error`, and
`PlatformPermissionDenied` (a `PlatformFailed` subtype) names permission
denials — a plain `case PlatformFailed()` arm still catches it.

## Opener: `openFile` → `openPath` + `openBytes`

```dart
// v0 — path-based, native-only
await deviceIO.fileOpener.openFile(filePath: path);

// v1 — same behavior, renamed
await deviceIO.fileOpener.openPath(filePath: path);

// v1 — NEW, works on every platform including web (blob tab)
await deviceIO.fileOpener.openBytes(bytes: bytes, fileName: 'doc.pdf');
```

## Init: loose param → config object

```dart
// v0
final deviceIO = await initDeviceIO(downloadSubfolder: 'MyApp');

// v1
final deviceIO = await initDeviceIO(
  config: DeviceIOConfig(downloadSubfolder: 'MyApp'),
);
```

## PickedAsset: `fromFile` → `lazy`

Only affects code CONSTRUCTING assets (custom adapters, tests):

```dart
// v0
PickedAsset.fromFile(
  mimeType: …, fileName: …,
  readBytesFromFile: () => …, streamFromFile: () => …,
);

// v1
PickedAsset.lazy(
  mimeType: …, fileName: …,
  readBytes: () => …, readStream: () => …,
);
```

`PickedAsset.fromBytes` is unchanged. Reading (`readBytes()` /
`readStream()`) is unchanged.

## New surface (no migration needed, worth adopting)

- `assetPicker.pickImages` / `pickFiles` — multi-select.
- `assetPicker.pickVideo` / `captureVideo` / `pickMedia` /
  `pickMultipleMedia` — video and mixed-media picking.
- `sharing.shareFileStream` — constant-memory large-file shares.
- `sharing.shareFiles` — several files in one sheet, via the `ShareFile`
  value type.
- `sharePositionOrigin` on every share method — the iPad popover anchor.
- `saveAs`/`saveToDevice`/`saveStreamToDevice` all take `mimeType`.
- `download.saveAs` — user-visible save via the system dialog (the
  mobile answer to `saveToDevice` landing in app-private storage).
- Share-sheet dismissal now surfaces as `PlatformCancelled` instead of
  success.

## Behavior changes without signature changes

- `saveToDevice` never overwrites: taken names get numbered variants
  (`report (1).pdf`). File names are sanitized (path separators and
  traversal neutralized).
- Failed stream saves no longer leave a partial file under the final
  name.
- Camera capture reports supported on mobile BROWSERS too (previously
  blanket-unsupported on web).
- On Chromium, generic file picks read lazily via the File System Access
  picker instead of eagerly loading every selected file.
