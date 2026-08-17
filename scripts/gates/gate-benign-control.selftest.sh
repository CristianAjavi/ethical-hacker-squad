#!/usr/bin/env bash
# Self-test for gate-benign-control.sh.
#
# A gate nobody has seen fail is not a proved gate, and a battery that lives on
# one laptop is not a monitored one. Every case here breaks, ON A THROWAWAY COPY
# of the corpus, exactly one thing the gate claims to watch, and asserts the exit
# code the doctrine demands:
#
#   1 = the gate MEASURED a defect        (the rule gutted, duplicated, unwired)
#   2 = the gate COULD NOT MEASURE        (its inputs are missing or unusable)
#   0 = measured and conforming           (controls, including a false-positive one)
#
# Two of the cases below are not decoration: P1 sends the gate a file full of the
# words it hunts ("benign", "legitimate", "verified", `Secure`) written as
# ordinary prose, because a gate that fires on correct text gets switched off
# within a week; and N0/N22 bracket the run so a battery that silently stopped
# measuring shows up as a green that never turned red.
#
# Exit codes: 0 = every case behaved | 1 = some case did not | 2 = could not measure.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="$HERE/gate-benign-control.sh"

if [ -n "${EHS_REPO_ROOT:-}" ]; then
  SRC="$EHS_REPO_ROOT"
elif SRC=$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null); then
  :
else
  SRC="$(cd "$HERE/../.." && pwd)"
fi

REM=skills/ethical-hacker-squad/references/knowledge/remediation.md
VOC=skills/ethical-hacker-squad/references/vocabulary.md
OTHER=skills/ethical-hacker-squad/references/knowledge/web-api.md

cannot() { printf 'COULD NOT MEASURE: %s\n' "$*" >&2; exit 2; }

[ -r "$GATE" ] || cannot "$GATE is not readable"
for f in "$REM" "$VOC" "$OTHER"; do
  [ -r "$SRC/$f" ] || cannot "$f is not readable under $SRC"
done
command -v awk >/dev/null 2>&1 || cannot "awk is missing"

T="$(mktemp -d)" || cannot "no temporary directory"
trap 'rm -rf "$T"' EXIT

# One pristine copy; every case is a copy of that copy, so a mutation can never
# leak into the next case or back into the repository.
mkdir -p "$T/pristine"
cp -R "$SRC/skills" "$SRC/agents" "$T/pristine/" 2>/dev/null \
  || cannot "the corpus could not be copied out of $SRC"
mkdir -p "$T/pristine/scripts/gates"
cp "$GATE" "$T/pristine/scripts/gates/" || cannot "the gate could not be copied"

pass=0; fail=0

prep() {  # prep <case> -> echoes the case root
  local d="$T/$1"
  mkdir -p "$d"
  cp -R "$T/pristine/." "$d/"
  printf '%s' "$d"
}

check() { # check <case> <expected rc> <description>
  local d="$T/$1" want="$2" desc="$3" rc out
  out=$(EHS_REPO_ROOT="$d" bash "$d/scripts/gates/gate-benign-control.sh" 2>&1); rc=$?
  if [ "$rc" -eq "$want" ]; then
    printf '  ok    %-4s %-56s rc=%s\n' "$1" "$desc" "$rc"; pass=$((pass+1))
  else
    printf '  FAIL  %-4s %-56s rc=%s (expected %s)\n' "$1" "$desc" "$rc" "$want"; fail=$((fail+1))
    printf '%s\n' "$out" | sed 's/^/        | /'
  fi
}

drop_region() { awk '/<!-- benign-control:rule/{s=1} !s{print} /<!-- \/benign-control:rule -->/{s=0}' "$1" >"$1.t" && mv "$1.t" "$1"; }
drop_line()   { grep -vF -- "$2" "$1" >"$1.t" && mv "$1.t" "$1"; }
sub_in_row()  { awk -v key="$2" -v from="$3" -v to="$4" '{ if (index($0, key)==1) gsub(from, to); print }' "$1" >"$1.t" && mv "$1.t" "$1"; }
edit()        { sed "$2" "$1" >"$1.t" && mv "$1.t" "$1"; }

printf 'Self-test for gate-benign-control.sh\n====================================\n'
printf 'corpus under test: %s\n\n' "$SRC"

# --- rc=0: controls --------------------------------------------------------
d=$(prep N0);  check N0 0 "CONTROL: untouched copy"

# --- rc=1: the rule is gone, gutted or duplicated --------------------------
d=$(prep N1);  drop_region "$d/$REM"
               check N1 1 "the whole rule region deleted"
d=$(prep N5);  drop_line "$d/$REM" '| **(b) benign**'
               check N5 1 "the BENIGN run deleted (the point of the procedure)"
d=$(prep N6);  sub_in_row "$d/$REM" '| **(b) benign**' '`inconclusive`' '`verified`'
               check N6 1 "a missing benign run rounded up to a pass"
d=$(prep N7);  sub_in_row "$d/$REM" '| **(a) baseline**' '`inconclusive`' '`mostly-verified`'
               check N7 1 "an outcome the vocabulary does not declare"
d=$(prep N15); awk '/\| \*\*\(b\) benign\*\*/{b=$0; next} /\| \*\*\(c\) attack\*\*/{print; print b; next} {print}' \
                 "$d/$REM" >"$d/r.t" && mv "$d/r.t" "$d/$REM"
               check N15 1 "the runs reordered (attack before benign)"
d=$(prep N16); drop_line "$d/$REM" '**Missing (b)**'
               check N16 1 "the incompleteness rule itself deleted"
d=$(prep N8);  awk '/<!-- benign-control:rule/{s=1} s{print} /<!-- \/benign-control:rule -->/{s=0}' \
                 "$d/$REM" >>"$d/$OTHER"
               check N8 1 "the rule duplicated into a second pack"
d=$(prep N11); drop_line "$d/$REM" '<!-- /benign-control:rule -->'
               check N11 1 "region opened and never closed"
d=$(prep N17); edit "$d/$REM" 's/<!-- benign-control:rule VER-08 -->/<!-- benign-control:rule VER-09 -->/'
               check N17 1 "marker id and procedure id disagree"

# --- rc=1: the procedure stops being a procedure of the corpus -------------
d=$(prep N12); awk '/^### VER-08 /{s=1} /^## §8/{s=0} !(s && /^\*\*Tooling\*\*/){print}' \
                 "$d/$REM" >"$d/r.t" && mv "$d/r.t" "$d/$REM"
               check N12 1 "one of the six mandatory fields removed"
d=$(prep N13); printf '\n### VER-08 A colliding heading in another pack\n' >>"$d/$OTHER"
               check N13 1 "the id collides with a heading elsewhere"
d=$(prep N19); edit "$d/$REM" 's/^### VER-06 /### VER-09 /'
               check N19 1 "a numbering gap opened in the VER series"

# --- rc=1: written but not wired in ----------------------------------------
d=$(prep N9);  edit "$d/$REM" 's/VER-02, VER-03, VER-04, VER-08/VER-02, VER-03, VER-04/'
               check N9 1 "dropped from the selective loading index"
d=$(prep N10); awk '/^### [A-Z]+-[0-9]+/{h=$0; sub(/^### /,"",h); split(h,a," "); cur=a[1]}
                    { if (cur != "" && cur != "VER-08") gsub(/VER-08/, "VER-99"); print }' \
                 "$d/$REM" >"$d/r.t" && mv "$d/r.t" "$d/$REM"
               check N10 1 "no other procedure points at it any more"

# --- rc=2: the gate cannot measure (never a pass) --------------------------
d=$(prep N2);  mv "$d/$REM" "$d/remediation.md.away"
               check N2 2 "remediation.md ABSENT"
d=$(prep N14); : >"$d/$REM"
               check N14 2 "remediation.md EMPTY"
d=$(prep N3);  mv "$d/$VOC" "$d/vocabulary.md.away"
               check N3 2 "vocabulary.md ABSENT"
d=$(prep N4);  edit "$d/$VOC" 's/vocabulary:declare verification/vocabulary:declare verifications/'
               check N4 2 "no 'verification' dimension declared"
d=$(prep N20); awk '/<!-- vocabulary:declare verification -->/{s=1; print; next}
                    /<!-- \/vocabulary:declare -->/{s=0} s && /^\|/{next} {print}' \
                 "$d/$VOC" >"$d/v.t" && mv "$d/v.t" "$d/$VOC"
               check N20 2 "the verification dimension declared but EMPTY"
d=$(prep N21); edit "$d/$VOC" 's/^| `verified` |/| `signed-off` |/'
               check N21 2 "a 'verification' dimension without \`verified\`"

# --- rc=0: false positive and closing control ------------------------------
d=$(prep P1);  printf '\nA benign request from a legitimate user must still be verified by hand, and the `Secure` attribute stays on the cookie.\n' >>"$d/$OTHER"
               check P1 0 "FALSE-POSITIVE CONTROL: the same words as ordinary prose"
d=$(prep N22); check N22 0 "FINAL CONTROL: untouched copy again"

printf '\nSummary: %d ok, %d failure(s)\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
printf 'Result: OK. The gate fails when it must fail, stays quiet on correct prose,\n'
printf '        and distinguishes "could not measure" from "nothing to report".\n'
exit 0
