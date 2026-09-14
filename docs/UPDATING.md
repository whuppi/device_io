# Updating device_io

Maintenance recipes. For architecture see
[`ARCHITECTURE.md`](ARCHITECTURE.md). For capability status see
[`CAPABILITY_ROADMAP.md`](CAPABILITY_ROADMAP.md).

---

## The pinned-protocol watchlist

This package leans on behaviors of its plugins that are NOT part of their
semver-stable Dart API. Every dependency bump re-verifies the affected
rows against the NEW version's source (read the source in the pub cache —
never trust memory or docs):

| Pinned behavior | Where it's relied on | Verified against | Re-verify when |
|---|---|---|---|
| open_filex method channel: name `open_file`, method `open_file`, args `{file_path, type, uti}`, JSON result `{type, message}`, codes 0/-1/-2/-3/-4 | `opener/native/` `_openMobile` | open_filex 4.7.0 | any open_filex bump |
| `FilePicker.saveFile` writes bytes on mobile (SAF/Files export) AND desktop (dialog then write) | `saver/native/` `saveAs` | file_picker 11.0.2 | any file_picker bump |
| image_picker permission error codes: `camera_access_denied`, `camera_access_restricted`, `photo_access_denied`, `photo_access_restricted` | picker `_permissionCodes` | image_picker platform impls (iOS + Android source) | any image_picker bump |
| Desktop image_picker impls throw `StateError` on `ImageSource.camera` unless a `cameraDelegate` is set (shared `CameraDelegatingImagePickerPlatform` base) | picker `isCameraSupported` gate | image_picker_platform_interface 2.11.1, `image_picker_platform.dart` | any image_picker / platform_interface bump — if desktop capture lands upstream, widen the gate |
| Web camera capture = the `<input capture>` attribute (`computeCaptureAttribute` → `setAttribute('capture', …)`); a hint mobile browsers honor and desktop browsers IGNORE (silently degrading to a plain file picker) | picker `isCameraSupported` gate refuses desktop before the plugin can fake it | image_picker_for_web 3.1.1, `image_picker_for_web.dart` | any image_picker_for_web bump |
| `SharePlus` is a thin delegator over `SharePlatform.instance`; desktop impls register via `registerWith` from the dependency alone | `sharing/native/` uses the platform interface | share_plus 12.0.2 | any share_plus bump |
| share_plus barrel poisons desktop pana attribution (url_launcher_linux/windows imports) | pubspec registration-only comment | share_plus 12.0.2 | re-check on bump — if fixed upstream, the interface import can revert to the barrel |
| open_filex declares only android + ios | pubspec registration-only comment | open_filex 4.7.0 | re-check on bump — if desktop platforms get declared, the channel-direct call can revert to the plugin API |

`make platforms` catches attribution regressions mechanically; the rest
of the table needs the source check.

Platform entitlements consumers must declare (verified via the example's
macOS integration smoke): silent `save` into `~/Downloads` needs
`com.apple.security.files.downloads.read-write`; `saveAs` and picking need
`com.apple.security.files.user-selected.read-write`. Without the Downloads
entitlement a sandboxed macOS app gets `Failed` from `save`
— the package surfaces it correctly, but the README's Install section is
the fix. iOS needs the three usage-description keys.

## Upgrading a dependency

1. Read the changelog between the current and target versions (pub cache:
   `~/.pub-cache/hosted/pub.dev/<pkg>-<version>/CHANGELOG.md`). Migrate
   breaking changes; note anything newly useful.
2. Re-verify every watchlist row for that package against the new source.
3. Known ceiling: share_plus 13.x requires `win32 ^6` while every stable
   file_picker (<12.0.0-beta) requires `win32 ^5` — bump the pair
   together when file_picker 12 leaves beta. `test` is capped by
   flutter_test's `test_api` pin; it moves with Flutter bumps.
4. `make check`.

## Adding a MIME type / extension mapping

The curated MIME↔extension table (`mimeToExtension` / `extensionToMime`,
re-exported by `lib/src/types/mime_types.dart`) lives in `virtual_file_store`, not
here — it's the workspace's one canonical copy, shared with pure-Dart code
that cannot depend on this Flutter plugin package. Add the entry in
`virtual_file_store/lib/src/mime/mime_types.dart` (see `virtual_file_store/docs/UPDATING.md`),
then add the extension to this package's category sets
([imageExtensions], [audioExtensions], etc. — still local, for UI icon
selection) if it belongs to one.

## Adding a method to an existing capability

1. Add it to the contract (`<concern>/<contract>.dart`) with the
   platform-behavior doc and, when the shape is new, a ```dart example.
2. Implement in BOTH `native/` and `web/` impls (or in the single picker
   impl). A platform that genuinely can't → `Unsupported` with
   the evidence verified first (plugin source / platform spec), never
   assumed.
3. Follow the error physics: catch `(e, st)`, rethrow `Error`s, capture
   `stackTrace`, map known permission codes.
4. Any filesystem write goes through `runtime/native/fs.dart` helpers.
5. Battery + runners cover it (VM + Chrome where reachable).
6. Update `CAPABILITY_ROADMAP.md` row and the changelog lane.

## Adding a new capability concern (fifth capability)

1. New folder `lib/src/<concern>/` with `<contract>.dart` +
   `native/` + `web/` impls — UNLESS the backing plugins are already
   federated and the impls would only diverge in `kIsWeb`-sized branches;
   then one platform-neutral impl (the picker precedent, see
   `ARCHITECTURE.md` §4).
2. Field on `DeviceIO` (runtime/device_io.dart) + wire all three resolve
   files (`_native`, `_web`, `_stub` — signatures stay identical).
3. Export the contract from the barrel's sectioned exports.
4. New knobs go on `DeviceIOConfig`, never as loose constructor parameters.
5. Run `make platforms` — a new dependency can silently drop platforms
   (check its pubspec `flutter.plugin.platforms` and its barrel's
   imports BEFORE importing it; the registration-only pattern exists for
   plugins that poison the walk).
6. Roadmap section + changelog entry.

## Adding a method to the links channel

The links door has three halves and one contract. A new method touches:

1. `lib/src/links/links_channel.dart` — the typed Dart call, its payload
   keys, and the error codes it may raise, in the class doc.
2. `android/src/main/kotlin/com/whuppi/device_io/DeviceIoPlugin.kt` —
   the `when (call.method)` arm. Map every exception to one of the
   documented codes; never let a raw Kotlin message become the contract.
3. `darwin/device_io/Sources/device_io/DeviceIoPlugin.swift` — the
   `switch call.method` case, same codes.
4. `lib/src/links/native/file_links.dart` — the world that uses it, and
   the `_failure` mapping if a new code appears.
5. `test/links/native_file_links_android_test.dart` — script the fake
   channel (`_Channel`) for the new method; the paths and web worlds have
   their own suites.

## Adding a method to `FolderIo`

`FolderIo`'s `path:` and `bookmark:` worlds open NO channel calls of
their own beyond what the folder token already means: a `path:` token
reads `dart:io` directly, and a `bookmark:` token is opened at the
FOLDER itself through the SAME `LinksChannel.open` a file's `open` uses
(no `relative`). The `folder-tree:` world (Android) has no local root at
all — every call crosses the channel, and the Kotlin side resolves the
relative path through Storage Access Framework document lookups — so a
new method on this door usually DOES touch Kotlin, unless it can be
built entirely from a resolved local root.

1. `lib/src/links/folder_io.dart` — the contract method, with the
   relative-path validation it inherits (`_validate`'s two rules: no
   leading `/`, no `..` segment) named in the doc comment. Name the
   platform difference (atomic on `path:`/`bookmark:`, not on
   `folder-tree:`) if the method writes.
2. `lib/src/links/native/folder_io.dart` — implement inside `_dispatch`'s
   `onRoot` callback for the `path:`/`bookmark:` worlds; implement inside
   `onTree` for Android, calling the matching `LinksChannel` method.
3. `lib/src/links/web/folder_io.dart` — `Unsupported`; there is no
   folder-grant world on the web to add a real implementation to.
4. If the method needs a channel call Android doesn't already serve
   (`folderRead` / `folderWrite` / `folderList` / `folderDelete`), that
   IS a new channel method — follow "Adding a method to the links
   channel" above instead, and only then wire it into `onTree`.
5. `test/links/native_folder_io_paths_test.dart` covers the `path:`
   world against real temp-directory files; `native_folder_io_darwin_test.dart`
   scripts the same `_Channel` fake as the file-links darwin suite,
   asserting `opens`/`closes` stay paired for the new method too;
   `native_folder_io_android_test.dart` scripts a channel fake asserting
   the method name and the `tree` / relative-path arguments crossed
   correctly, plus that the path refusal never reaches the channel;
   `web_folder_io_test.dart` asserts the `Unsupported`.

## Releasing

Versions, tags, and publishing belong to the reusable `whuppi/ci` release
workflow (`.github/workflows/release.yml` calls it): `version: 0.0.0` in
pubspec and `lib/src/version.dart` are placeholders stamped at publish time
from the changelog's top untagged heading. You only write the changelog
summary — one untagged version max per lane file.

The pipeline itself — gate → discover → publish across the two changelog lanes
(`CHANGELOG.pre.md` for dev/prereleases, `CHANGELOG.md` for prod/stable), and
the GitHub environment approval that gates every pub.dev push — is the shared
engine; see whuppi/ci/docs/ARCHITECTURE.md "The release surface".
