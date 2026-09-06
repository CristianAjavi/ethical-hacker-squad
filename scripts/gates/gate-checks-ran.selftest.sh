#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Proves gate-checks-ran.sh in the negative.
#
# The gate's whole job is to tell three states apart that GitHub renders
# identically as an empty check list:
#
#   * a pull request that produced no run and should have          -> rc 1
#   * a pull request pushed a moment ago whose runs do not exist yet -> rc 0
#   * a read that failed, so the count of runs is not zero but unknown -> rc 2
#
# Collapse any two of those and the gate becomes worse than nothing: it would
# either accuse every fresh push, or certify a silence it never measured. Every
# case below exists because one specific collapse is cheap to write by accident.
#
# The gate is driven through a `gh` double on PATH, so the code under test is
# the gate's real parsing and its real control flow - not a second
# implementation that happens to agree with it.
#
# EXIT CODES: 0 every case behaved / 1 a case did not / 2 could not run
# ---------------------------------------------------------------------------
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GATE="$HERE/gate-checks-ran.sh"
[ -r "$GATE" ] || { echo "  COULD NOT MEASURE: $GATE is missing (rc 2)"; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "  COULD NOT MEASURE: the gate needs jq and so does this test (rc 2)"; exit 2; }

LAB="$(mktemp -d)"; trap 'rm -rf "$LAB"' EXIT
mkdir -p "$LAB/bin"
REPO="acme/widget"

# An instant N minutes in the past, in the spelling the GitHub API uses. Both
# date(1) dialects are tried; if neither answers the test says so instead of
# quietly testing 1970.
ago() {
  local m="$1" out
  out="$(date -u -v-"${m}"M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" && { printf '%s' "$out"; return 0; }
  out="$(date -u -d "${m} minutes ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)" && { printf '%s' "$out"; return 0; }
  return 1
}
OLD="$(ago 90)"  || { echo "  COULD NOT MEASURE: neither date(1) dialect produced a timestamp (rc 2)"; exit 2; }
NEW="$(ago 1)"   || { echo "  COULD NOT MEASURE: neither date(1) dialect produced a timestamp (rc 2)"; exit 2; }

# --- the gh double ---------------------------------------------------------
# Answers exactly the four calls the gate makes, from files the cases rewrite.
# Every exit code is a file too, so "this read failed" is a fixture and not a
# separate code path.
cat > "$LAB/bin/gh" <<'SH'
#!/bin/sh
lab="$LAB_DIR"
rc_of() { [ -r "$lab/$1" ] && cat "$lab/$1" || echo 0; }
case "$1" in
  auth) exit "$(rc_of auth_rc)" ;;
  pr)
    rc="$(rc_of list_rc)"; [ "$rc" -eq 0 ] || exit "$rc"
    cat "$lab/prs.tsv"; exit 0 ;;
  api)
    path="$2"
    case "$path" in
      */actions/runs*)
        rc="$(rc_of runs_rc)"; [ "$rc" -eq 0 ] || exit "$rc"
        sha="${path##*head_sha=}"; sha="${sha%%&*}"
        awk -v s="$sha" '$1==s {print $2; found=1} END{if(!found) print "0"}' "$lab/runs.tsv"
        exit 0 ;;
      */commits/*)
        rc="$(rc_of dates_rc)"; [ "$rc" -eq 0 ] || exit "$rc"
        sha="${path##*/commits/}"
        awk -v s="$sha" '$1==s {print $2; found=1} END{if(!found) exit 1}' "$lab/dates.tsv"
        exit $? ;;
      *)
        rc="$(rc_of repo_rc)"; [ "$rc" -eq 0 ] || exit "$rc"
        cat "$lab/repo_name"; exit 0 ;;
    esac ;;
esac
exit 1
SH
chmod +x "$LAB/bin/gh"

# --- fixture helpers -------------------------------------------------------
reset() {
  printf '%s' "$REPO" > "$LAB/repo_name"
  : > "$LAB/prs.tsv"; : > "$LAB/runs.tsv"; : > "$LAB/dates.tsv"
  for f in auth_rc list_rc runs_rc dates_rc repo_rc; do echo 0 > "$LAB/$f"; done
}
add_pr() {  # number sha mergeable draft title
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$LAB/prs.tsv"
}
set_runs() { printf '%s\t%s\n' "$1" "$2" >> "$LAB/runs.tsv"; }
set_date() { printf '%s\t%s\n' "$1" "$2" >> "$LAB/dates.tsv"; }

pass=0; fails=0
run_case() {  # name want_rc needle absent
  local name="$1" want="$2" needle="$3" absent="${4:-}" out rc bad=""
  out="$(env PATH="$LAB/bin:$PATH" LAB_DIR="$LAB" EHS_CHECKS_REPO="$REPO" \
             EHS_CHECKS_GRACE_MIN=10 bash "$GATE" 2>&1)"; rc=$?
  [ "$rc" -eq "$want" ] || bad="rc=$rc, expected $want"
  if [ -n "$needle" ] && ! printf '%s' "$out" | grep -qi -- "$needle"; then
    bad="${bad:+$bad; }it never said '$needle'"
  fi
  if [ -n "$absent" ] && printf '%s' "$out" | grep -qi -- "$absent"; then
    bad="${bad:+$bad; }it said '$absent' and must not"
  fi
  if [ -z "$bad" ]; then
    printf '  [self-test OK]   %-52s rc=%s\n' "$name" "$rc"; pass=$((pass + 1))
  else
    printf '  [self-test FAIL] %-52s %s\n' "$name" "$bad"
    printf '%s\n' "$out" | sed 's/^/      /'; fails=$((fails + 1))
  fi
}

# 1. Baseline. Without it rc 0 is unreachable and the gate has stopped being a
#    measurement: a check that can only fail is a check nobody keeps.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
add_pr 2 bbb MERGEABLE true  "a draft, which still gets runs"
add_pr 3 ccc CONFLICTING false "in conflict but its runs exist from before"
set_runs aaa 7; set_runs bbb 4; set_runs ccc 2
run_case "every open PR has a verdict -> passes" 0 "every one has a verdict"

# 2. THE DEFECT THIS GATE WAS WRITTEN FOR. A pull request opened already in
#    conflict starts nothing at all, and an empty check list reads as calm.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
add_pr 2 ddd CONFLICTING false "opened before its base moved"
set_runs aaa 7; set_runs ddd 0
set_date ddd "$OLD"
run_case "a conflicted PR with no run at all -> fails" 1 "#2"

# 3. The diagnosis has to name the conflict, not just the absence. Without the
#    cause the reader looks at the workflow triggers, which are innocent.
run_case "and it says the conflict is why nothing ran" 1 "no merge ref"

# 4. The same silence with a clean merge is a DIFFERENT bug - a trigger that
#    does not fire - and must not be reported as a conflict.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
add_pr 2 eee MERGEABLE false "merges clean and still ran nothing"
set_runs aaa 7; set_runs eee 0
set_date eee "$OLD"
run_case "clean merge and no run -> blames the trigger, not a conflict" 1 "NOT a conflict"

# 5. THE FALSE POSITIVE THAT WOULD GET THIS GATE DELETED. GitHub creates the
#    runs a moment after the push, so a zero on a fresh head is not yet a fact.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
add_pr 2 fff MERGEABLE false "pushed one minute ago"
set_runs aaa 7; set_runs fff 0
set_date fff "$NEW"
run_case "a head pushed a minute ago is excluded, not accused" 0 "too young"

# 6. But an exclusion is not a measurement. If EVERY open pull request is inside
#    the window the gate judged nobody, and a population of nobody is not a
#    clean sweep.
reset
add_pr 1 fff MERGEABLE false "pushed one minute ago"
set_runs fff 0
set_date fff "$NEW"
run_case "nothing left to judge -> 2, never a pass" 2 "nothing was judged"

# 7. An unreadable count is not a zero. Reporting 1 here would accuse a pull
#    request on the strength of a failed HTTP call.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 5
echo 22 > "$LAB/runs_rc"
run_case "the runs endpoint fails -> 2, not 0 and not 1" 2 "could not be counted"

# 8. Nor is a non-numeric answer. `total_count` absent from the JSON yields an
#    empty string, and an empty string compares equal to nothing safely.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa "null"
run_case "total_count is not a number -> 2" 2 "not a count"

# 9. A head with no run whose date will not read cannot be told from a push of a
#    second ago. That is the exact ambiguity the grace window exists to resolve.
reset
add_pr 1 ggg MERGEABLE false "no run and no date"
set_runs ggg 0
echo 9 > "$LAB/dates_rc"
run_case "the commit date fails to read -> 2" 2 "cannot be told from a push"

# 10. An empty list from the wrong repository is the failure that looks most like
#     success: rc 0, no output, nothing to report. The probe exists for it.
reset
printf '%s' "other/repo" > "$LAB/repo_name"
run_case "the probe answers for another repository -> 2" 2 "different repository"

# 11. And when the probe itself does not answer.
reset
echo 4 > "$LAB/repo_rc"
run_case "the repository probe does not answer -> 2" 2 "would prove nothing"

# 12. An unauthenticated gh reads every list as empty, which is a clean sweep
#     spelled exactly like a broken one.
reset
echo 1 > "$LAB/auth_rc"
run_case "gh not authenticated -> 2" 2 "not authenticated"

# 13. Listing the pull requests can fail on its own.
reset
echo 3 > "$LAB/list_rc"
run_case "listing the open pull requests fails -> 2" 2 "failed"

# 14. A repository with genuinely no open pull request passes, and says the
#     sweep was empty rather than implying it inspected something.
reset
run_case "no open pull request at all -> passes, and says so" 0 "no open pull request"

# 15. The grace window has to be a number. A typo that makes it empty would
#     compare as a string and exclude everything forever.
reset
add_pr 1 aaa MERGEABLE false "a normal pull request"
set_runs aaa 5
out="$(env PATH="$LAB/bin:$PATH" LAB_DIR="$LAB" EHS_CHECKS_REPO="$REPO" \
           EHS_CHECKS_GRACE_MIN="ten" bash "$GATE" 2>&1)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -qi 'whole number'; then
  printf '  [self-test OK]   %-52s rc=%s\n' "a non-numeric grace window -> 2" "$rc"; pass=$((pass + 1))
else
  printf '  [self-test FAIL] %-52s rc=%s\n' "a non-numeric grace window -> 2" "$rc"
  printf '%s\n' "$out" | sed 's/^/      /'; fails=$((fails + 1))
fi

printf '\n  %d PASS / %d FAIL\n' "$pass" "$fails"
[ "$fails" -eq 0 ] || exit 1
exit 0
