#!/usr/bin/env bash
# Changelog bullet wall: one change per bullet, one sentence, at most 60
# words (80 for a **Breaking** bullet, whose migration is inline), no
# trailing period, no `###` subsection, no PR link (the release tooling
# appends the commit list). The standard is the comment block at the top
# of CHANGELOG.md; this is the part of it a reviewer would otherwise have
# to count by hand. Stamped from whuppi/ci; edit it there.
#
# Words are counted after dropping link targets, so a long GitHub URL
# never pushes a short bullet over the line. A bullet that wraps onto
# indented continuation lines is counted as one bullet. Under a version
# heading, one prose paragraph may lead the entry; any further prose is a
# paragraph that should be bullets.
set -euo pipefail

cd "$(dirname "$0")/.."

limit=60
breaking_limit=80
bad=0

check_bullet() {
  local file="$1" line_no="$2" body="$3"
  local stripped count max
  stripped=$(printf '%s' "$body" | sed -E 's/\]\([^)]*\)/]/g')
  read -ra words <<< "$stripped"
  count=${#words[@]}
  max=$limit
  case "$body" in
    "**Breaking"*) max=$breaking_limit ;;
  esac
  if [ "$count" -gt "$max" ]; then
    echo "$file:$line_no: $count words (limit $max): ${body:0:80}…"
    bad=1
  fi
  case "$stripped" in
    *.) echo "$file:$line_no: ends with a period: ${body:0:80}…"; bad=1 ;;
  esac
  if printf '%s' "$body" | grep -qE '\[PR #[0-9]+\]|/pull/[0-9]+'; then
    echo "$file:$line_no: links a PR; the release tooling appends the commit list: ${body:0:80}…"
    bad=1
  fi
}

for file in CHANGELOG.md CHANGELOG.pre.md; do
  [ -f "$file" ] || continue
  line_no=0
  in_header=0
  bullet=""
  bullet_line=0
  prose_blocks=0
  in_prose=0
  while IFS= read -r line; do
    line_no=$((line_no + 1))
    case "$line" in
      "<!--"*) case "$line" in *"-->"*) continue ;; esac; in_header=1 ;;
    esac
    if [ "$in_header" -eq 1 ]; then
      case "$line" in
        *"-->"*) in_header=0 ;;
      esac
      continue
    fi
    case "$line" in
      "- "*)
        [ -n "$bullet" ] && check_bullet "$file" "$bullet_line" "$bullet"
        bullet=${line#- }
        bullet_line=$line_no
        in_prose=0
        continue
        ;;
      "  "*)
        if [ -n "$bullet" ]; then
          bullet="$bullet ${line#"${line%%[![:space:]]*}"}"
          continue
        fi
        ;;
      "### "*)
        echo "$file:$line_no: a ### subsection; bullet order carries the categories"
        bad=1
        ;;
      "## "*) prose_blocks=0; in_prose=0 ;;
    esac
    [ -n "$bullet" ] && check_bullet "$file" "$bullet_line" "$bullet"
    bullet=""
    case "$line" in
      ""|"#"*|"<!--"*|"  "*) in_prose=0 ;;
      *)
        if [ "$in_prose" -eq 0 ]; then
          prose_blocks=$((prose_blocks + 1))
          in_prose=1
          if [ "$prose_blocks" -gt 1 ]; then
            echo "$file:$line_no: a prose paragraph; one lead line may open an entry, the rest are bullets: ${line:0:80}…"
            bad=1
          fi
        fi
        ;;
    esac
  done < "$file"
  [ -n "$bullet" ] && check_bullet "$file" "$bullet_line" "$bullet"
done

if [ "$bad" -ne 0 ]; then
  echo
  echo "A changelog bullet is one sentence: what changed and what you do about"
  echo "it. The cause and the proof go in the PR (the entry's commit list"
  echo "reaches it). Cut the bullet; do not raise the limit."
  exit 1
fi
