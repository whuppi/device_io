# Contributing

## Setup

```bash
git clone https://github.com/whuppi/device_io.git
cd device_io
make hooks               # activates commit-msg + pre-commit (run once)
fvm install              # downloads the SDK version pinned in .fvmrc
fvm flutter pub get
```

**Requires:** [FVM](https://fvm.app) (`.fvmrc` pins the exact Flutter
version). No native toolchains — this package wraps federated plugins;
their platform code builds inside consumer apps.

**Without FVM:** all Makefile commands accept `DART` and `FLUTTER`
overrides:

```bash
make check DART=dart FLUTTER=flutter
```

## Before submitting a PR

```bash
make check
```

Runs `format` (check mode) + `analyze` (strict lints) + `analyze-floor`
(the OLDEST in-range dependencies must still analyze clean — the lower
bounds in pubspec are promises) + `platforms` (pana must attribute all
six platforms) + `test`. Must pass. Don't suppress with `// ignore:` —
fix the underlying issue.

## PR workflow

All PRs target `dev`. That's the only branch contributors touch.

```
your fork / feature branch ──PR──► dev
                                    ↓ CI: the same make targets as local
                                    ↓ PR title: Conventional Commits (feat: / fix: / etc.)
                                    ↓ squash-merge when green
```

You don't write changelog entries, bump versions, or touch `prod`.
The maintainer handles releases.

## Code style

- Match existing code in the repo.
- **Expected failures are values, never throws.** Every adapter method
  returns `PlatformResult` — `Supported` / `Cancelled` / `Unsupported` /
  `Failed` (+ `PermissionDenied`). Catches capture the stack trace into
  the result and rethrow `Error`s so programmer bugs crash loudly.
- **The stub-default conditional import in `lib/src/runtime/` is
  load-bearing.** The default target is what pub.dev's analyzer
  attributes to every platform; a `dart:io` default silently drops web.
  `make platforms` guards it.
- **Registration-only dependencies stay unimported.** `share_plus` is
  reached through its platform interface and `open_filex` through its
  method channel — importing either package's Dart barrel drops desktop
  platforms from pub.dev attribution (their internals pin
  single-platform packages). The pubspec comments carry the reasoning;
  `make platforms` fails if this regresses.
- **No `dart:io` outside `lib/src/_shared/` and the `native/` adapter
  folders.** Shared interfaces and types stay platform-neutral.
- **Every impossibility claim needs evidence.** A `PlatformUnsupported`
  return must be backed by verified platform/plugin behavior, not
  convenience — check the claim against the plugin sources before
  writing it.
- Tests mirror `lib/src/`; platform-variant behavior is written once as
  a battery and instantiated by a VM runner and a Chrome runner (see the
  test-architecture section in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)).

## Adding a capability

Step-by-step checklists in [`docs/UPDATING.md`](docs/UPDATING.md).
