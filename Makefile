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
        analyze analyze-floor platforms format \
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

check: format analyze analyze-floor platforms test

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
# § 3 — Test
#
# make test        Unit (VM) + web adapters (Chrome).
# make test-unit   Pure-Dart + native-adapter tests on the VM.
# make test-web    Web adapter tests in a real browser (-p chrome) —
#                  blob downloads, Web Share detection, File System
#                  Access feature paths.
#
# The suite is being rebuilt — targets fail loudly until it lands,
# which is the honest state.
# ═══════════════════════════════════════════════════════════════════

test: test-unit test-web

test-unit:
	@echo "=== Unit: VM (types + _shared + picker + native adapters) ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	$(FLUTTER) test $(VERBOSE) $(TIMEOUT) --file-reporter json:$(TEST_RESULTS_DIR)/unit.json

test-web:
	@echo "=== Web adapters: Chrome ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	$(DART) test $(TIMEOUT) test/web_runners/ -p chrome --concurrency=1 --file-reporter json:$(TEST_RESULTS_DIR)/web.json

# ═══════════════════════════════════════════════════════════════════
# § 4 — Clean
# ═══════════════════════════════════════════════════════════════════

clean:
	$(FLUTTER) clean
	rm -rf $(TEST_RESULTS_DIR)
