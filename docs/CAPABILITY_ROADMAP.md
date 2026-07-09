# Capability Roadmap

Every capability the package offers or plans, with status. Nothing ships
while an active row sits un-resolved. Statuses: **DONE** · **BUILDING** ·
**PLANNED** · **WONT_DO** (with reason).

For the architecture see [`ARCHITECTURE.md`](ARCHITECTURE.md). For
maintenance recipes see [`UPDATING.md`](UPDATING.md).

---

## Picking — `AssetPicker`

| Capability | Status | Notes |
|---|---|---|
| Pick single image (gallery) | DONE | Lazy XFile-backed reads on every platform |
| Pick multiple images (+ limit) | DONE | Empty selection = `Cancelled`, never an empty list |
| Camera capture | DONE | Phones/tablets — native apps AND mobile browsers (capture attribute). Desktop is `Unsupported` (verified: desktop impls throw without a camera delegate) |
| Pick single / multiple files (+ extension filter) | DONE | Native lazy via cached path; web lazy via File System Access where present, otherwise file_picker's `readAsBytes` (single lazy; a multi-pick buffers up front) |
| Permission mapping | DONE | Exact image_picker codes → `PlatformPermissionDenied`; file_picker's SAF needs none |
| Pick video / mixed media | DONE | `pickVideo` / `captureVideo` / `pickMedia` / `pickMultipleMedia`, lazy like every pick; `maxDuration` honored for camera recording only (plugin behavior, documented); no permission codes exist beyond the four mapped (verified against plugin source) |
| Lazy web file picks | DONE | `showOpenFilePicker` (Chromium) behind a stub-default conditional export; blob-backed handles read on demand; `withData` fallback on Firefox/Safari |

## Sharing — `Sharer`

| Capability | Status | Notes |
|---|---|---|
| Share text (+ subject) | DONE | |
| Share file from bytes | DONE | Staged in unique cache subdirs; never eagerly deleted (receiver race) |
| Share file from stream | DONE | Constant memory on native; buffered on web (Web Share needs materialized files) |
| Dismissal as `Cancelled` | DONE | `ShareResultStatus.dismissed` / web `AbortError` |
| Share multiple files | DONE | `shareFiles` + the `ShareFile` value type; one staging dir per call with in-call name dedup; empty list throws `ArgumentError` (caller bug) |
| Share position origin (iPadOS popover anchor) | DONE | `sharePositionOrigin` on every share method; anchors the popover on iPad/Mac, ignored elsewhere (verified against ShareParams docs) |

## Saving — `FileSaver`

| Capability | Status | Notes |
|---|---|---|
| Silent save (bytes) | DONE | Sanitized names, atomic no-clobber numbering, dir auto-created |
| Silent save (stream) | DONE | `.part`-then-rename; failed stream leaves nothing |
| `saveAs` via system dialog | DONE | SAF (Android) / Files export (iOS) / native dialog (desktop) / File System Access with download fallback (web); `mimeType` feeds the fallback's blob type |
| Web streaming `saveAs` writes | DONE | `FileSystemWritableFileStream` on Chromium |
| Silent save to PUBLIC storage on mobile | WONT_DO (for now) | Android-only gap (desktop/web `save` already land user-visible; iOS has no public Downloads at all) whose fix needs first-party MediaStore native code — an identity change from plugin-wrapper to plugin. `saveAs` is the user-visible mobile answer. Revisit if a consumer app needs background exports to public storage. |
| Silent streaming saves on web | WONT_DO (for now) | A no-dialog streaming write needs a File System Access handle; handles can be persisted (IndexedDB) but re-activating one still requires a user-gesture permission grant, so "silent" stays impossible. Revisit if the gesture requirement is relaxed |

## Opening — `FileOpener`

| Capability | Status | Notes |
|---|---|---|
| `openBytes` on every platform | DONE | Native: stage + OS open; web: blob URL in a new tab |
| `openPath` (native) | DONE | Desktop via OS open commands (stderr surfaced on failure); mobile via open_filex's channel |
| `openPath` on web | WONT_DO | Filesystem paths do not exist on web — `openBytes` is the web path |

## Cross-cutting

| Capability | Status | Notes |
|---|---|---|
| Sealed `PlatformResult` with `Cancelled` + `PermissionDenied` | DONE | Stack traces captured on failures |
| Six-platform pub.dev attribution | DONE | pana-gated (`make platforms`); registration-only deps pattern |
| MIME lookups (curated + full database) | DONE | package:mime behind the curated maps |
| App permission requesting | WONT_DO | Apps own their permission UX and Info.plist/manifest entries; this package surfaces denials as typed results |
| Paths or eager bytes on `PickedAsset` | WONT_DO | Design note in `picked_asset.dart` — paths don't exist on web; eager bytes OOM large files |

## Infrastructure

| Capability | Status | Notes |
|---|---|---|
| Strict lints + zero-issue analyzer | DONE | |
| Makefile gates (format / analyze / analyze-floor / platforms) | DONE | |
| Test suite (mirror VM suites · runtime layer · grammar battery · real-Chrome quarantine) | DONE | Chartered behavioral tests; recording fakes at platform-interface seams; the runtime/resolve layer pinned in `test/runtime/`; the cross-adapter `PlatformResult` grammar as one spec in `test/batteries/`; browser charters under `test/platform/web/`; mechanical guards (`make test-guards`). Shape in `ARCHITECTURE.md` §8 |
| Example app | DONE | Six platforms, one exhaustive `PlatformResult` renderer, lazy reads on tap; host journeys cover all four tabs (pick / share / save / open + cross-tab plumb); the integration smoke proves real filesystem effects on-device |
| CI via the shared workflow repo | DONE | First consumer of `whuppi/ci` (born on v1.0.0; pinned per-workflow and bumped by grouped Dependabot PRs — currently v2.0.4). Thin caller stubs over the reusable workflows; fast PR gate in `ci.yml` (format/analyze/floor/platforms/guards/unit/web via `make-target`); label-triggered cross-target matrix in `full-test.yml` (package × OS, host journeys, real-device integration smokes, release verify); release via the reusable gate → discover → publish workflow (no binaries). Shared-CI upgrades arrive as grouped Dependabot PRs, tested by that PR's own CI |
| Published to pub.dev | DONE | `1.0.0` stable live under the verified publisher (whuppi.com); 160/160 pana; two-lane changelogs drive the release train (prerelease from dev, stable from prod, env-gated publish approval) |
| pub.dev listing | DONE | Novice-first description (≤180 chars, scored range), five searched topics, README banner (light/dark `<picture>`, flattened to `<img>` in the published tarball) |
