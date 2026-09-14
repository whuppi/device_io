# Changelog — prerelease lane

<!--
═══════════════════════════════════════════════════════════════════════
CHANGELOG STANDARD — read before editing. Applies to both changelogs.
═══════════════════════════════════════════════════════════════════════
Two INDEPENDENT lane changelogs — do NOT mirror one from the other:
  • CHANGELOG.pre.md — the prerelease lane (`## X.Y.Z-dev.N`). Add an
    entry per prerelease you cut on dev.
  • CHANGELOG.md — the stable lane (`## X.Y.Z`). Add an entry per stable
    release, CONSOLIDATING the prerelease entries that ship under it.
They share prose but track their OWN version sequences. There is no
`cp + sed` regen: that mirror falsely assumed every prerelease becomes a
same-numbered stable, so it manufactured stable headings for versions
that never shipped — which the release tooling's `--check-versions` flags.
Hand-edit each lane's file directly.

ADDING A VERSION
  Add a heading at the TOP (newest first) of the right lane's file and
  write the summary. Exactly ONE new (untagged) version may sit at the
  top of each file — every heading BELOW it must already have its git tag
  (or a verified `release: no-tag` HTML-comment directive). `--check-versions`
  enforces this at PR + release time: a second un-released version is
  rejected, since it would collapse into the one release the merge cuts.
  Versions, commit lists, tags, publishing — the release tooling owns all
  of it; you only write the human summary.

ENTRY SHAPE
  ## X.Y.Z-dev.0
  <one-line prose lead — only to frame a big release or signal "no
   behavior change"; omit when the bullets speak for themselves>
  - **Breaking:** <what changed> → <migration step, INLINE>   ← always first
  - <upgrade action>                                          ← any required action next
  - Added/Changed <capability or improvement>                ← then improvements
  - Fixed <bug> ([#N](issue-url) reported by [@user](abs-url), [PR #N](abs-url))  ← fixes last

  Order IS the grouping — Breaking → action → added/changed → fixed. No
  `###` subsections: bullet order carries the categories. Only Breaking
  is bold-tagged; everything else is verb-led. Fixes start with "Fixed".

  EXCEPTION — the genesis entry (a ground-up build, no prior published
  version) uses facet tags instead of deltas: **API:** / **Safety:** /
  etc., describing the new package's dimensions.

CONTENT RULES (never change)
  • Migrate from the entry ALONE — breaking changes inline, old → new.
    (pub.dev freezes each version's CHANGELOG as a snapshot, so an entry
    can't rely on anything that later moves.)
  • NEVER link a living doc (README, docs/*) from an entry — it rots when
    the doc moves on.
  • Links point only at IMMUTABLE targets — a PR, commit, or issue:
    ([#N](https://github.com/whuppi/device_io/issues/N) reported by
    [@user](https://github.com/user), [PR #N](https://github.com/whuppi/device_io/pull/N)).
    Credit the issue + reporter when a reported issue drove the fix; the PR
    (or commit) link alone otherwise.
  • No capability inventories — "what's shipped" lives in README +
    docs/CAPABILITY_ROADMAP.md; the changelog says only what CHANGED.
═══════════════════════════════════════════════════════════════════════
-->

<!-- Add new versions below, newest first. -->

## 3.0.0-dev.0

- **Breaking:** `DeviceIO.custom` gains a required `folders` → pass `NativeFolderIo()` / `WebFolderIo()` (or a custom implementation) alongside the other capabilities. Adds `DeviceIO.folders` (`FolderIo`): read / write / list / delete objects inside a folder `links` already linked, by a forward-slash relative path; writes are atomic on most platforms (bytes land at a temporary sibling name, then a rename puts them at the real path); a missing object is a plain `Success` on both `read` and `delete`. A `path:` folder token reads `dart:io` directly; a `bookmark:` token (Apple) opens the FOLDER itself — the same channel `open` a file uses, with no `relative` — inside a security scope held for exactly the one call; a `folder-tree:` token (Android) resolves the relative path through four dedicated channel methods (`folderRead` / `folderWrite` / `folderList` / `folderDelete`), one Storage Access Framework document lookup per segment, and its write is not atomic like the other worlds — the provider has no rename-over, so a crash between deleting the old object and renaming the new one into place can briefly leave it absent (never torn). `pickFolder` now persists a tree grant's write half alongside its read half (a single file's own grant stays read-only); a grant taken before this change fails a `folder-tree:` write with `PermissionDenied` rather than silently re-prompting. `Unsupported` only on the web, where folders carry no grant at all.
- Added `DeviceIO.links` — the fifth capability, `FileLinks`: keep a person's file where it is instead of copying it. Its own picker asks the platform for access it can KEEP (a persistable Storage Access Framework grant on Android, an in-place document URL plus bookmark on iOS / macOS, a path on Linux / Windows); every pick comes back as a `LinkCandidate` with a `LinkStrength` verdict measured natively (a cloud provider's pipe is `none`, never guessed from a name) and both ways forward — `link` for the durable ones, `readStream` to copy the rest. `open` hands back a `FilePathHandle` or a `FileDescriptorHandle`, with `LinkTargetMissing` / `LinkNotDownloaded(startDownload)` / `LinkPermissionGone` as typed refusals; `pickFolder` + `children` make one grant cover a whole folder; `budget()` reads Android's grant ledger and `link` refuses `LinkBudgetFull` at the cap's reserve. The web answers honestly: every candidate is copy-only. This makes device_io a plugin package (Kotlin + one shared Swift source); `DeviceIO.custom` gains a required `links`
- Added `FileLinks.candidateForPath(path)` — a file the app can already name (one it saved itself, one a path-based picker handed over) as a candidate carrying the same verdict a pick would; `LinkTargetMissing` when nothing is there, `Unsupported` on the web. The example's integration lane proves the real bookmark mint / resolve / scope on macOS and iOS through it
- `FileLinks.children` gained `recursive`: every file under a linked folder, each carrying its new `LinkCandidate.relativeDirectory` (the path under the folder, `/`-joined, empty at the top) — so a folder laid out one model per subfolder groups by directory. Apple walks with one enumerator, Android walks the tree's document ids, desktop lists recursively; the non-recursive default is unchanged.
- Changed the copy path's refusals: `LinkCandidate.readStream` now fails with a `LinkReadError` carrying the typed refusal (`LinkTargetMissing` / `LinkNotDownloaded` / `LinkPermissionGone`) instead of a raw platform exception
- Apple picks are `durable` only when the system minted a bookmark for them; a sandboxed app without `com.apple.security.files.bookmarks.app-scope` now gets a `session` candidate (copy) instead of a link whose id was a bare URL and could never be reopened. README names the entitlement
- Changed `mimeToExtension` / `extensionToMime` (`lib/src/types/mime_types.dart`) to re-export the curated MIME↔extension table from the new `virtual_file_store` path dependency instead of carrying a duplicate; `mimeTypeFromFileName` / `extensionFromMimeType` are unchanged in name, signature, and behavior
- Fixed the Apple copy path for a pick the system could not bookmark: the plain URL the picker granted for this launch is now opened as a session id, so copying a `session` candidate works instead of failing as `missing`

## 2.0.0-dev.0

- **Breaking:** the result family is renamed — `PlatformResult` → `Outcome`,
  `PlatformSuccess` → `Success`, `PlatformCancelled` → `Cancelled`,
  `PlatformUnsupported` → `Unsupported`, `PlatformFailure` → `Failed`,
  `PlatformPermissionDenied` → `PermissionDenied`. Migration is a mechanical
  find-and-replace of those six names; fields, semantics, and the sealed
  hierarchy (PermissionDenied still subtypes Failed) are unchanged.
- Added `AssetPicker.pickDirectory` — a directory chooser on the five native
  platforms; `Unsupported` on web.
- Added `FileSaver.saveInto` — silent save into a caller-chosen directory
  (pairs with `pickDirectory` for pick-once-save-many), with the same
  name-sanitizing and no-clobber guarantees as `save`; `Unsupported` on web.
- Added `FileOpener.open(SaveLocation)` — opens what a save returned without
  destructuring: `SavedAtPath` opens at its path, `SavedByBrowser` returns
  `Unsupported`.

## 1.0.0-dev.0

First prerelease — cross-platform device IO for Flutter: pick, share,
save, open. One API on iOS, Android, macOS, Windows, Linux, and web.
