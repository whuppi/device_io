#!/usr/bin/env bash
# shellcheck shell=bash
# ────────────────────────────────────────────────────────────────────
# upgrade_pana.sh — the consumer-side upgrade radar for ONE pin: pana.
#
# Canonical: whuppi/ci/tool/upgrade_pana.sh; the workspace stamper copies it
# verbatim into each consumer's tool/. Edit the canonical + re-stamp — never a
# stamped copy. pr-checks fails a consumer PR whose stamped copy drifted.
#
# A consumer repo pins exactly one tool version of its own: PANA_VERSION in
# tool/versions.env, read by tool/platforms_gate.sh. The pin exists so the
# platform gate runs the SAME pana pub.dev runs — a stale pin means the gate
# quietly stops predicting the verdict it exists to predict. This script is
# what keeps that honest: it compares the pin against pub.dev's latest stable
# and fails when they differ.
#
# Not to be confused with whuppi/ci's OWN tool/ci/upgrade.sh, which watches the
# five binary pins whuppi/ci itself owns (fvm, Chrome, bore, zizmor,
# actionlint), sources tool/lib.sh, and is never stamped anywhere. This script
# is its consumer-side counterpart: self-contained, one pin, no lib.sh.
#
# CHECK ONLY — no apply mode, no auto-PR machinery. A scheduled run going red
# is the whole signal: it tells a human to bump one line. An apply mode can be
# added later if red nightlies prove annoying; until then the smaller surface
# is the better one.
#
# Any difference is drift, in EITHER direction. There is no semver comparison
# here on purpose: the contract is "the pin equals pub.dev's latest stable", so
# a pin that is ahead (a hand-picked prerelease, say) is just as much a gate
# that no longer matches pub.dev as a pin that is behind.
#
# Exit codes:
#   0  the pin matches pub.dev's latest stable
#   1  drift — the pin and pub.dev disagree (the actionable case)
#   2  the check could not run (no jq, no curl, no pin, network/parse failure)
#
# Env:
#   PANA_VERSION   normally read from tool/versions.env next to this script;
#                  an already-exported value wins, which is what lets a test
#                  drive the comparison without touching the file.
# Run from anywhere — paths resolve from the script's own location.
# ────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

command -v jq >/dev/null 2>&1 || {
  echo "upgrade_pana: jq not found (needed to parse the pub.dev API)" >&2
  exit 2
}
command -v curl >/dev/null 2>&1 || {
  echo "upgrade_pana: curl not found (needed to reach the pub.dev API)" >&2
  exit 2
}

# The pin lives in the caller's own tool/versions.env, stamped next to this
# script. An exported PANA_VERSION wins so the comparison stays testable.
if [ -z "${PANA_VERSION:-}" ] && [ -f "$SCRIPT_DIR/versions.env" ]; then
  # shellcheck source=/dev/null
  . "$SCRIPT_DIR/versions.env"
fi
if [ -z "${PANA_VERSION:-}" ]; then
  echo "upgrade_pana: PANA_VERSION is not set — expected it in" >&2
  echo "  $SCRIPT_DIR/versions.env" >&2
  exit 2
fi

# `.latest` is pub.dev's latest STABLE release for the package — prereleases
# are reachable only through `.versions`, so this never drifts onto one.
api="https://pub.dev/api/packages/pana"
body="$(curl -fsSL --retry 3 --retry-delay 2 --max-redirs 5 \
  --connect-timeout 10 --max-time 30 "$api" 2>/dev/null || true)"

if [ -z "$body" ]; then
  echo "upgrade_pana: could not reach $api — the radar cannot report." >&2
  exit 2
fi

latest="$(printf '%s' "$body" | jq -r '.latest.version // empty' 2>/dev/null || true)"
if [ -z "$latest" ]; then
  echo "upgrade_pana: $api returned no .latest.version — the radar cannot report." >&2
  exit 2
fi

if [ "$PANA_VERSION" = "$latest" ]; then
  echo "upgrade_pana: OK — pana pin $PANA_VERSION is current (pub.dev latest stable)."
  exit 0
fi

echo "upgrade_pana: DRIFT — the pana pin no longer matches pub.dev."
echo "  pinned here:          $PANA_VERSION"
echo "  pub.dev latest stable: $latest"
echo ""
echo "  The platform gate runs whatever this pin says, so it is no longer"
echo "  running the pana pub.dev runs. Bump the one line and re-run the gate:"
echo ""
echo "    PANA_VERSION=\"$latest\"   # in tool/versions.env, then: make platforms"
exit 1
