# Changelog — prerelease lane

<!--
This is the PRERELEASE lane (`## X.Y.Z-dev.N`), cut from dev. The stable
lane lives in CHANGELOG.md. Read the CHANGELOG STANDARD comment there
before editing — it applies to both files.
-->

## 1.0.0-dev.0

First prerelease — cross-platform device IO for Flutter: pick, share,
save, open. One API on iOS, Android, macOS, Windows, Linux, and web.

- **API:** four capability contracts (`AssetPickerAdapter`,
  `SharingAdapter`, `DownloadAdapter`, `FileOpenerAdapter`) behind one
  `DeviceIO` container built by `initDeviceIO`. Every operation returns a
  sealed `PlatformResult` — `Supported` / `Cancelled` / `Unsupported` /
  `Failed`, with `PermissionDenied` as a named failure subtype carrying
  the caught error and stack trace.
- **Picking:** single + multi picks for images, videos, mixed media, and
  generic files; camera capture (photo + video) on phones/tablets —
  native apps and mobile browsers; lazy `PickedAsset` reads — bytes or a
  fresh stream per call, nothing loaded until asked. On Chromium, file
  picks use the File System Access picker for blob-backed lazy handles.
- **Saving:** silent saves with browser-grade filesystem safety (name
  sanitization incl. Windows reserved names, atomic no-clobber numbering,
  `.part`-then-rename stream writes), plus `saveAs` through the system
  save dialog on every platform (SAF / Files export / native dialog /
  File System Access with download fallback).
- **Sharing:** text, files, byte streams, and multi-file sheets
  (`shareFiles` + `ShareFile`) via the OS share sheet and the Web Share
  API, with dismissals mapped to `Cancelled` and an iPad popover anchor
  (`sharePositionOrigin`) on every method.
- **Opening:** `openBytes` on every platform (staged file + OS viewer
  natively, blob URL in a new tab on web) and `openPath` for
  just-saved files.
- **Platforms:** pub.dev attributes all six platforms; the stub-default
  conditional import and the registration-only dependency pattern are
  guarded by the pana platform gate (`make platforms`).
- **CI:** first consumer of the `whuppi/ci` shared workflows — fast PR gate,
  label-triggered cross-target full test (package × OS, host journeys,
  real-device integration smokes, release verify), triage / auto-close /
  labels / retry hygiene, and the changelog-driven release pipeline.
