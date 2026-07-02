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
        test-example test-example-matrix test-example-macos test-example-device \
        test-example-android test-example-ios test-example-linux \
        test-example-windows test-example-web \
        verify-android verify-ios verify-macos verify-linux \
        verify-windows verify-web \
        clean

# ═══════════════════════════════════════════════════════════════════
# § 1 — Gate
#
# make check    Full local gate before PR.
# make hooks    Activate the repo's git hooks (commit-msg, pre-commit).
#               Run once after cloning — they stay dormant otherwise.
#               Idempotent.
# ═══════════════════════════════════════════════════════════════════

check: format analyze analyze-floor platforms test-guards test test-example-matrix

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
# § 3b — Example tests
#
# make test-example-matrix   Host-VM journeys: the example UI driven end
#                            to end through the real adapters against
#                            scripted plugin edges, across every device
#                            profile. No device needed — part of check.
# make test-example-macos    Integration smoke on macOS (real plugins).
# make test-example-device   Integration smoke on DEVICE=<id>.
#
# make test-example-<plat>   Integration smoke on one real target
#                            (android / ios / linux / windows / web). The
#                            per-platform CI matrix (full-test) runs these;
#                            each boots its device via the make-target
#                            capabilities. Android + iOS run on the
#                            booted emulator/simulator (no -d); the Android
#                            report lands at test-results/int-android.json,
#                            which the emulator teardown-watchdog reconciles.
# make verify-<plat>         Release build of the example — proves the
#                            plugin links and packages on that target.
# ═══════════════════════════════════════════════════════════════════

test-example: test-example-matrix test-example-macos

test-example-matrix:
	@echo "=== Example: journey matrix (host VM, every device profile) ==="
	cd example && $(FLUTTER) test $(VERBOSE) $(TIMEOUT) test/journeys

test-example-macos:
	@echo "=== Example: integration smoke on macOS ==="
	cd example && $(FLUTTER) test $(TIMEOUT) integration_test/device_io_smoke_test.dart -d macos

test-example-device:
	@echo "=== Example: integration smoke on device=$(DEVICE) ==="
	cd example && $(FLUTTER) test $(TIMEOUT) integration_test/device_io_smoke_test.dart -d $(DEVICE)

# Android + iOS run on the connected/booted device — no -d. CI boots the
# emulator/simulator via the make-target capabilities. The Android JSON
# report is what the emulator watchdog's reconciler reads.
test-example-android:
	@echo "=== Example: Android ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	cd example && $(FLUTTER) test $(VERBOSE) $(TIMEOUT) integration_test/device_io_smoke_test.dart --file-reporter json:../$(TEST_RESULTS_DIR)/int-android.json

test-example-ios:
	@echo "=== Example: iOS ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	cd example && $(FLUTTER) test $(VERBOSE) $(TIMEOUT) integration_test/device_io_smoke_test.dart --file-reporter json:../$(TEST_RESULTS_DIR)/int-ios.json

test-example-linux:
	@echo "=== Example: Linux ==="
	$(call ensure_gtk)
	@mkdir -p $(TEST_RESULTS_DIR)
	cd example && $(FLUTTER) test $(VERBOSE) $(TIMEOUT) integration_test/device_io_smoke_test.dart -d linux --file-reporter json:../$(TEST_RESULTS_DIR)/int-linux.json

test-example-windows:
	@echo "=== Example: Windows ==="
	@mkdir -p $(TEST_RESULTS_DIR)
	cd example && $(FLUTTER) test $(VERBOSE) $(TIMEOUT) integration_test/device_io_smoke_test.dart -d windows --file-reporter json:../$(TEST_RESULTS_DIR)/int-windows.json

# Web integration runs through flutter drive (-d web-server) with a single
# Chrome managed by chromedriver — the same shape as pdf_manipulator's web
# path, minus its WASM threading modes (device_io has none). The chrome
# capability puts chromedriver on PATH in CI. One shell so the background
# chromedriver PID survives to the cleanup.
test-example-web:
	@echo "=== Example: Web (integration smoke via flutter drive) ==="
	@chromedriver --port=4444 >/dev/null 2>&1 & \
	CD_PID=$$!; \
	sleep 2; \
	( cd example && $(FLUTTER) drive \
	    --driver=test_driver/integration_test.dart \
	    --target=integration_test/device_io_smoke_test.dart \
	    -d web-server \
	    --browser-name=chrome \
	    --driver-port=4444 \
	    --web-browser-flag=--no-sandbox ); \
	rc=$$?; \
	kill $$CD_PID 2>/dev/null || true; \
	exit $$rc

# ── Verify: release builds of the example ──
verify-android:
	@echo "=== Verify: Android ==="
	cd example && $(FLUTTER) build apk --release $(VERBOSE)

verify-ios:
	@echo "=== Verify: iOS ==="
	cd example && $(FLUTTER) build ios --release --no-codesign $(VERBOSE)

verify-macos:
	@echo "=== Verify: macOS ==="
	cd example && $(FLUTTER) build macos --release $(VERBOSE)

verify-linux:
	@echo "=== Verify: Linux ==="
	$(call ensure_gtk)
	cd example && $(FLUTTER) build linux --release $(VERBOSE)

verify-windows:
	@echo "=== Verify: Windows ==="
	cd example && $(FLUTTER) build windows --release $(VERBOSE)

verify-web:
	@echo "=== Verify: Web ==="
	cd example && $(FLUTTER) build web --release $(VERBOSE)

# ═══════════════════════════════════════════════════════════════════
# § 3c — Build helpers
# ═══════════════════════════════════════════════════════════════════

# Linux desktop builds need GTK 3. Present → no-op. Missing → install on
# CI, instruct locally.
define ensure_gtk
	@command -v pkg-config >/dev/null && pkg-config --exists gtk+-3.0 || { \
		if [ -n "$$CI" ]; then sudo apt-get update -qq && sudo apt-get install -y -qq ninja-build libgtk-3-dev; \
		else echo "Error: libgtk-3-dev not found. Run: sudo apt-get install -y ninja-build libgtk-3-dev"; exit 1; fi; }
endef

# ═══════════════════════════════════════════════════════════════════
# § 4 — Clean
# ═══════════════════════════════════════════════════════════════════

clean:
	$(FLUTTER) clean
	rm -rf $(TEST_RESULTS_DIR)
