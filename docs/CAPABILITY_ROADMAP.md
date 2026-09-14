# Capability Roadmap

Every capability the package offers or plans, with status. Nothing ships
while an active row sits un-resolved. Statuses: **DONE** · **BUILDING** ·
**PLANNED** · **WONT_DO** (with reason).

Platform-honesty rule: a proposed capability that would be `Unsupported` on
more platforms than it works on defaults to WONT_DO — the package's promise
is cross-platform verbs, not native-only conveniences. A row may override
the default only with an argued note.

For the architecture see [`ARCHITECTURE.md`](ARCHITECTURE.md). For
maintenance recipes see [`UPDATING.md`](UPDATING.md).

---

## Picking — `AssetPicker`

| Capability | Status | Notes |
|---|---|---|
| Pick single image (gallery) | DONE | Lazy XFile-backed reads on every platform |
| Pick multiple images (+ limit) | DONE | Empty selection = `Cancelled`, never an empty list |
| Camera capture | DONE | Phones/tablets — native apps AND mobile browsers (the `capture` input hint). Desktop is `Unsupported`, verified in both worlds: desktop native impls throw `StateError` without a camera delegate, and desktop browsers ignore the `capture` hint (the plugin would silently degrade to a file picker — the gate refuses first). Pinned in `UPDATING.md` |
| Pick single / multiple files (+ extension filter) | DONE | Native lazy via cached path; web lazy via File System Access where present, otherwise file_picker's `readAsBytes` (single lazy; a multi-pick buffers up front) |
| Permission mapping | DONE | Exact image_picker codes → `PermissionDenied`; file_picker's SAF needs none |
| Pick video / mixed media | DONE | `pickVideo` / `captureVideo` / `pickMedia` / `pickMultipleMedia`, lazy like every pick; `maxDuration` honored for camera recording only (plugin behavior, documented); no permission codes exist beyond the four mapped (verified against plugin source) |
| Lazy web file picks | DONE | `showOpenFilePicker` (Chromium) behind a stub-default conditional export; blob-backed handles read on demand; `withData` fallback on Firefox/Safari |
| Pick a directory | DONE | `pickDirectory` — 5 native platforms; web returns `Unsupported` (browsers expose no directory paths). Overrides the platform-honesty default: it exists to feed `saveInto`, and the pair degrades cleanly to `saveAs` on web. Note: file_picker maps its own channel errors to null, so a protected-directory denial surfaces as `Cancelled` |
| Drag-and-drop intake | WONT_DO | A UI-layer concern (a drop target is a widget); packages like desktop_drop own it. This package stays UI-free — a dropped file's bytes can already flow into `openBytes`/`share`/`save` |

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
| `saveInto` a chosen directory | DONE | Silent bytes-save into a caller-supplied directory (pairs with `pickDirectory` for a pick-once-save-many flow); sanitized names + no-clobber numbering, same guarantees as `save`; web returns `Unsupported` |
| Save/share progress callbacks | WONT_DO | Byte-level progress needs plugin-internal hooks none of the wrapped plugins expose. Callers who need progress can wrap their own byte stream (count chunks before handing it to `saveStream`) — the stream seam already makes this a 5-line caller recipe |
| Silent save to PUBLIC storage on mobile | WONT_DO (for now) | Android-only gap (desktop/web `save` already land user-visible; iOS has no public Downloads at all) whose fix needs first-party MediaStore native code — an identity change from plugin-wrapper to plugin. `saveAs` is the user-visible mobile answer. Revisit if a consumer app needs background exports to public storage. |
| Silent streaming saves on web | WONT_DO (for now) | A no-dialog streaming write needs a File System Access handle; handles can be persisted (IndexedDB) but re-activating one still requires a user-gesture permission grant, so "silent" stays impossible. Revisit if the gesture requirement is relaxed |

## Opening — `FileOpener`

| Capability | Status | Notes |
|---|---|---|
| `openBytes` on every platform | DONE | Native: stage + OS open; web: blob URL in a new tab |
| `openPath` (native) | DONE | Desktop via OS open commands (stderr surfaced on failure); mobile via open_filex's channel |
| `openPath` on web | WONT_DO | Filesystem paths do not exist on web — `openBytes` is the web path |
| `open(SaveLocation)` | DONE | Closes the save→open loop without caller destructuring: `SavedAtPath` opens at its path; `SavedByBrowser` is `Unsupported` (the browser owns downloads — no handle to reopen) |
| Open a URI / deep link | WONT_DO | url_launcher owns URI opening and does it well; wrapping it adds a dependency without adding a guarantee |

## System probe — `SystemProbe`

| Capability | Status | Notes |
|---|---|---|
| Free storage bytes | PLANNED | All six platforms. Native reads the volume backing a caller-supplied path; web reads the origin's remaining quota. Async on every platform because the web source is a Promise |
| Total physical RAM | PLANNED | Five platforms. Web is `Unsupported` — browsers refuse to answer honestly (see below). Overrides the platform-honesty default the same way `pickDirectory` does: it works on 5 of 6, and the sixth degrades to a typed `Unsupported`, not a wrong number |
| Free RAM / available RAM | WONT_DO | No portable meaning. macOS reports most memory as "used" by design (the page cache is not free-able-on-demand in the way callers assume), Linux's `MemAvailable` is a heuristic, and iOS refuses entirely. Callers wanting a fit decision want total RAM plus their own budget policy |
| CPU / core count / OS version | WONT_DO | Not IO. `device_info_plus` owns this and does it well; this package's promise is device *IO* verbs |

### Why build rather than depend

No pub package covers the six platforms acceptably. Surveyed:

| Package | Platforms | Likes | Last release |
|---|---|---|---|
| `disk_space_plus` | Android, iOS | 14 | 13 months |
| `disk_space` | Android, iOS | 62 | 4 years |
| `disk_space_2` | Android, iOS, Linux, Windows — **no macOS** | 16 | current |
| `disk_usage` | 5 native | **2** | 11 months |
| `universal_disk_space` | 5 native | 14 | 5 years |

Only two reach macOS: one with two likes, one five years stale that works
by parsing `df` output (breaks on locale and format changes). None reaches
web. Taking a two-like unverified plugin for a capability this small is the
dependency a reviewer flags — and it would still leave web unanswered.

### Web — the asymmetry

Storage and RAM diverge sharply on web, and the reason is privacy, not
effort.

**Storage: fully answerable.** `navigator.storage.estimate()` is Baseline
Widely available (since September 2023 — every browser). It returns
`{quota, usage}`; free is `quota - usage`. That is not a degraded answer,
it is the *correct* one: the browser refuses writes past the origin quota
regardless of physical disk, so quota **is** the ceiling. Asking for
physical free space on web would be the wrong question. MDN notes the
values are deliberately imprecise (compression, dedup, obfuscation) and
that quota varies per origin with engagement signals — fine for a
conservative preflight, which wants a floor.

**RAM: not answerable.** `navigator.deviceMemory` is *Limited
availability* — MDN: "does not work in some of the most widely-used
browsers" (no Safari, no Firefox). Worse, the value is "imprecise to
curtail fingerprinting": rounded to the **nearest power of two**, then
clamped to implementation-defined bounds — MDN's own example set is
`2, 4, 8, 16, 32`. A 64 GB machine may report `32`, or `8`. Surfacing that
as "total RAM" into a does-this-model-fit decision is a correctness bug.
`Unsupported` is the honest answer.

### Native — verified layouts and the traps

The hazard is that a wrong FFI struct layout returns silent garbage rather
than crashing. Verify each platform against its real header, and prove the
layout with a compiled C probe (`sizeof` + `offsetof`, and one live call
whose result is checked against `df`) before trusting the Dart struct.

**macOS — verified against the installed SDK.** `sys/statvfs.h`:

```c
struct statvfs {
    unsigned long f_bsize, f_frsize;
    fsblkcnt_t    f_blocks, f_bfree, f_bavail;
    fsfilcnt_t    f_files,  f_ffree, f_favail;
    unsigned long f_fsid, f_flag, f_namemax;
};
```

The trap: `sys/_types.h:70` defines `__darwin_fsblkcnt_t` as **`unsigned
int`** — 32-bit, not 64. A Dart struct that declares those three fields
`Uint64` misreads every field from `f_blocks` onward. Declare them
`Uint32`. (Consequence: `f_bavail * f_frsize` saturates around 16 TB on
4 KiB blocks — acceptable, and worth an assert.) BSD `statfs` has genuine
64-bit counts if that ceiling ever matters, at the cost of a much larger
struct and the `statfs$INODE64` symbol-suffix question on x86_64.

**Linux / Android — NOT yet verified.** glibc and bionic both expose
`statvfs`, but `fsblkcnt_t` is 32-bit on 32-bit Android without
`_FILE_OFFSET_BITS=64`, and the field order after `f_favail` differs from
Darwin. Use `statvfs64` and confirm against the real headers before
writing the struct — do not reuse the macOS layout.

**iOS — NOT yet verified, likely needs a different call.** `statvfs` is
believed to *under*report on iOS because it ignores purgeable space;
Apple's guidance points at `NSURLVolumeAvailableCapacityForImportantUsageKey`
instead. Confirm against Apple's docs before shipping iOS rather than
assuming `statvfs` transfers from macOS.

**Windows.** `GetDiskFreeSpaceExW` returns free-bytes-available-to-caller
directly — no struct, no layout hazard.

**RAM per platform.** macOS/iOS `sysctlbyname("hw.memsize")`;
Linux/Android `MemTotal` from `/proc/meminfo` (plain file read — no FFI,
no struct, so prefer it over `sysinfo()`); Windows
`GlobalMemoryStatusEx`.

### Shape

```dart
/// Free bytes the app may still write.
/// Native: free space on the volume backing [forPath].
/// Web: the origin's remaining quota — the real ceiling, since the
/// browser refuses writes past it regardless of physical disk.
Future<Outcome<int>> freeStorageBytes({String? forPath});

/// Total physical RAM. `Unsupported` on web.
Outcome<int> totalRamBytes();
```

Storage is async (web's source is a Promise), RAM is sync. Both return
`Outcome` so web's RAM answer is a typed `Unsupported` rather than a lie.

Known consumer: `llm_weights` gates model downloads on free storage and
model-fit on RAM, and defines a `DeviceInfo` interface for an app to
implement. That adapter belongs in the **app**, never in either package —
see that package's own roadmap.

## Cross-cutting

| Capability | Status | Notes |
|---|---|---|
| Sealed `Outcome` with `Cancelled` + `PermissionDenied` | DONE | Stack traces captured on failures |
| Six-platform pub.dev attribution | DONE | pana-gated (`make platforms`); registration-only deps pattern |
| MIME lookups (curated + full database) | DONE | package:mime behind the curated maps; the curated maps themselves are virtual_file_store's (see `docs/UPDATING.md`) |
| App permission requesting | WONT_DO | Apps own their permission UX and Info.plist/manifest entries; this package surfaces denials as typed results |
| Paths or eager bytes on `PickedAsset` | WONT_DO | Design note in `picked_asset.dart` — paths don't exist on web; eager bytes OOM large files |

## Linking — `FileLinks`

| Capability | Status | Notes |
|---|---|---|
| Pick with keepable access | DONE | Own native pickers: SAF with `FLAG_GRANT_PERSISTABLE_URI_PERMISSION` (Android), in-place `UIDocumentPickerViewController` (iOS), `NSOpenPanel` (macOS); file_picker paths on Linux / Windows; the asset picker's blobs on web |
| `LinkStrength` verdict per candidate | DONE | Measured natively — `fstat` `S_ISREG` on Android, `isRegularFile` + iCloud status on Darwin — never inferred from a name |
| `link` / `unlink` — durable in place | DONE | Grant on Android, bookmark on Darwin, the path on desktop; `LinkNotDurable` for a `session` / `none` candidate |
| The grant budget | DONE | `budget()` reads `getPersistedUriPermissions`; `link` refuses `LinkBudgetFull` at cap − 8 (128, or 512 from Android 11); uncounted elsewhere |
| Folder links + `children` | DONE | One grant / bookmark for every child; a child's `link` takes nothing more; non-recursive, extension-filtered, sorted |
| `open` → `FileHandle` | DONE | `FileDescriptorHandle` (Android, detached fd) or `FilePathHandle` (Darwin inside a held scope; desktop paths); `close` releases once |
| Typed refusals on open | DONE | `LinkTargetMissing`, `LinkNotDownloaded(startDownload)`, `LinkPermissionGone`; every native code mapped in one place |
| The copy path from the same pick | DONE | `LinkCandidate.readStream` — `/proc/self/fd` on Android, a scoped path on Darwin, the file on desktop, the blob on web |
| Web | DONE | Every candidate `none`; `link` / `open` / folders are typed refusals — the browser keeps no durable handle |
| Eviction of least-recently-used grants at a full budget | WONT_DO | A package must never silently take access away from a consumer's rows; refuse and say so. Folder links are the answer to "many files" |
| Persisted File System Access handles on web | PLANNED | Chromium can keep `FileSystemFileHandle`s in IndexedDB with a permission re-prompt; nothing here yet |

## Folder IO — `FolderIo`

| Capability | Status | Notes |
|---|---|---|
| `read` — bytes at a relative path, null when absent | DONE | Never a refusal for a missing object |
| `write` — atomic, creating parent directories | DONE | Bytes land at a temporary sibling name in the same directory, then a rename puts them at the real path; a reader never observes a partial write |
| `list` — every object under a prefix, recursive, sorted | DONE | `''` lists everything under the folder |
| `delete` — a missing object is a `Success`, not an error | DONE | |
| The relative-path refusal | DONE | A leading `/` or a `..` segment is a typed `Failed`, never a traversal |
| `path:` / `bookmark:` folder tokens | DONE | `dart:io` directly for a path; a bookmark opens the FOLDER itself (no `relative`) through the same channel `open` a file uses, held for exactly the one call |
| `folder-tree:` (Android) | WONT_DO (for now) | A tree grant's write side is Storage Access Framework document creation, not a filesystem path — no channel for it yet. Revisit if a consumer needs writable Android folder shelves |
| Web | DONE | `Unsupported` for every method — no folder grant a `FolderRef` could have come from |

## Infrastructure

| Capability | Status | Notes |
|---|---|---|
| Strict lints + zero-issue analyzer | DONE | |
| Makefile gates (format / analyze / analyze-floor / platforms) | DONE | |
| Test suite (mirror VM suites · runtime layer · grammar battery · real-Chrome quarantine) | DONE | Chartered behavioral tests; recording fakes at platform-interface seams; the runtime/resolve layer pinned in `test/runtime/`; the cross-adapter `Outcome` grammar as one spec in `test/batteries/`; browser charters under `test/platform/web/`; mechanical guards (`make test-guards`). Shape in `ARCHITECTURE.md` §8 |
| Example app | DONE | Six platforms, one exhaustive `Outcome` renderer, lazy reads on tap; host journeys cover all four tabs (pick / share / save / open + cross-tab plumb); the integration smoke proves real filesystem effects on-device |
| CI via the shared workflow repo | DONE | First consumer of `whuppi/ci` (born on v1.0.0; pinned per-workflow and bumped by grouped Dependabot PRs — currently v2.0.5). Thin caller stubs over the reusable workflows; fast PR gate in `ci.yml` (format/analyze/floor/platforms/guards/unit/web via `make-target`); label-triggered cross-target matrix in `full-test.yml` (package × OS, host journeys, real-device integration smokes, release verify); release via the reusable gate → discover → publish workflow (no binaries). Shared-CI upgrades arrive as grouped Dependabot PRs, tested by that PR's own CI |
| Published to pub.dev | DONE | `1.0.0` stable live under the verified publisher (whuppi.com); 160/160 pana; two-lane changelogs drive the release train (prerelease from dev, stable from prod, env-gated publish approval) |
| pub.dev listing | DONE | Novice-first description (≤180 chars, scored range), five searched topics, README banner (light/dark `<picture>`, flattened to `<img>` in the published tarball) |
