<!--
============================================================================
AUTO-GENERATED — DO NOT EDIT
============================================================================
This file is rendered by:
  /Users/deepanshu/personal1/whuppi/.claude/scripts/stamp-agents.sh
from:
  /Users/deepanshu/personal1/whuppi/AGENTS.template.md
  with per-repo data inlined in the stamper itself.

To change content:
  - Workspace-wide: edit AGENTS.template.md, then re-run the stamper.
  - One repo only:  edit the `repo_data` case for "device_io" in stamp-agents.sh,
                    then re-run the stamper.
Manual edits to this file will be overwritten on the next stamp.
============================================================================
-->

# device_io

> **Public AI agent contract** for device_io — read by Cursor, OpenAI Codex, Aider, Devin, JetBrains Junie, and any AI tool that follows the [agents.md](https://agents.md) convention.
>
> Claude Code reads the deeper workspace config at `whuppi/.claude/rules/` and `whuppi/.claude/memory/` automatically — this AGENTS.md exists for every *other* AI tool.
>
> Stamped from `whuppi/AGENTS.template.md`. Per-repo content lives in the placeholder sections; everything else is identical workspace-wide.

---

## What this tool does

**device_io** is a cross-platform device IO package for Flutter — pick images and files, share via the OS sheet, save silently or through the system save dialog, open in the default viewer. One API on iOS, Android, macOS, Windows, Linux, and web: apps never branch on platform. Every operation returns a sealed `PlatformResult` — `Success` / `Cancelled` / `Unsupported` / `Failed`, with `PermissionDenied` as a named failure carrying the caught error and stack trace. Four capability contracts (`AssetPicker`, `Sharer`, `FileSaver`, `FileOpener`) sit behind one `DeviceIO` container, constructed synchronously via `DeviceIO()`. Reads are lazy (`PickedAsset` loads nothing until asked); filesystem writes are browser-grade safe (name sanitization, atomic no-clobber numbering, `.part`-then-rename stream writes). pub.dev attributes all six platforms, guarded by the pana platform gate (`make platforms`).

This repo is one tool inside the **whuppi** workspace — a multi-tool monorepo. The workspace ships shared engineering standards, code conventions, brand identity, and build patterns that apply across every tool. They're documented in three layers:

- **Repo-specific architecture, design, reference:** `./docs/`
- **Workspace human-readable standards:** `../docs/` (when this repo is cloned as part of the whuppi workspace) — engineering principles, decision frameworks, secret/CI patterns
- **Workspace AI-only directives:** `../.claude/rules/` (Claude Code reads these automatically; other AI tools can read them as supplementary context)

If you're working on this tool standalone (cloned outside the workspace), the in-repo `./docs/` is your authority; ignore the workspace pointers.

---

## Build and test commands

Run these after every code change. A failing test or analyzer error means the task is not done — don't suppress with `// ignore:`, `# noqa`, or `--no-verify`. Fix the underlying issue.

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

Match the style of existing code in this repo first. Workspace-wide standards live at:

- **Engineering standards** (seven questions before every decision, env-blind code, twelve-factor checklist): `../docs/universal/development-standards.md`
- **Secrets and environments** (GitHub Environments, branch=env, security walls, files-not-env-vars): `../docs/universal/secrets-and-environments.md`
- **Python tools** (SDK/CLI/MCP three-layer pattern, ruff config, hatchling): `../.claude/rules/python-shared/sdk-cli-mcp-pattern.md`
- **Flutter packages** (opaque boundaries, async at edges, dependency flow): `../.claude/rules/flutter-shared/package-design.md`
- **Comments and doc-comments** (what earns a comment, what doesn't): `../.claude/rules/universal/comments.md`
- **Renaming anything** (sweep all references in one session): `../.claude/rules/universal/rename-hygiene.md`

When in doubt, read existing code in this repo and match it. Per-repo style consistency beats general-best-practice consistency.

---

## Tool-specific notes

**The stub-default conditional import is load-bearing.** `lib/src/runtime/resolve.dart` (and `lib/src/picker/web_file_pick.dart`) default to the STUB target: pub.dev attributes to every platform whatever the DEFAULT conditional import pulls in, so a `dart:io` default silently drops web. `make platforms` guards it.

**Two dependencies are registration-only — never import their Dart.** `share_plus` is reached through `share_plus_platform_interface`, and `open_filex` through its method channel — importing either package's own barrel drops desktop platforms from pub.dev attribution (their internals pin single-platform packages). The pubspec comments carry the reasoning; `make platforms` fails if this regresses.

**Expected failures are values, never throws.** Adapters return `PlatformResult`, capture stack traces into failures, and rethrow `Error`s so programmer bugs crash loudly. Never convert a programmer error into a `PlatformFailed`. Every `PlatformUnsupported` must be evidence-backed against plugin source, not assumed.

**Filesystem writes go through `lib/src/_shared/native_fs.dart`** (sanitize / atomic reserve / stage). Never interpolate a caller-supplied fileName into a path directly.

**Pinned plugin behaviors and platform entitlements** are tabulated in `docs/UPDATING.md` — the open_filex channel protocol, `saveFile` bytes semantics, the permission-code list, and the macOS Downloads/user-selected entitlements a consumer app must declare. Re-verify on every dependency bump.

**Tests mirror `lib/src/` (VM) with the web adapters in real Chrome under `test/web_runners/`.** Every test file opens with a CHARTER stating what it alone proves; assertions are behavioral against declared truths, never liveness. Host-VM example journeys stay in memory (no `dart:io`); real filesystem effects live in the integration smoke.

---

## Data, secrets, and gitignore

This repo's `.gitignore` is stamped from `../.gitignore.template` (workspace canonical). It already covers:

- `data/.env` and every other `.env` flavor (only `.env.example` / `.env.template` / `.env.sample` are committed)
- `data/auth/` (captured tokens, cookies, OAuth credentials)
- `data/db/*.sqlite*` (full app state — irreplaceable)
- `cookies*.json`, `*.token`, `*.pem`, `*.key`
- `output/`, `debug/`, `logs/`, `cache/`

Never commit a sensitive file even if it's somehow not gitignored — surface to the maintainer instead. The gitignore is defense-in-depth, not the only check.

---

## Working with AI agents

- **Run the test suite before claiming completion.** Always.
- **Don't add `TODO` comments as a substitute for fixing things.** If you found it, you own it — fix in this pass or surface to the maintainer.
- **Don't add backwards-compat shims** for code that hasn't shipped. Code assumes the latest schema and contracts; migrations handle old data once.
- **Don't refactor "for cleanliness" without a stated reason.** Surface the suggestion before changing surrounding code.
- **No co-authored-by AI in commits.** The maintainer is the author.
- **Never force-push protected branches** (`prod`, `main`, `dev`). Never skip pre-commit hooks.

For the engineering philosophy that informs every line of code in this workspace, see `../.claude/rules/universal/dc-engineering-philosophy.md` if available.

---

*This file is stamped from `whuppi/AGENTS.template.md`. The placeholder sections (`{{...}}`) are the only parts customized per repo. Re-stamping refreshes the shared content; per-repo placeholders are preserved.*
