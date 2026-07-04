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
| `FilePicker.saveFile` writes bytes on mobile (SAF/Files export) AND desktop (dialog then write) | `download/native/` `saveAs` | file_picker 11.0.2 | any file_picker bump |
| image_picker permission error codes: `camera_access_denied`, `camera_access_restricted`, `photo_access_denied`, `photo_access_restricted` | picker `_permissionCodes` | image_picker platform impls (iOS + Android source) | any image_picker bump |
| `SharePlus` is a thin delegator over `SharePlatform.instance`; desktop impls register via `registerWith` from the dependency alone | `sharing/native/` uses the platform interface | share_plus 12.0.2 | any share_plus bump |
| share_plus barrel poisons desktop pana attribution (url_launcher_linux/windows imports) | pubspec registration-only comment | share_plus 12.0.2 | re-check on bump — if fixed upstream, the interface import can revert to the barrel |
| open_filex declares only android + ios | pubspec registration-only comment | open_filex 4.7.0 | re-check on bump — if desktop platforms get declared, the channel-direct call can revert to the plugin API |

`make platforms` catches attribution regressions mechanically; the rest
of the table needs the source check.

Platform entitlements consumers must declare (verified via the example's
macOS integration smoke): silent `save` into `~/Downloads` needs
`com.apple.security.files.downloads.read-write`; `saveAs` and picking need
`com.apple.security.files.user-selected.read-write`. Without the Downloads
entitlement a sandboxed macOS app gets `PlatformFailed` from `save`
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

## Adding a method to an existing capability

1. Add it to the contract (`<concern>/<contract>.dart`) with the
   platform-behavior doc and, when the shape is new, a ```dart example.
2. Implement in BOTH `native/` and `web/` impls (or in the single picker
   impl). A platform that genuinely can't → `PlatformUnsupported` with
   the evidence verified first (plugin source / platform spec), never
   assumed.
3. Follow the error physics: catch `(e, st)`, rethrow `Error`s, capture
   `stackTrace`, map known permission codes.
4. Any filesystem write goes through `_shared/native_fs.dart` helpers.
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

## Releasing

Versions, tags, and publishing belong to the reusable `whuppi/ci` release
workflow (`.github/workflows/release.yml` calls it): `version: 0.0.0` in
pubspec and `lib/src/version.dart` are placeholders stamped at publish time
from the changelog's top untagged heading. You only write the changelog
summary — one untagged version max per lane file.

Pushing a new top heading to a lane changelog on its branch triggers the
pipeline: **gate** (refuse a lane whose changelog adds >1 unreleased version)
→ **discover** (stamp the tag tree, create the GitHub release) → **publish**
(build the pub.dev changelog + README, `dart pub publish`). dev reacts to
`CHANGELOG.pre.md` (prereleases), prod to `CHANGELOG.md` (stable). Publish
waits on the branch-named GitHub environment approval, so a human gates every
pub.dev push.
