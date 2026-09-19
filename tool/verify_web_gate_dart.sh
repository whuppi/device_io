#!/usr/bin/env bash
# shellcheck shell=bash
# ────────────────────────────────────────────────────────────────────
# verify_web_gate_dart.sh — the pure-Dart web gate, shared verbatim.
#
# Canonical: whuppi/ci/tool/verify_web_gate_dart.sh; the workspace stamper
# copies it verbatim into each consumer's tool/. Edit the canonical + re-stamp
# — never a stamped copy. pr-checks fails a consumer PR whose stamped copy
# drifted.
#
# The pure-Dart twin of verify_web_gate.sh. That script is Flutter-only: it
# runs `flutter build web` on example/, which needs a Flutter app with a web/
# directory. A pure-Dart package has neither, so it had no usable web gate at
# all — and a package that advertises web with nothing compiling it is exactly
# the false green the Flutter gate exists to prevent.
#
# "Web support" is two compilers, not one. dart2js (the default JS build) and
# dart2wasm (`dart compile wasm`) have different type models: a js-interop
# switch or cast that dart2js accepts, dart2wasm can reject (a non-exhaustive
# JSAny switch, an unsound interop `as`, etc.). Neither the analyzer nor pana's
# wasm heuristic actually compiles wasm, so a JS-only build is a false green.
# This gate compiles the package's showcase under both compilers so that gap
# fails at PR time, not in a user's build.
#
# The showcase is the right thing to compile: it exercises the public API the
# way a consumer does, so anything web-hostile that a consumer would hit is
# reachable from it. A package whose showcase is deliberately native (it spawns
# a process, reads a file) has no business claiming web, and this gate says so
# by failing.
#
# What this gate does NOT do: run the test suite in a browser. That is the
# caller's own `test-web` lane, because how a package invokes its suite is a
# per-package decision (platform selectors, tagged files, a dedicated web
# runner). The two are complements — this gate proves the code COMPILES for
# web; the test lane proves it BEHAVES there.
#
# Env:
#   DART        Dart command — REQUIRED, no fallback. The caller (the Makefile
#               target) passes it; a missing one fails loud, never guesses.
#   WEB_ENTRY   Entrypoint to compile, relative to the package root.
#               Default: example/main.dart — the fleet's showcase convention.
# Run from the package root.
# ────────────────────────────────────────────────────────────────────
set -euo pipefail

: "${DART:?verify_web_gate_dart: DART must be set by the caller, e.g. fvm dart}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PKG_ROOT"

WEB_ENTRY="${WEB_ENTRY:-example/main.dart}"

if [ ! -f "$WEB_ENTRY" ]; then
  echo "verify_web_gate_dart: no entrypoint at $WEB_ENTRY" >&2
  echo "  Point WEB_ENTRY at the file to compile, or drop this gate from the" >&2
  echo "  package's test-web target — an absent showcase is not a pass." >&2
  exit 2
fi

# Build products are throwaway; keep them out of the working tree so a local
# run leaves nothing behind and never lands in a published package.
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

# DART may be several words ("fvm dart"): split it once, on purpose, into an array,
# so every call below quotes it and no linter is silenced for it.
read -ra DART_CMD <<<"$DART"

echo "verify_web_gate_dart: dart2js   — $DART compile js $WEB_ENTRY"
"${DART_CMD[@]}" compile js -o "$out/main.js" "$WEB_ENTRY"

echo "verify_web_gate_dart: dart2wasm — $DART compile wasm $WEB_ENTRY"
"${DART_CMD[@]}" compile wasm -o "$out/main.wasm" "$WEB_ENTRY"

echo "verify_web_gate_dart: OK — $WEB_ENTRY compiles under dart2js and dart2wasm"
