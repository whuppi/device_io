# Capability Roadmap

Every capability the package offers or plans, with status. Nothing ships
while an active row sits un-resolved. Statuses: **DONE** · **BUILDING** ·
**PLANNED** · **WONT_DO** (with reason).

For the architecture see [`ARCHITECTURE.md`](ARCHITECTURE.md). For
maintenance recipes see [`UPDATING.md`](UPDATING.md).

---

## Picking — `AssetPickerAdapter`

| Capability | Status | Notes |
|---|---|---|
| Pick single image (gallery) | DONE | Lazy XFile-backed reads on every platform |
| Pick multiple images (+ limit) | DONE | Empty selection = `Cancelled`, never an empty list |
| Camera capture | DONE | Phones/tablets — native apps AND mobile browsers (capture attribute). Desktop is `Unsupported` (verified: desktop impls throw without a camera delegate) |
| Pick single / multiple files (+ extension filter) | DONE | Native lazy via cached path; web eager (`withData`) |
| Permission mapping | DONE | Exact image_picker codes → `PlatformPermissionDenied`; file_picker's SAF needs none |
| Pick video / generic media | PLANNED | `pickVideo` / `pickMedia` over image_picker's video surface |
| Lazy web file picks | PLANNED | File System Access `showOpenFilePicker` (Chromium) for blob-backed lazy handles; `withData` stays the fallback |

## Sharing — `SharingAdapter`

| Capability | Status | Notes |
|---|---|---|
| Share text (+ subject) | DONE | |
| Share file from bytes | DONE | Staged in unique cache subdirs; never eagerly deleted (receiver race) |
| Share file from stream | DONE | Constant memory on native; buffered on web (Web Share needs materialized files) |
| Dismissal as `Cancelled` | DONE | `ShareResultStatus.dismissed` / web `AbortError` |
| Share multiple files | PLANNED | `ShareParams.files` already carries a list; surface it |
| Share position origin (iPadOS popover anchor) | PLANNED | `sharePositionOrigin` passthrough |

## Saving — `DownloadAdapter`

| Capability | Status | Notes |
|---|---|---|
| Silent save (bytes) | DONE | Sanitized names, atomic no-clobber numbering, dir auto-created |
| Silent save (stream) | DONE | `.part`-then-rename; failed stream leaves nothing |
| `saveAs` via system dialog | DONE | SAF (Android) / Files export (iOS) / native dialog (desktop) / File System Access with download fallback (web) |
| Web streaming `saveAs` writes | DONE | `FileSystemWritableFileStream` on Chromium |
| Silent save to PUBLIC storage on mobile | PLANNED | Needs MediaStore native code (a plugin or our own channel) — `saveToDevice` on mobile is app-private today, documented loudly |
| Silent streaming saves on web | WONT_DO (for now) | A no-dialog streaming write needs a File System Access handle, which only user-initiated dialogs can produce; revisit if a handle-reuse API is added |

## Opening — `FileOpenerAdapter`

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
| Test suite (mirror + batteries × VM/Chrome runners) | BUILDING | Structure planned in `ARCHITECTURE.md` §8 |
| Example app (doubles as integration harness) | PLANNED | Smoke test for the programmatic surfaces per platform |
| CI via the shared workflow repo | PLANNED | device_io is the first consumer of `whuppi/ci` |
