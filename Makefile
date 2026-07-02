# ═══════════════════════════════════════════════════════════════════
# SDK resolution
#
# Uses fvm by default (.fvmrc pins the version). Contributors without
# fvm can override:  make check DART=dart FLUTTER=flutter
# ═══════════════════════════════════════════════════════════════════

DART    ?= fvm dart
FLUTTER ?= fvm flutter
TEST_RESULTS_DIR ?= test-results
TIMEOUT := $(if $(CI),--timeout=30x,)
VERBOSE := $(if $(CI),--verbose,)

.PHONY: check hooks \
        analyze analyze-floor platforms format test-guards \
        test test-unit test-web \
        clean

# ═══════════════════════════════════════════════════════════════════
# § 1 — Gate
#
# make check    Full local gate before PR.
# make hooks    Activate the repo's git hooks (commit-msg, pre-commit).
#               Run once after cloning — they stay dormant otherwise.
#               Idempotent.
# ═══════════════════════════════════════════════════════════════════

check: format analyze analyze-floor platforms test-guards test

hooks:
	@git config core.hooksPath .githooks
	@echo "✓ git hooks active (core.hooksPath → .githooks)"

# ═══════════════════════════════════════════════════════════════════
# § 2 — Analyze
#
# make format         Formatter in check mode — fails on unformatted files
#                     (CI is never the first place the formatter runs).
# make analyze        Static analysis, strict lints from analysis_options.
# make analyze-floor  Resolve to the OLDEST in-range dependencies and
#                     analyze the shipped code (lib only). The lower bounds
#                     are only honest if the code analyzes against them,
#                     not just the newest a fresh build resolves. Tests are
#                     excluded on purpose; a consumer sees lib, never your
#                     tests. Snapshots and restores the lock so a local run
#                     leaves the tree clean.
# make platforms      Gate pub.dev platform support: pana must report all
#                     six platforms, else a regression like an unconditional
#                     dart:io import silently drops web (the stub-default
#                     conditional import in runtime/ is what it protects).
# ═══════════════════════════════════════════════════════════════════

format:
	$(DART) format --output=none --set-exit-if-changed .

analyze:
	$(DART) analyze

analyze-floor:
	@cp pubspec.lock .pubspec.lock.floor-backup
	$(FLUTTER) pub downgrade
	$(DART) analyze lib
	@mv .pubspec.lock.floor-backup pubspec.lock
	@$(FLUTTER) pub get >/dev/null
	@echo "✓ floor analyze clean (lockfile restored)"

platforms:
	@$(DART) pub global activate pana >/dev/null
	@$(DART) pub global run pana --no-warning --json . 2>/dev/null \
	  | $(DART) run tool/check_platforms.dart

# ═══════════════════════════════════════════════════════════════════
# § 2b — Test-suite guards
#
# make test-guards   Mechanical rules over the suite itself:
#                    - package:web / dart:js_interop only under
#                      test/web_runners/ (the VM suites must compile
#                      without a browser target)
#                    - dart:io outside the native-adapter suites
#                      (test/_shared, test/download, test/sharing,
#                      test/opener — their SUBJECTS wrap dart:io)
#                      carries an 'io-exempt: <reason>' comment
#                    - no direct plugin imports anywhere in test/ —
#                      suites fake through the platform INTERFACES
#                      (image_picker_platform_interface,
#                      share_plus_platform_interface) or mock the
#                      method channels; importing a plugin's own Dart
#                      couples tests to what the adapters abstract
# ═══════════════════════════════════════════════════════════════════

test-guards:
	@bad=$$(grep -rln "package:web/\|dart:js_interop" test/ --include="*.dart" \
	  | grep -v "^test/web_runners/" || true); \
	if [ -n "$$bad" ]; then \
	  echo "browser-only import outside test/web_runners/ — the VM suites"; \
	  echo "must compile without a browser target:"; \
	  echo "$$bad"; exit 1; fi
	@bad=$$(for f in $$(grep -rln "dart:io" test/types test/picker test/harness test/web_runners --include="*.dart" 2>/dev/null); do \
	  grep -q "io-exempt:" "$$f" || echo "$$f"; \
	done); \
	if [ -n "$$bad" ]; then \
	  echo "dart:io in a suite whose subject is not dart:io-backed. A test"; \
	  echo "that legitimately needs it carries an 'io-exempt: <reason>'"; \
	  echo "comment. Missing it:"; \
	  echo "$$bad"; exit 1; fi
	@bad=$$(grep -rln "package:image_picker/\|package:file_picker/\|package:share_plus/\|package:open_filex/" test/ --include="*.dart" || true); \
	if [ -n "$$bad" ]; then \
	  echo "direct plugin import in a test — fake through the platform"; \
	  echo "interface packages or mock the method channel instead:"; \
	  echo "$$bad"; exit 1; fi
	@echo "✓ test guards clean"

# ═══════════════════════════════════════════════════════════════════
# § 3 — Test
#
# make test        Unit (VM) + web adapters (Chrome).
# make test-unit   Pure-Dart + native-adapter tests on the VM.
# make test-web    Web adapter tests in a real browser (-p chrome) —
#                  blob downloads, Web Share detection, File System
#                  Access feature paths.
#
# ═══════════════════════════════════════════════════════════════════

test: test-unit test-web

test-unit:
	@echo "=== Unit: VM (types + _shared + picker + native adapters) ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	$(FLUTTER) test $(VERBOSE) $(TIMEOUT) test/types test/_shared test/picker test/download test/sharing test/opener --file-reporter json:$(TEST_RESULTS_DIR)/unit.json

test-web:
	@echo "=== Web adapters: real Chrome ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	$(FLUTTER) test $(VERBOSE) $(TIMEOUT) --platform chrome test/web_runners --file-reporter json:$(TEST_RESULTS_DIR)/web.json

# ═══════════════════════════════════════════════════════════════════
# § 4 — Clean
# ═══════════════════════════════════════════════════════════════════

clean:
	$(FLUTTER) clean
	rm -rf $(TEST_RESULTS_DIR)
