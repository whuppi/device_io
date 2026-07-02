# Changelog

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
that never shipped — which the release tooling's --check-versions flags.
Hand-edit each lane's file directly.

ADDING A VERSION
  Add a heading at the TOP (newest first) of the right lane's file and
  write the summary. Exactly ONE new (untagged) version may sit at the
  top of each file — every heading BELOW it must already have its git tag
  (or a verified `release: no-tag` HTML-comment directive). --check-versions
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
  etc., describing the new package's dimensions. See the 1.0.0 entry.

CONTENT RULES (never change)
  • Migrate from the entry ALONE — breaking changes inline, old → new.
    (pub.dev freezes each version's CHANGELOG as a snapshot, so an entry
    can't rely on anything that later moves.)
  • NEVER link a living doc (README, docs/*) from an entry — it rots when
    the doc moves on. The migration guide is reached from the README.
  • Links point only at IMMUTABLE targets — a PR, commit, or issue:
    ([#N](https://github.com/whuppi/device_io/issues/N) reported by
    [@user](https://github.com/user), [PR #N](https://github.com/whuppi/device_io/pull/N)).
    Credit the issue + reporter when a reported issue drove the fix; the PR
    (or commit) link alone otherwise.
  • No capability inventories — "what's shipped" lives in README +
    docs/CAPABILITY_ROADMAP.md; the changelog says only what CHANGED.
═══════════════════════════════════════════════════════════════════════
-->

## 1.0.0

First public release — cross-platform device IO for Flutter: pick, share,
save, open. One API on iOS, Android, macOS, Windows, Linux, and web.

- **API:** four capability contracts (`AssetPickerAdapter`,
  `SharingAdapter`, `DownloadAdapter`, `FileOpenerAdapter`) behind one
  `DeviceIO` container built by `initDeviceIO`. Every operation returns a
  sealed `PlatformResult` — `Supported` / `Cancelled` / `Unsupported` /
  `Failed`, with `PermissionDenied` as a named failure subtype carrying
  the caught error and stack trace.
- **Picking:** single + multi image and file picks, camera capture on
  phones/tablets (native apps and mobile browsers), lazy `PickedAsset`
  reads — bytes or a fresh stream per call, nothing loaded until asked.
- **Saving:** silent saves with browser-grade filesystem safety (name
  sanitization incl. Windows reserved names, atomic no-clobber numbering,
  `.part`-then-rename stream writes), plus `saveAs` through the system
  save dialog on every platform (SAF / Files export / native dialog /
  File System Access with download fallback).
- **Sharing:** text, files, and byte streams via the OS share sheet and
  the Web Share API, with dismissals mapped to `Cancelled`.
- **Opening:** `openBytes` on every platform (staged file + OS viewer
  natively, blob URL in a new tab on web) and `openPath` for
  just-saved files.
- **Platforms:** pub.dev attributes all six platforms; the stub-default
  conditional import and the registration-only dependency pattern are
  guarded by a pana gate in CI.
