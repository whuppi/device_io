# device_io

> **Public AI agent contract** for device_io — read by Cursor, OpenAI Codex, Aider, Devin, JetBrains Junie, and any AI tool that follows the [agents.md](https://agents.md) convention.
>
> Claude Code reads the deeper workspace config at `whuppi/.claude/rules/` and `whuppi/.claude/memory/` automatically — this AGENTS.md exists for every *other* AI tool.
>
> Stamped from `whuppi/AGENTS.template.md`. Per-repo content lives in the placeholder sections; everything else is identical workspace-wide.

---

## What this tool does

Cross-platform device IO for Flutter: pick images and files, share via the OS sheet, save silently or through the system save dialog, open in the default viewer. One API on iOS, Android, macOS, Windows, Linux, and web — apps never branch on platform; every outcome is a sealed `PlatformResult` value (`Supported` / `Cancelled` / `Unsupported` / `Failed`, with `PermissionDenied` as a named failure).

This repo is one tool inside the **whuppi** workspace — a multi-tool monorepo. The workspace ships shared engineering standards, code conventions, brand identity, and build patterns that apply across every tool. They're documented in three layers:

- **Repo-specific architecture, design, reference:** `./docs/`
- **Workspace human-readable standards:** `../docs/` (when this repo is cloned as part of the whuppi workspace) — engineering principles, decision frameworks, secret/CI patterns
- **Workspace AI-only directives:** `../.claude/rules/` (Claude Code reads these automatically; other AI tools can read them as supplementary context)

If you're working on this tool standalone (cloned outside the workspace), the in-repo `./docs/` is your authority; ignore the workspace pointers.

---

## Build and test commands

Run these after every code change. A failing test or analyzer error means the task is not done — don't suppress with `// ignore:`, `# noqa`, or `--no-verify`. Fix the underlying issue.

```bash
```bash
make hooks           # activate git hooks (once after cloning)
fvm install          # SDK pinned in .fvmrc
fvm flutter pub get
make check           # format + analyze + analyze-floor + platforms + test
make analyze         # static analysis only
make platforms       # pana gate: all six platforms must stay attributed
```
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

- **The stub-default conditional import in `lib/src/runtime/init_device_io.dart` is load-bearing.** pub.dev attributes to every platform whatever the DEFAULT target imports; a `dart:io` default silently drops web. Never make a platform library the default.
- **Two dependencies are registration-only — never import their Dart.** `share_plus` is reached via `share_plus_platform_interface` and `open_filex` via its method channel; importing either barrel drops desktop platforms from pub.dev attribution (their internals pin single-platform packages). `make platforms` fails if this regresses. Reasoning lives in the pubspec comments.
- **Expected failures are values, never throws.** Adapters return `PlatformResult`, capture stack traces into failures, and rethrow `Error`s so bugs crash loudly. Never convert a programmer error into a `PlatformFailed`.
- **Every `PlatformUnsupported` claim must be evidence-backed** — verify against plugin sources / platform APIs before writing one.
- **Filesystem writes go through `lib/src/_shared/native_fs.dart`** (sanitize / atomic reserve / stage). Never interpolate a caller-supplied fileName into a path directly.
- Pinned plugin behaviors (open_filex channel protocol, `saveFile` bytes semantics, permission code list) are tabulated in `docs/UPDATING.md` — re-verify on every dependency bump.

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
