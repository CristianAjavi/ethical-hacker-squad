#!/usr/bin/env bash
# Tests scripts/gh/next-version.sh and scripts/gh/build-changelog.sh on a
# throwaway repository built here. Both are covered in ONE file because they
# share one rule and shared it wrongly: `BREAKING CHANGE:` decides the semver in
# the first and the "Breaking changes" heading in the second, and both used to
# look for it with `tr '\r\n' '  '` + `(^|[[:space:]])BREAKING[ -]CHANGE:`.
#
# WHY THIS FILE EXISTS
#   Conventional Commits puts `BREAKING CHANGE:` in a FOOTER: at the start of its
#   own line. Flattening the body into one line and then accepting the marker
#   after ANY whitespace made every mid-sentence mention decide the release.
#   MEASURED before the fix, with the eight cases below: a body reading "this is
#   not a BREAKING CHANGE: no API moved", a body quoting somebody else's
#   changelog, and a marker indented by two spaces ALL produced bump=major and
#   filed a `docs:` commit under "Breaking changes". The commit body is untrusted
#   text - it arrives through PRs of the knowledge loop - so this is a stranger
#   choosing the major version of a published release.
#
#   The half of this file that matters most is the OTHER four cases. A suite that
#   only proves the three false majors are gone stays green the day somebody
#   tightens the expression too far and a LEGITIMATE footer stops being seen; the
#   release would then ship as minor and nothing here would say so. Cases 5-8 are
#   what make that impossible: a footer, a footer after a blank line, a `type!:`
#   subject and a plain `feat:` must keep the verdict they have always had.
#
# Zero network. git is used only inside a throwaway repository under mktemp.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = harness broke.
set -uo pipefail

SP="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -- "$SP/../../.." && pwd -P)"
NEXTV="$ROOT/scripts/gh/next-version.sh"
CHLOG="$ROOT/scripts/gh/build-changelog.sh"
for f in "$NEXTV" "$CHLOG"; do
  [ -f "$f" ] || { echo "  COULD NOT MEASURE: $f is missing (rc 2)"; exit 2; }
done
command -v git >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: git is missing (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
R="$LAB/repo"; mkdir -p "$R"
pass=0; fail=0

G() { git -C "$R" -c user.email=t@e -c user.name=t "$@"; }

git -C "$R" init -q -b main 2>/dev/null || { echo "  COULD NOT MEASURE: git init failed (rc 2)"; exit 2; }
printf 'seed\n' > "$R/a.txt"; G add -A; G commit -qm "chore: base"
BASE="$(G rev-parse HEAD)"

# case <label> <subject> <body> <want-bump> <want-breaking:yes|no>
case_run() {
  local label="$1" subject="$2" body="$3" want_bump="$4" want_break="$5"
  local sha bump chl has_break ok=1

  printf 'x%s\n' "$RANDOM" > "$R/b.txt"; G add -A
  printf '%s\n\n%s\n' "$subject" "$body" | G commit -q -F - || {
    printf '  FAIL  %-52s (the commit could not be made)\n' "$label"; fail=$((fail+1)); return; }
  sha="$(G rev-parse HEAD)"

  # next-version.sh and build-changelog.sh both read the CURRENT repository, so
  # they run with the lab as the working directory and never see this worktree.
  bump="$( cd "$R" && bash "$NEXTV" --current 1.2.3 --from "$BASE" --to "$sha" --bump auto 2>/dev/null \
           | sed -n 's/^bump=//p' )"
  chl="$( cd "$R" && bash "$CHLOG" --version 9.9.9 --from "$BASE" --to "$sha" --date 2026-01-01 2>/dev/null )"
  if printf '%s\n' "$chl" | grep -q '^### Breaking changes$'; then has_break=yes; else has_break=no; fi

  [ "$bump" = "$want_bump" ] || ok=0
  [ "$has_break" = "$want_break" ] || ok=0
  if [ "$ok" -eq 1 ]; then
    printf '  PASS  %-52s bump=%-6s breaking=%s\n' "$label" "$bump" "$has_break"; pass=$((pass+1))
  else
    printf '  FAIL  %-52s bump=%-6s breaking=%-3s (wanted %s / %s)\n' \
      "$label" "${bump:-<none>}" "$has_break" "$want_bump" "$want_break"
    fail=$((fail+1))
  fi
  G reset -q --hard "$BASE"
}

echo "== next-version.sh + build-changelog.sh: who is allowed to declare a break"

# --- the three the fix removes: untrusted prose deciding the release ---------
case_run "a body that DENIES a break is not a break" \
  "docs: touch up the readme" \
  "To be clear, this is not a BREAKING CHANGE: no API moved." \
  patch no

case_run "a body quoting somebody else's changelog" \
  "docs: import upstream notes" \
  "> upstream wrote: BREAKING CHANGE: they dropped node 16" \
  patch no

case_run "a marker indented two spaces is not a footer" \
  "docs: an example" \
  "  BREAKING CHANGE: indented, not a footer" \
  patch no

# --- the four controls: what must NOT stop working -------------------------
# These are the ones that catch the opposite mistake. An expression tightened
# past the spec (anchoring on the first line, requiring the exact spelling with
# a space, demanding a preceding blank line) leaves the three cases above green
# and silently downgrades a real breaking release to minor.
case_run "a LEGITIMATE footer still forces major" \
  "feat: new thing" \
  "BREAKING CHANGE: the api moved" \
  major yes

case_run "a legitimate footer after prose and a blank line" \
  "fix: something" \
  "$(printf 'some prose here\n\nBREAKING CHANGE: the api moved')" \
  major yes

case_run "a type!: subject still forces major" \
  "refactor!: drop the old api" \
  "no footer at all" \
  major yes

case_run "a plain feat: is still minor and not breaking" \
  "feat: add a thing" \
  "no footer at all" \
  minor no

case_run "a plain docs: is still patch and not breaking" \
  "docs: touch up the readme" \
  "nothing special here" \
  patch no

echo
echo "  $pass PASS / $fail FAIL"
[ "$fail" -eq 0 ] || exit 1
echo "  Result: OK. Only a real footer declares a break, in the version AND in the"
echo "          CHANGELOG, and every legitimate way of declaring one still works."
exit 0
