<!-- Generated file — do not edit by hand; changes here are overwritten. -->

# device_io

> Instructions for AI coding agents working in this repository — read by Codex, Cursor, Copilot, Aider, Devin, Junie, Gemini and any tool that follows the [agents.md](https://agents.md) convention. Everything an agent needs is in this repository: this file and `./docs/`.

---

## What this tool does

**device_io** is a cross-platform device IO package for Flutter — pick images and files, share via the OS sheet, save silently or through the system save dialog, open in the default viewer. One API on iOS, Android, macOS, Windows, Linux, and web: apps never branch on platform. Every operation returns a sealed `PlatformResult` — `Success` / `Cancelled` / `Unsupported` / `Failed`, with `PermissionDenied` as a named failure carrying the caught error and stack trace. Four capability contracts (`AssetPicker`, `Sharer`, `FileSaver`, `FileOpener`) sit behind one `DeviceIO` container, constructed synchronously via `DeviceIO()`. Reads are lazy (`PickedAsset` loads nothing until asked); filesystem writes are browser-grade safe (name sanitization, atomic no-clobber numbering, `.part`-then-rename stream writes). pub.dev attributes all six platforms, guarded by the pana platform gate (`make platforms`).

The architecture, design and reference docs for this code live in `./docs/`. They are the authority on how it is shaped.

---

## Build and test commands

Run these after every code change. A failing test or analyzer error means the task is not done: never silence it with `// ignore:`, `# noqa` or `--no-verify`; fix the cause.

```bash
# Setup (needs FVM — https://fvm.app; .fvmrc pins the Flutter version)
make hooks                      # activate git hooks (once after cloning)
fvm install
fvm flutter pub get
make check                      # format + analyze + analyze-floor + platforms + test-guards + test + example journeys

# Without FVM (override SDK commands)
make check DART=dart FLUTTER=flutter

# Individual targets
make analyze                    # static analysis, strict lints
make platforms                  # pana gate — all six platforms must stay attributed
make test-unit                  # pure-logic + native-adapter suites (VM)
make test-web                   # web adapter suites in real Chrome
make test-example-matrix        # example UI journeys across a device-profile matrix
make test-example-macos         # example integration smoke on macOS (real plugins)
```

---

## Code style

- Match the existing code in this repository first: naming, comment density, file layout, idiom.
- A comment explains only what the code cannot say: an invariant, a constraint, a surprising choice that matters, a foot-gun. Never history, dates, doc section numbers, or the code restated in English.
- A rename sweeps every reference in one pass — code, docs, comments, tests, configs — until a search for the old name finds nothing.
- No `TODO` in place of a fix, no empty methods, no placeholder comments.

---

## Tool-specific notes

**The stub-default conditional import is load-bearing.** `lib/src/runtime/resolve.dart` (and `lib/src/picker/web_file_pick.dart`) default to the STUB target: pub.dev attributes to every platform whatever the DEFAULT conditional import pulls in, so a `dart:io` default silently drops web. `make platforms` guards it.

**Two dependencies are registration-only — never import their Dart.** `share_plus` is reached through `share_plus_platform_interface`, and `open_filex` through its method channel — importing either package's own barrel drops desktop platforms from pub.dev attribution (their internals pin single-platform packages). The pubspec comments carry the reasoning; `make platforms` fails if this regresses.

**Expected failures are values, never throws.** Adapters return `PlatformResult`, capture stack traces into failures, and rethrow `Error`s so programmer bugs crash loudly. Never convert a programmer error into a `PlatformFailed`. Every `PlatformUnsupported` must be evidence-backed against plugin source, not assumed.

**Filesystem writes go through `lib/src/_shared/native_fs.dart`** (sanitize / atomic reserve / stage). Never interpolate a caller-supplied fileName into a path directly.

**Pinned plugin behaviors and platform entitlements** are tabulated in `docs/UPDATING.md` — the open_filex channel protocol, `saveFile` bytes semantics, the permission-code list, and the macOS Downloads/user-selected entitlements a consumer app must declare. Re-verify on every dependency bump.

**Tests mirror `lib/src/` (VM); browser-bound suites are quarantined under `test/platform/web/` (the only tree `dart test -p chrome` compiles); the runtime/resolve layer is pinned in `test/runtime/`; the cross-adapter PlatformResult grammar lives as one spec in `test/batteries/`.** Every test file opens with a CHARTER stating what it alone proves; assertions are behavioral against declared truths, never liveness. Host-VM example journeys stay in memory (no `dart:io`); real filesystem effects live in the integration smoke.

---

## Data, secrets and gitignore

`.gitignore` already covers:

- `data/.env` and every other `.env` flavor (only `.env.example`, `.env.template` and `.env.sample` are committed)
- `data/auth/` (captured tokens, cookies, OAuth credentials)
- `data/db/*.sqlite*` (full app state)
- `cookies*.json`, `*.token`, `*.pem`, `*.key`
- `output/`, `debug/`, `logs/`, `cache/`

Never commit a sensitive file even if it is somehow not ignored — tell the maintainer instead. The ignore file is a second line of defense, not the only check.

---

## Working with AI agents

- **Run the test suite before claiming a task is done.** Always.
- **Fix what you find.** A `TODO` is not a fix: fix it in this pass or tell the maintainer.
- **No backwards-compatibility shims** for code that has not shipped. Code assumes the latest schema and contracts; migrations handle old data once.
- **No refactoring "for cleanliness" without a stated reason.** Suggest it before changing surrounding code.
- **No AI co-author lines in commits.** The maintainer is the author.
- **Never force-push a protected branch** (`prod`, `main`, `dev`), and never skip pre-commit hooks.
