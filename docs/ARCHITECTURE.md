# device_io — Architecture

> **Type:** architecture · **Scope:** device_io · **Status:** SHIPPED (test suite being rebuilt) · **Last verified:** 2026-07-02
> **Companion docs:** [`CAPABILITY_ROADMAP.md`](CAPABILITY_ROADMAP.md) (status per capability) · [`UPDATING.md`](UPDATING.md) (maintenance recipes)

What the package IS: the current shipped shape of every layer. When this
doc and the code disagree, the code wins — then fix this doc.

---

## 1. The contract

device_io gives a Flutter app four device capabilities through one API
that is identical on iOS, Android, macOS, Windows, Linux, and web:

- **Pick** — images (gallery/camera) and generic files, single or multi.
- **Share** — text, files, byte streams via the OS share sheet / Web Share.
- **Save** — silently to the downloads area, or through the system save
  dialog (`saveAs`).
- **Open** — bytes or a saved path in the platform's default viewer.

The load-bearing promises:

1. **Consumers never branch on platform.** All platform handling lives
   inside this package. Where something is truly impossible on a
   platform, the app receives a typed `PlatformUnsupported` value — not
   an exception, not a crash, not a need for `kIsWeb` in app code.
2. **Every outcome is a named value.** Operations return the sealed
   `PlatformResult<T>`: `Supported(value)` / `Cancelled` /
   `Unsupported(reason)` / `Failed(message, error, stackTrace)`, with
   `PermissionDenied` as a `Failed` subtype (generic handling stays one
   `switch` arm; settings-prompt handling can match it specifically).
   User dismissals are `Cancelled` — never null, never an error.
3. **Throws are for bugs only.** Adapters catch expected failures into
   `Failed` (capturing the stack trace) and rethrow `Error`s so
   programmer mistakes crash loudly instead of becoming failure toasts.
4. **Every `Unsupported` claim is evidence-backed.** Each one was
   verified against plugin sources / platform APIs — not assumed.
5. **Filesystem writes are browser-grade safe.** Caller-supplied names
   are sanitized (separators, traversal, control chars, Windows reserved
   device names); saves never clobber (atomic numbered variants); stream
   saves are `.part`-then-rename so failures leave nothing behind.

---

## 2. The file tree

Alpha-sorted as the IDE shows it; the order is the reading order.

```
lib/
  device_io.dart               ← barrel: sectioned exports, quick-start doc
  src/
    _shared/
      native_fs.dart           ← dart:io helpers: sanitize / reserve / stage
    download/
      download_adapter.dart    ← contract: saveToDevice / saveStream / saveAs
      native/  web/            ← dart:io impl · blob + File System Access impl
    opener/
      file_opener_adapter.dart ← contract: openBytes / openPath
      native/  web/            ← OS-open + open_filex channel · blob-tab impl
    picker/
      asset_picker_adapter.dart          ← contract: pick/capture, single+multi
      picked_asset.dart                  ← lazy value type (no paths, no bytes)
      plugin_asset_picker_adapter.dart   ← ONE impl, all platforms (§4)
      web_file_pick.dart + _stub/_web    ← FSA lazy-pick seam, STUB DEFAULT (§3)
    runtime/
      device_io.dart           ← the DeviceIO container (four adapter fields)
      init_device_io.dart      ← conditional export — STUB IS THE DEFAULT (§3)
      init_device_io_native.dart / _stub.dart / _web.dart
    sharing/
      sharing_adapter.dart     ← contract: shareText / shareFile / shareFileStream
      native/  web/            ← share_plus interface impl · Web Share impl
    types/
      device_io_config.dart    ← DeviceIOConfig for initDeviceIO
      mime_types.dart          ← curated maps + package:mime-backed lookups
      platform_result.dart     ← the sealed result family
    version.dart               ← 0.0.0 placeholder, stamped at release
```

---

## 3. The platform seam — three tools, each for one situation

| Situation | Tool | Where |
|---|---|---|
| Code cannot compile cross-platform | Conditional import, **stub as default** | `runtime/init_device_io.dart`, `picker/web_file_pick.dart` |
| Compiles everywhere, behavior differs | `kIsWeb` const branch (tree-shaken) | picker's file-pick path |
| Browser capability varies at runtime | Feature detection, graceful ladder | web `saveAs` (File System Access → download), Web Share (`hasProperty` → `canShare`) |

The stub-default is load-bearing: pub.dev's analyzer attributes to every
platform whatever the DEFAULT conditional target imports. A `dart:io`
default silently drops web. `make platforms` (pana) guards this.

---

## 4. The real-matrix rule

`native/` + `web/` adapter pairs exist ONLY where platform APIs genuinely
bind: download, opener, and sharing import `dart:io` on one side and
`package:web` on the other. The picker has **one** implementation for all
platforms — the underlying image_picker / file_picker plugins are already
federated, and its two true divergences (camera capture support, web file
picks having no lazy handle) are `kIsWeb`/`defaultTargetPlatform`
branches, not file splits. A per-platform pair there would be a fake
matrix: two near-identical copies.

---

## 5. Error physics

```
plugin / OS / browser throws
        │
        ▼
adapter catch (e, st)
        ├── e is Error?            → rethrow (programmer bug, crash loudly)
        ├── known permission code? → PlatformPermissionDenied(error: e, stackTrace: st)
        └── otherwise              → PlatformFailed(message, error: e, stackTrace: st)
```

- Permission mapping matches image_picker's EXACT error codes (verified
  against the iOS + Android plugin sources); unknown codes stay generic
  failures — an explicit contract, not a guess.
- Web Share support is feature-detected before calling; rejected share
  promises are classified by DOMException *name* (spec constant), matched
  on the string form because typed JS-interop `is` checks are not
  consistent across dart2js/wasm.
- Share sheet dismissal (`ShareResultStatus.dismissed`, web `AbortError`)
  and picker dismissal map to `Cancelled`.

---

## 6. Filesystem safety (`_shared/native_fs.dart`)

| Helper | Guarantee |
|---|---|
| `sanitizeFileName` | No separators/traversal/control chars; Windows-forbidden chars and reserved device names (CON, NUL, COM1…) neutralized; 200-char cap keeping the extension; empty → `file`. |
| `reserveFreshFile` | Atomic `File.create(exclusive: true)` numbering (`report (1).pdf`) — concurrent same-name saves can't collide; bounded loop with timestamped fallback. |
| `stageFile` | Unique `createTemp` dir under the OS cache per staging; real fileName preserved for share sheets/viewers; never eagerly deleted (receivers read after the call returns; the OS reclaims cache). |

Stream saves write to a `.part` sibling and rename over the reserved
placeholder on success — a failed stream leaves nothing behind.

---

## 7. The pana attribution seams

Two dependencies are **registration-only** — declared in pubspec (which
is what wires their native code via the generated plugin registrant) but
never imported:

| Dependency | Why its Dart is not imported | How it's reached |
|---|---|---|
| `share_plus` | Its barrel unconditionally exports desktop impls pinning `url_launcher_linux` / `url_launcher_windows` (single-platform packages) — importing it drops every desktop platform from pana's walk | `share_plus_platform_interface` → `SharePlatform.instance` |
| `open_filex` | Declares only android + ios | Its method channel (`open_file`), protocol pinned against the 4.7.0 source |

`make platforms` fails if either regresses.

---

## 8. Test architecture (suite being rebuilt)

Three mappings, mirroring the reference package pattern:

1. **Mirror** — pure logic tests mirror `lib/src/` one concern per file
   (`test/types/`, `test/_shared/`, `test/picker/`, …).
2. **Batteries × runners** — adapter-contract behavior is written once as
   a platform-agnostic battery and instantiated by a VM runner (native
   adapters + fake `path_provider`) and a Chrome runner (`-p chrome`,
   real blob / feature-detection paths).
3. **Harness** — `Timeout.factor`-based timeouts (CI's `--timeout=30x`
   scales; local stays tight), plugin fakes; the harness is itself
   tested.

No fixture generator: nothing format-shaped is under test — inline const
byte fixtures suffice.

---

## 9. The one-line summary

> **Four capabilities, one sealed result family, zero platform branches
> for consumers. Seams: stub-default conditional import, kIsWeb only
> where the matrix would be fake, runtime feature-detection ladders on
> web. Throws are bugs; everything else is a named value carrying its
> evidence. Filesystem writes behave like a browser's. pana guards the
> six-platform claim.**
