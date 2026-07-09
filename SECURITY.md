# Security Policy

## Reporting a vulnerability

Report privately via [GitHub Security Advisories](https://github.com/whuppi/device_io/security/advisories/new). Do not open a public issue.

## What's in scope

- **Path escapes** — a file name that gets a save, share staging, or open staging write OUTSIDE its intended directory despite `sanitizeFileName` (traversal sequences, encoding tricks, platform-specific separators).
- **Overwrites of user files** — anything that defeats the atomic no-clobber reservation and silently replaces an existing file in Downloads.
- **Staged-file exposure** — shared/opened files are staged under the OS cache directory; anything that lands them somewhere world-readable beyond that, or leaks them across app sandboxes.
- **Web isolation escapes** — blob URLs or File System Access handles reaching content they shouldn't.

## What's NOT in scope

- **Vulnerabilities in the underlying plugins** not caused by how this package drives them — report upstream: [image_picker / path_provider](https://github.com/flutter/packages/issues), [file_picker](https://github.com/miguelpruivo/flutter_file_picker/issues), [share_plus](https://github.com/fluttercommunity/plus_plugins/issues), [open_filex](https://github.com/crazecoder/open_file/issues).
- **Content of picked/saved/shared files** — bytes pass through untouched by design. Validating or scanning content is the app's job.
- **Permission-denied outcomes** — surfaced as typed results (`PermissionDenied`), not vulnerabilities.
- **Browser-imposed limits** — popup blockers, user-gesture requirements for share/save dialogs. The package degrades gracefully; the limits are the platform working as intended.
- **Crashes from unusual file names or byte streams** — bugs, not vulnerabilities. Report them as [regular issues](https://github.com/whuppi/device_io/issues).

## Operational notes (known, accepted)

These are conscious trade-offs, documented so they aren't mistaken for oversights:

- **Staged files are not eagerly deleted.** Share targets and file viewers may read a staged file long after the triggering call returns (on Android the share future resolves when the sheet closes, before the receiver reads the content URI). Staging dirs live under the OS cache directory, which Android and iOS reclaim automatically; eager deletion would hand receivers dead files.
- **open_filex is driven through its method channel directly**, with the protocol pinned against its 4.7.0 source (the plugin declares only android + ios, so importing its Dart API would drop desktop platform attribution on pub.dev). A protocol change in a future open_filex version surfaces as a runtime failure on mobile file-opens, not a compile error — dependency bumps re-verify the protocol (see `docs/UPDATING.md`).
- **`sanitizeFileName` is filesystem safety, not content validation.** It makes names safe to place in a path; it does not inspect bytes, extensions vs content mismatches, or double extensions.

## Response

Valid reports are fixed and shipped as patch versions.
