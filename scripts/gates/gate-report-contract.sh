#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gate-report-contract.sh — the deliverable contract, with teeth.
#
# WHY IT EXISTS
#   references/report.md carried two intentions that nothing enforced:
#     · "never display full secrets" — an instruction repeated in six agent
#       contracts and in SKILL.md rule 6. Instruction-level controls of that
#       class have already failed once in this operator's real delivery work,
#       which is the entire argument for moving it into a check.
#     · a coverage declaration, and now a ruled-out section: the two things that
#       make a deliverable an audit instead of a list of complaints. A mandatory
#       section that no one measures is mandatory until the first hurried edit.
#
# WHAT IT MEASURES  (two independent checks, one verdict)
#   A. THE SPECIFICATION. references/report.md still declares as mandatory the
#      sections and rules this gate holds in its own floor: the redaction pass
#      with its four placeholder classes, the ruled-out section with its three
#      parts, the coverage declaration with the rule that separates it from the
#      ruled-out list, plus the sections that were already there. Deleting a
#      section, dropping a rule, removing a placeholder class or downgrading a
#      mandatory section to conditional is a MEASURED failure (1).
#   B. THE DELIVERABLE. A scan for secret formats that can be recognised
#      offline, over what this plugin ships (the corpus and the agents) and,
#      with --deliverable, over the report about to be sent.
#
#   The floor lives HERE, in the gate, and not in the document it polices. If
#   the list of mandatory sections lived in report.md, deleting a line from
#   report.md would delete the check along with the requirement.
#
# WHY CHECKSUM-VALIDATED FORMATS AND NOT A GENERIC `password` REGEX
#   Because the deliverable's subject matter *is* passwords. A gate that greps
#   for password|secret|token|api[_-]?key inside a security report fires on
#   nearly every page of a correct one; its precision is near zero, it trains
#   the reader to ignore it, and it is switched off within a week — the same
#   failure mode already documented for gate-verdict-vocabulary.sh.
#
#   references/tooling.md carries the measurement this gate is built on:
#   format-specific patterns reached above 99% precision where entropy-based
#   detection did not (Meli et al., NDSS 2019), and GitHub tokens carry a CRC32
#   checksum, Base62-encoded in their last six characters, that validates
#   OFFLINE — no network call, no request to the provider, which is precisely
#   the action tooling.md forbids ("never test a credential against the real
#   service"). So the scanner keys on structure — prefix, exact length, charset
#   — and the checksum is used to CLASSIFY a hit, never to acquit one:
#
#     · checksum validates      -> `credential`   : treat as compromised, rotate.
#     · prefix and length match -> `token-shaped` : still a failure. A 40-char
#       token-shaped literal has no place in a deliverable; write the format
#       class, the length and the location instead.
#
#   The checksum never downgrades a hit to a pass for two reasons. The encoding
#   is reconstructed from the published format, not from a specification we can
#   execute against a real token (see "WHAT THIS GATE DOES NOT VERIFY"), and a
#   scanner whose acquittals depend on an inferred algorithm is a scanner that
#   fails silently in the one direction that matters.
#
#   That the choice is right is measured, not assumed: this repository's own
#   corpus teaches secret recognition, so
#   knowledge/supply-chain-secrets-malware.md and knowledge/ai-safety.md both
#   contain `ghp_`, `AKIA`, `xoxb-` and `sk-ant-` as prose. A prefix-only regex
#   would fail this gate on the two files that teach how to find secrets. The
#   length-gated patterns stay silent on them, and the clean fixture in
#   fixtures/report/good/ keeps that false-positive control running.
#
# WHAT THIS GATE DOES NOT VERIFY  (an unstated blind spot is how a gate ends up
# measuring nothing)
#   · That our CRC32/Base62 reconstruction matches GitHub's generator byte for
#     byte. We never had a real token to compare against and never will: that is
#     why a failed checksum still fails the gate. Both plausible Base62
#     alphabets are accepted, which errs towards flagging.
#   · Personal data, internal hostnames and weaponised payloads. They have no
#     format to key on. report.md states that in the same words, so nobody reads
#     silence here as coverage.
#   · Whether a real report's sections are complete. A deliverable is written in
#     the client's language with the client's headings; the report:section
#     markers belong to the specification. Checking an actual report becomes
#     possible with the findings artifact of backlog item 7.
#   · Repository-wide secret scanning. That is gitleaks' job, with its measured
#     46% precision; this gate is about what leaves in the deliverable.
#
# EXIT CODES (repo contract: an rc=0 never means "I did not check it")
#   0 = I MEASURED and it conforms
#   1 = I MEASURED and it FAILS
#   2 = I COULD NOT MEASURE (missing tool, missing input, a deliverable with
#       files I cannot read, a broken instrument). Never a pass.
#
# USAGE
#   scripts/gates/gate-report-contract.sh                      # spec + self-scan
#   scripts/gates/gate-report-contract.sh --deliverable PATH   # plus a deliverable
#   scripts/gates/gate-report-contract.sh --self-test          # only the battery
#   scripts/gates/gate-report-contract.sh --patterns           # list what it looks for
#
# ENVIRONMENT VARIABLES
#   EHS_REPO_ROOT     repo root (otherwise: git, otherwise the script's ancestor)
#   EHS_DELIVERABLE   same as --deliverable
#   GATE_SELFTEST=0   skips the battery. The verdict can then never be 0: a gate
#                     nobody saw fail is a gate nobody has tested.
#   EHS_SELFTEST_CHILD=1
#                     internal. Marks an invocation launched BY the battery, so
#                     it does not recurse. Unlike GATE_SELFTEST=0 it does not
#                     forfeit the 0, because the parent is the one proving the
#                     gate. Never set it by hand: outside the battery it means
#                     "run this gate without ever having tested it".
# ---------------------------------------------------------------------------
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/gates/lib/common.sh
. "$SELF_DIR/lib/common.sh"

FAILURES=0
N_CHECKED=0
SELFTEST_SKIPPED=0

ok()      { printf '  [OK]   %s\n' "$*"; N_CHECKED=$((N_CHECKED + 1)); }
fail()    { printf '  [FAIL] %s\n' "$*" >&2; N_CHECKED=$((N_CHECKED + 1)); FAILURES=$((FAILURES + 1)); }
info()    { printf '         %s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }

unmeasurable() {
  printf '\n[COULD NOT MEASURE] %s\n' "$*" >&2
  printf 'gate-report-contract: rc=2 (not a pass; it is the absence of a measurement)\n' >&2
  exit "$GATE_UNMEASURABLE"
}

# --- 0. arguments ----------------------------------------------------------
DELIVERABLE="${EHS_DELIVERABLE:-}"
ONLY_SELFTEST=0
LIST_PATTERNS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --deliverable) DELIVERABLE="${2:-}"; shift 2 || true ;;
    --self-test)   ONLY_SELFTEST=1; shift ;;
    --patterns)    LIST_PATTERNS=1; shift ;;
    -h|--help)     sed -n '2,110p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) unmeasurable "unknown argument: $1" ;;
  esac
done

# --- 1. tools --------------------------------------------------------------
for tool in awk grep sed find sort mktemp cp; do
  command -v "$tool" >/dev/null 2>&1 || unmeasurable "the tool '$tool' is missing"
done

TMPD="$(mktemp -d 2>/dev/null || mktemp -d -t ehsreport)" \
  || unmeasurable "I could not create a temporary directory"
cleanup() { [ -n "${TMPD:-}" ] && command rm -rf "$TMPD" 2>/dev/null; }
trap cleanup EXIT

# --- 2. repository root ----------------------------------------------------
if [ -n "${EHS_REPO_ROOT:-}" ]; then
  ROOT="$EHS_REPO_ROOT"
elif ROOT=$(git -C "$SELF_DIR" rev-parse --show-toplevel 2>/dev/null); then
  :
else
  ROOT="$(cd "$SELF_DIR/../.." && pwd)"
fi
[ -d "$ROOT/skills" ] || unmeasurable \
  "I cannot find skills/ under '$ROOT' (wrong cwd? this is not the plugin repo)"

REFS="skills/ethical-hacker-squad/references"
SPEC_REL="$REFS/report.md"
SPEC="$ROOT/$SPEC_REL"
GOOD_FIXTURES="$ROOT/scripts/gates/fixtures/report/good"

# ---------------------------------------------------------------------------
# THE MANDATORY FLOOR. Held here on purpose: a floor stored inside the document
# it polices disappears with the same edit that breaks the rule.
# ---------------------------------------------------------------------------
REQUIRED_SECTIONS='redaction-pass
executive-summary
scope-and-method
findings
ruled-out
coverage-declaration
verification
residual-risk'

# Declared sections whose class is NOT mandatory. Listed one by one so that a
# section cannot be quietly demoted into "conditional" and disappear from the
# floor: to move one here you have to edit this gate.
CONDITIONAL_SECTIONS='changes-made'

# rule-id@section-it-must-live-in
REQUIRED_RULES='redaction.classes@redaction-pass
redaction.no-partial-secret@redaction-pass
redaction.payload-annex@redaction-pass
redaction.self-check@redaction-pass
ruled-out.tested-and-absent@ruled-out
ruled-out.depth@ruled-out
ruled-out.resisted@ruled-out
ruled-out.regression-test@ruled-out
coverage.gaps@coverage-declaration'

# The closed set of placeholder classes. Item 4 of the backlog names exactly
# these four surfaces: secrets, PII, internal hosts and weaponised payload
# parameters.
REDACTION_CLASSES='[REDACTED:secret]
[REDACTED:pii]
[REDACTED:internal-host]
[REDACTED:payload]'

# What the self-scan covers: what this plugin ships to a user. Each entry must
# exist; a scan path that vanished makes the scan unmeasurable rather than
# quietly smaller.
SCAN_PATHS='skills
agents
README.md
scripts/gates/fixtures/report/good'

# Text extensions the scanner reads.
TEXT_EXT='md|txt|json|yml|yaml|html|htm|csv|log|sarif|xml'

# ---------------------------------------------------------------------------
# THE SECRET FORMATS. Three TAB-separated fields: id, regex, note. The separator
# is a tab and not a pipe because half of these regexes contain a pipe, and a
# table whose delimiter appears inside its own data is a bug waiting for the
# first alternation someone adds.
#
# Every pattern is length-gated: a bare prefix never matches. That single rule
# is what keeps the gate silent on the corpus files that teach secret detection.
# ---------------------------------------------------------------------------
PATTERNS="$(cat <<'PATEOF'
github-token	gh[pousr]_[A-Za-z0-9]{36}	classic GitHub token, 40 chars, CRC32 checksum verifiable offline
github-pat-fine	github_pat_[A-Za-z0-9_]{60,}	fine-grained GitHub PAT
aws-access-key-id	(AKIA|ASIA|AROA|AIDA)[A-Z0-9]{16}	AWS access key id, high precision by prefix, no published checksum
anthropic-key	sk-ant-[A-Za-z0-9_-]{24,}	Anthropic API key
openai-key	sk-(proj-)?[A-Za-z0-9]{32,}	OpenAI API key
slack-token	xox[baprse]-[A-Za-z0-9-]{16,}	Slack token
google-api-key	AIza[A-Za-z0-9_-]{35}	Google API key
stripe-secret-key	sk_live_[A-Za-z0-9]{16,}	Stripe live secret key
gitlab-pat	glpat-[A-Za-z0-9_-]{20}	GitLab personal access token
npm-token	npm_[A-Za-z0-9]{36}	npm automation token
private-key-block	-----BEGIN [A-Z ]*PRIVATE KEY-----	PEM private key header
signed-jwt	eyJ[A-Za-z0-9_-]{8,}\.eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{16,}	signed JWT; the third segment must be present, so an alg:none teaching example does not match
PATEOF
)"

if [ "$LIST_PATTERNS" -eq 1 ]; then
  while IFS="$(printf '\t')" read -r id re note; do
    [ -n "$id" ] || continue
    printf '%-20s %s\n%-20s %s\n' "$id" "$re" "" "$note"
  done <<EOF
$PATTERNS
EOF
  exit 0
fi

# ---------------------------------------------------------------------------
# THE INSTRUMENT: CRC32 (IEEE, reflected) and Base62, in POSIX awk.
#
# No bitwise builtins are used: the one-true-awk shipped with macOS has none, so
# xor is arithmetic. Written to disk once and reused by every scan.
# ---------------------------------------------------------------------------
AWK_CRC="$TMPD/crc.awk"
cat >"$AWK_CRC" <<'AWKEOF'
function xor32(a, b,   r, p, ab, bb) {
  r = 0; p = 1;
  while (a > 0 || b > 0) {
    ab = a % 2; bb = b % 2;
    if (ab != bb) r += p;
    a = int(a / 2); b = int(b / 2); p *= 2;
  }
  return r;
}
function crc32(s,   i, n, c, crc, k) {
  crc = 4294967295;                      # 0xFFFFFFFF
  n = length(s);
  for (i = 1; i <= n; i++) {
    c = ORD[substr(s, i, 1)];
    crc = xor32(crc, c);
    for (k = 0; k < 8; k++) {
      if (crc % 2 == 1) crc = xor32(int(crc / 2), 3988292384);   # 0xEDB88320
      else crc = int(crc / 2);
    }
  }
  return xor32(crc, 4294967295);
}
function b62(x, alpha,   r) {
  if (x == 0) r = "0";
  r = "";
  while (x > 0) { r = substr(alpha, (x % 62) + 1, 1) r; x = int(x / 62); }
  while (length(r) < 6) r = "0" r;       # GitHub pads the checksum to 6 chars
  return r;
}
function initord(   i) { for (i = 1; i < 256; i++) ORD[sprintf("%c", i)] = i; }
BEGIN {
  initord();
  # Two plausible Base62 orderings. The published format says "Base62-encoded
  # CRC32" without pinning the alphabet, so both are accepted: erring towards
  # flagging costs a 3.6e-11 chance of a coincidental match and buys immunity to
  # having guessed the ordering wrong.
  A1 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
  A2 = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
}
AWKEOF

# --- 3. the instrument checks itself before it is used ---------------------
# CRC-32/ISO-HDLC published check value: crc32("123456789") = 0xCBF43926.
CRC_SELFCHECK="$(printf '' | awk -f "$AWK_CRC" -e 'BEGIN { print crc32("123456789"); exit }' 2>/dev/null)"
if [ -z "$CRC_SELFCHECK" ]; then
  # -e is not portable to every awk; fall back to appending the driver.
  cat "$AWK_CRC" >"$TMPD/crcself.awk"
  printf 'BEGIN { print crc32("123456789"); exit }\n' >>"$TMPD/crcself.awk"
  CRC_SELFCHECK="$(printf '' | awk -f "$TMPD/crcself.awk" 2>/dev/null)"
fi
[ "$CRC_SELFCHECK" = "3421780262" ] || unmeasurable \
  "my CRC32 does not reproduce the published check value (got '${CRC_SELFCHECK:-nothing}', expected 3421780262): the instrument is broken, so nothing it says about a checksum can be trusted"

# ---------------------------------------------------------------------------
# scan_files <output-file> <file-list-file>
#   Emits: class<TAB>format-id<TAB>path<TAB>line
#   NEVER emits the matched text. A gate that prints the secret it found in the
#   CI log has moved the leak, not stopped it.
# ---------------------------------------------------------------------------
SCAN_AWK="$TMPD/scan.awk"
cat "$AWK_CRC" >"$SCAN_AWK"
cat >>"$SCAN_AWK" <<'AWKEOF'
function classify(m,   body, sum) {
  if (m ~ /^gh[pousr]_/ && length(m) == 40) {
    body = substr(m, 5, 30); sum = substr(m, 35, 6);
    if (sum == b62(crc32(body), A1) || sum == b62(crc32(body), A2))
      return "credential\tgithub-token";
    return "token-shaped\tgithub-token";
  }
  if (m ~ /^github_pat_/)                 return "high-precision\tgithub-pat-fine";
  if (m ~ /^(AKIA|ASIA|AROA|AIDA)/)       return "high-precision\taws-access-key-id";
  if (m ~ /^sk-ant-/)                     return "high-precision\tanthropic-key";
  if (m ~ /^sk-/)                         return "high-precision\topenai-key";
  if (m ~ /^xox/)                         return "high-precision\tslack-token";
  if (m ~ /^AIza/)                        return "high-precision\tgoogle-api-key";
  if (m ~ /^sk_live_/)                    return "high-precision\tstripe-secret-key";
  if (m ~ /^glpat-/)                      return "high-precision\tgitlab-pat";
  if (m ~ /^npm_/)                        return "high-precision\tnpm-token";
  if (m ~ /^-----BEGIN/)                  return "high-precision\tprivate-key-block";
  if (m ~ /^eyJ/)                         return "high-precision\tsigned-jwt";
  return "high-precision\tunclassified";
}
{
  p1 = index($0, ":"); if (p1 == 0) next;
  path = substr($0, 1, p1 - 1); rest = substr($0, p1 + 1);
  p2 = index(rest, ":"); if (p2 == 0) next;
  ln = substr(rest, 1, p2 - 1); m = substr(rest, p2 + 1);
  printf "%s\t%s\t%s\n", classify(m), path, ln;
}
AWKEOF

GREP_ARGS=""
build_grep_args() {
  GREP_ARGS=""
  local id re note
  while IFS="$(printf '\t')" read -r id re note; do
    [ -n "$id" ] || continue
    GREP_ARGS="$GREP_ARGS
$re"
  done <<EOF
$PATTERNS
EOF
}
build_grep_args

# scan_list <file-with-NUL-separated-paths> <hits-out>
scan_list() {
  local list="$1" out="$2" err="$TMPD/grep.err" args=()
  : >"$out"
  [ -s "$list" ] || return 0
  local re
  while IFS= read -r re; do
    [ -n "$re" ] || continue
    args+=(-e "$re")
  done <<EOF
$GREP_ARGS
EOF
  : >"$err"
  LC_ALL=C xargs -0 grep -onHE "${args[@]}" -- <"$list" >"$TMPD/hits.raw" 2>"$err"
  # grep exits 1 when there is nothing to find; that is a measurement, not an
  # error. Anything written to stderr is an error and must not be swallowed.
  if [ -s "$err" ]; then
    unmeasurable "the scanner could not read part of its input: $(head -3 "$err" | tr '\n' ' ')"
  fi
  awk -f "$SCAN_AWK" "$TMPD/hits.raw" >"$out" 2>/dev/null \
    || unmeasurable "the classifier failed over the scanner output"
  return 0
}

# collect <root> <relative-paths> -> writes $TMPD/files.list (NUL-separated),
# $TMPD/skipped.list, and sets N_FILES.
#
# No pipe into the loop: a `find | while read` in a subshell loses every counter
# it increments, and a counter that silently returns to zero is how a scan comes
# to measure nothing while still printing a verdict.
collect() {
  local base="$1" rels="$2"
  : >"$TMPD/files.list"; : >"$TMPD/skipped.list"; : >"$TMPD/files.raw0"
  N_FILES=0
  local p target f ext
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    target="$base/$p"
    if [ ! -e "$target" ]; then
      printf 'MISSING %s\n' "$p" >>"$TMPD/skipped.list"
      continue
    fi
    find "$target" -type f ! -name '.*' -print0 >>"$TMPD/files.raw0" 2>/dev/null
  done <<EOF
$rels
EOF
  while IFS= read -r -d '' f; do
    [ "$f" = "${BASH_SOURCE[0]}" ] && continue     # never scan the gate's own source
    ext="${f##*.}"
    if printf '%s' "$ext" | grep -qE "^($TEXT_EXT)$"; then
      printf '%s\0' "$f" >>"$TMPD/files.list"
      N_FILES=$((N_FILES + 1))
    else
      printf 'NOT-TEXT %s\n' "$f" >>"$TMPD/skipped.list"
    fi
  done <"$TMPD/files.raw0"
}

# ===========================================================================
# CHECK A — THE SPECIFICATION
# ===========================================================================
check_spec() {
  section "A. the specification: $SPEC_REL"
  [ -f "$SPEC" ] || unmeasurable "$SPEC_REL does not exist: there is no deliverable contract to check"
  [ -r "$SPEC" ] || unmeasurable "$SPEC_REL is not readable"

  # One awk pass, one process. The earlier version spawned an awk per floor
  # entry — twenty-five of them per run, multiplied by every case of the
  # battery. A gate slow enough to annoy is a gate someone removes from CI.
  local ev="$TMPD/spec.verdicts"
  awk \
    -v REQ="$(printf '%s' "$REQUIRED_SECTIONS" | tr '\n' ' ')" \
    -v COND="$(printf '%s' "$CONDITIONAL_SECTIONS" | tr '\n' ' ')" \
    -v RULES="$(printf '%s' "$REQUIRED_RULES" | tr '\n' ' ')" \
    -v CLASSES="$(printf '%s' "$REDACTION_CLASSES" | tr '\n' ' ')" \
    -v SPEC="$SPEC_REL" '
    function bad(msg, line) { nbad++; BADMSG[nbad] = SPEC ":" line " — " msg }
    function OK(m)   { print "OK\t" m }
    function FAILM(m){ print "FAIL\t" m }
    BEGIN { cur = "-" }
    /^<!-- report:section / {
      if (NF != 5 || $3 !~ /^id=/ || $4 !~ /^class=/ || $5 != "-->") {
        bad("malformed section marker", NR); next
      }
      if (cur != "-") bad("section " $3 " opens inside " cur, NR)
      id = substr($3, 4); cls = substr($4, 7)
      if (cls != "mandatory" && cls != "conditional") {
        bad("unknown class \"" cls "\" on section " id, NR); next
      }
      cur = id; SEEN[id]++; CLS[id] = cls; next
    }
    /^<!-- \/report:section / {
      if (cur == "-") bad("closing marker without an open section", NR)
      cur = "-"; next
    }
    /^<!-- report:rule / {
      if (NF != 4 || $4 != "-->") { bad("malformed rule marker", NR); next }
      if (!($3 in RSEC)) RSEC[$3] = cur
      pending = $3; next
    }
    {
      if (pending != "" && $0 !~ /^[[:space:]]*$/) {
        if ($0 ~ /^<!--/) bad("rule " pending " has no text under it", NR)
        pending = ""
      }
      if (cur != "-") {
        n = split(CLASSES, CL, " ")
        for (i = 1; i <= n; i++) if (index($0, CL[i])) HASCLASS[CL[i] "@" cur] = 1
        if (index($0, "gate-report-contract.sh")) HASGATE[cur] = 1
      }
    }
    END {
      if (pending != "") bad("rule " pending " has no text under it", "EOF")
      if (cur != "-")    bad("section " cur " is never closed", "EOF")

      if (nbad > 0) { for (i = 1; i <= nbad; i++) FAILM(BADMSG[i]) }
      else OK("every report:section / report:rule marker is well formed, closed and not nested")

      n = split(REQ, A, " ")
      for (i = 1; i <= n; i++) {
        s = A[i]; if (s == "") continue
        if (!(s in SEEN))       { FAILM(SPEC " no longer declares the mandatory section \"" s "\""); continue }
        if (SEEN[s] > 1)        { FAILM("section \"" s "\" is declared " SEEN[s] " times"); continue }
        if (CLS[s] != "mandatory")
          FAILM("section \"" s "\" is declared \"" CLS[s] "\": a mandatory section cannot be downgraded from inside the document it governs")
        else OK("section \"" s "\" is present and mandatory")
      }

      n = split(COND, A, " ")
      for (i = 1; i <= n; i++) {
        s = A[i]; if (s == "") continue
        if (!(s in SEEN)) { FAILM("the declared section \"" s "\" has disappeared from " SPEC); continue }
        if (CLS[s] != "conditional")
          FAILM("section \"" s "\" is declared \"" CLS[s] "\" but this gate lists it as conditional: change the gate, not only the document")
        else OK("section \"" s "\" is present and conditional, as declared here")
      }

      n = split(RULES, A, " ")
      for (i = 1; i <= n; i++) {
        r = A[i]; if (r == "") continue
        p = index(r, "@"); rid = substr(r, 1, p - 1); rsec = substr(r, p + 1)
        if (!(rid in RSEC)) { FAILM("the mandatory rule \"" rid "\" is no longer declared in " SPEC); continue }
        if (RSEC[rid] != rsec)
          FAILM("rule \"" rid "\" now sits in section \"" RSEC[rid] "\"; it only means anything inside \"" rsec "\"")
        else OK("rule \"" rid "\" is declared inside \"" rsec "\"")
      }

      n = split(CLASSES, A, " ")
      for (i = 1; i <= n; i++) {
        c = A[i]; if (c == "") continue
        if (HASCLASS[c "@redaction-pass"]) OK("the placeholder class " c " is defined inside the redaction section")
        else FAILM("the placeholder class " c " is no longer defined inside the redaction section: a class nobody declares is a category nobody redacts")
      }

      if (HASGATE["redaction-pass"]) OK("the redaction section still tells the operator how to run this check")
      else FAILM("the redaction section no longer names gate-report-contract.sh: a mechanism nobody is told to run is prose again")
    }
  ' "$SPEC" >"$ev" || unmeasurable "I could not parse $SPEC_REL"

  [ -s "$ev" ] || unmeasurable "the specification parser produced no verdict at all over $SPEC_REL"

  local verdict msg
  while IFS="$(printf '\t')" read -r verdict msg; do
    case "$verdict" in
      OK)   ok "$msg" ;;
      FAIL) fail "$msg" ;;
    esac
  done <"$ev"
}

# ===========================================================================
# CHECK B — THE SECRET SCAN
# ===========================================================================
report_hits() { # report_hits <hits-file> <label>
  local hits="$1" label="$2" n
  n="$(wc -l <"$hits" | tr -d ' ')"
  if [ "$n" -eq 0 ]; then
    ok "$label: 0 hits over $(printf '%s' "$N_FILES") file(s)"
    return 0
  fi
  while IFS=$'\t' read -r cls fid path line; do
    case "$cls" in
      credential)
        fail "$path:$line — $fid whose checksum validates offline. Treat it as compromised and rotate it; the deliverable must carry [REDACTED:secret] plus the format class, the length and this location." ;;
      token-shaped)
        fail "$path:$line — $fid: prefix and exact length match, checksum does not validate. Not a live token, and still a failure: a token-shaped literal has no place in a deliverable." ;;
      *)
        fail "$path:$line — $fid: a high-precision format with no offline checksum. Replace it with [REDACTED:secret] plus format class and location; assume it is live until the owner says otherwise." ;;
    esac
  done <"$hits"
  return 1
}

N_FILES=0

check_selfscan() {
  section "B. secret formats in what this plugin ships"
  [ -d "$GOOD_FIXTURES" ] || unmeasurable \
    "the false-positive control $GOOD_FIXTURES is missing: without it I cannot show that the scanner stays quiet on correct text"

  : >"$TMPD/files.raw0"
  collect "$ROOT" "$SCAN_PATHS"
  if grep -q '^MISSING ' "$TMPD/skipped.list" 2>/dev/null; then
    unmeasurable "a declared scan path does not exist: $(grep '^MISSING ' "$TMPD/skipped.list" | tr '\n' ' ')"
  fi
  [ "$N_FILES" -gt 0 ] || unmeasurable "the scan path list produced no file to read"
  info "scanned: $(printf '%s' "$SCAN_PATHS" | tr '\n' ' ')"
  info "out of scope here: docs/ and scripts/ (internal material, not the deliverable); a whole-repository secret scan is gitleaks' job"
  scan_list "$TMPD/files.list" "$TMPD/hits.self"
  report_hits "$TMPD/hits.self" "self-scan"
  if [ -s "$TMPD/skipped.list" ]; then
    info "not read (no text extension): $(grep -c '^NOT-TEXT' "$TMPD/skipped.list" || true) file(s) — listed, never silently skipped"
    grep '^NOT-TEXT' "$TMPD/skipped.list" | sed 's/^/           /' || true
  fi
}

check_deliverable() {
  [ -n "$DELIVERABLE" ] || return 0
  section "B'. the deliverable: $DELIVERABLE"
  [ -e "$DELIVERABLE" ] || unmeasurable \
    "the deliverable '$DELIVERABLE' does not exist: I cannot certify what I cannot read"
  : >"$TMPD/files.raw0"
  if [ -d "$DELIVERABLE" ]; then
    collect "$DELIVERABLE" "."
  else
    collect "$(dirname "$DELIVERABLE")" "$(basename "$DELIVERABLE")"
  fi
  [ "$N_FILES" -gt 0 ] && info "reading $N_FILES file(s)"
  if [ -s "$TMPD/skipped.list" ]; then
    grep '^NOT-TEXT' "$TMPD/skipped.list" | sed 's/^NOT-TEXT /           /' || true
    unmeasurable "part of the deliverable is in a format I do not read (listed above). In deliverable mode that is a 2: an unread file is an unchecked file, and this contract is about everything that leaves."
  fi
  [ "$N_FILES" -gt 0 ] || unmeasurable "the deliverable contains no readable file"
  scan_list "$TMPD/files.list" "$TMPD/hits.deliv"
  report_hits "$TMPD/hits.deliv" "deliverable"
}

# ===========================================================================
# THE BATTERY. It runs on every invocation: a gate nobody has seen fail is a
# gate nobody has tested. GATE_SELFTEST=0 skips it and forfeits the 0.
# ===========================================================================
mk_fake_root() { # mk_fake_root <dir>
  local t="$1"
  mkdir -p "$t/$REFS" "$t/agents" "$t/scripts/gates/fixtures/report/good"
  cp "$SPEC" "$t/$SPEC_REL"
  cp "$ROOT/README.md" "$t/README.md" 2>/dev/null || printf '# placeholder\n' >"$t/README.md"
  cp "$GOOD_FIXTURES"/*.md "$t/scripts/gates/fixtures/report/good/" 2>/dev/null || true
  printf 'placeholder agent\n' >"$t/agents/placeholder.md"
}

run_child() { # run_child <fake-root> [args...]; echoes rc
  local t="$1"; shift
  # EHS_SELFTEST_CHILD, not GATE_SELFTEST=0: the second one forfeits the 0 by
  # design, so every child would return 2 and the battery would only ever be
  # able to prove "2". That is exactly the bug this battery caught in itself on
  # its first run.
  EHS_SELFTEST_CHILD=1 EHS_REPO_ROOT="$t" EHS_DELIVERABLE="" \
    bash "${BASH_SOURCE[0]}" "$@" >"$TMPD/child.out" 2>&1
  printf '%s' "$?"
}

ST_FAIL=0
expect() { # expect <label> <expected-rc> <actual-rc>
  if [ "$2" = "$3" ]; then
    printf '  [self-test OK]   %-46s rc=%s\n' "$1" "$3"
  else
    printf '  [self-test FAIL] %-46s rc=%s (expected %s)\n' "$1" "$3" "$2" >&2
    sed 's/^/      | /' "$TMPD/child.out" >&2
    ST_FAIL=$((ST_FAIL + 1))
  fi
}

# A fictitious 40-character GitHub token whose checksum validates under our own
# reconstruction. Built here, never committed: a checksum-valid literal in the
# tree is exactly the string this repository tells everyone not to commit, and
# it would be flagged by every scanner that reads the repository afterwards.
make_token() { # make_token <30-char-body> -> prints the 40-char token
  local body="$1" sum
  cat "$AWK_CRC" >"$TMPD/mk.awk"
  printf 'BEGIN { print b62(crc32(BODY), A1); exit }\n' >>"$TMPD/mk.awk"
  sum="$(awk -v BODY="$body" -f "$TMPD/mk.awk" </dev/null)"
  printf 'ghp_%s%s' "$body" "$sum"
}

self_test() {
  section "self-test: the battery this gate has to survive"
  local t rc body tok tok_shaped
  body="EhsFixtureNotARealToken000001x"        # exactly 30 chars

  # 0. control: an untouched copy must be green.
  t="$TMPD/st0"; mk_fake_root "$t"
  rc="$(run_child "$t")"; expect "control: untouched copy" 0 "$rc"

  # 1. a mandatory section deleted from the spec.
  t="$TMPD/st1"; mk_fake_root "$t"
  sed '/report:section id=ruled-out/d' "$SPEC" >"$t/$SPEC_REL"
  rc="$(run_child "$t")"; expect "mandatory section removed" 1 "$rc"

  # 2. a mandatory section downgraded to conditional.
  t="$TMPD/st2"; mk_fake_root "$t"
  sed 's/id=coverage-declaration class=mandatory/id=coverage-declaration class=conditional/' \
      "$SPEC" >"$t/$SPEC_REL"
  rc="$(run_child "$t")"; expect "mandatory section downgraded" 1 "$rc"

  # 3. a required rule marker deleted.
  t="$TMPD/st3"; mk_fake_root "$t"
  sed '/report:rule ruled-out.regression-test/d' "$SPEC" >"$t/$SPEC_REL"
  rc="$(run_child "$t")"; expect "required rule removed" 1 "$rc"

  # 4. a placeholder class deleted.
  t="$TMPD/st4"; mk_fake_root "$t"
  sed 's/\[REDACTED:payload\]//g' "$SPEC" >"$t/$SPEC_REL"
  rc="$(run_child "$t")"; expect "placeholder class removed" 1 "$rc"

  # 5. a malformed marker.
  t="$TMPD/st5"; mk_fake_root "$t"
  sed 's/<!-- report:section id=findings class=mandatory -->/<!-- report:section findings -->/' \
      "$SPEC" >"$t/$SPEC_REL"
  rc="$(run_child "$t")"; expect "malformed section marker" 1 "$rc"

  # 6. the spec itself is missing -> 2, never 0.
  t="$TMPD/st6"; mk_fake_root "$t"; mv "$t/$SPEC_REL" "$t/$SPEC_REL.moved"
  rc="$(run_child "$t")"; expect "spec absent" 2 "$rc"

  # 7. POSITIVE CONTROL: a fictitious token whose checksum validates.
  t="$TMPD/st7"; mk_fake_root "$t"
  tok="$(make_token "$body")"
  printf 'evidence: %s\n' "$tok" >"$t/agents/leak.md"
  rc="$(run_child "$t")"; expect "checksum-valid fictitious token" 1 "$rc"
  grep -q 'checksum validates offline' "$TMPD/child.out" \
    || { printf '  [self-test FAIL] the token was caught but not classified as a credential\n' >&2
         ST_FAIL=$((ST_FAIL + 1)); }

  # 8. same shape, checksum deliberately wrong.
  t="$TMPD/st8"; mk_fake_root "$t"
  tok_shaped="ghp_${body}zzzzzz"
  printf 'evidence: %s\n' "$tok_shaped" >"$t/agents/leak.md"
  rc="$(run_child "$t")"; expect "token-shaped, checksum invalid" 1 "$rc"

  # 9. a format with no offline checksum.
  t="$TMPD/st9"; mk_fake_root "$t"
  printf 'evidence: AKIA%s\n' "IOSFODNN7EXAMPLE" >"$t/agents/leak.md"
  rc="$(run_child "$t")"; expect "high-precision prefix format" 1 "$rc"

  # 10. FALSE-POSITIVE CONTROL: the text this corpus is full of.
  t="$TMPD/st10"; mk_fake_root "$t"
  {
    printf 'Prefixes taught in the corpus: ghp_, gho_, AKIA, sk-ant-, xoxb-, AIza.\n'
    printf 'Redacted evidence: [REDACTED:secret] (a GitHub token, ghp_, 40 chars).\n'
    printf 'A 35-char body is one short: ghp_%s\n' "EhsFixtureNotARealToken00000x"
    printf 'alg:none teaching example: eyJhbGciOiJub25lIn0.eyJzdWIiOiIxIn0.\n'
    printf 'A UUID and a hash: 8f14e45f-ea2c-4c07-8b1a-4b0c2f9d1e77 %s\n' \
           "da39a3ee5e6b4b0d3255bfef95601890afd80709"
  } >"$t/agents/legit.md"
  rc="$(run_child "$t")"; expect "false-positive control (ordinary text)" 0 "$rc"

  # 11. deliverable mode: the path does not exist.
  t="$TMPD/st11"; mk_fake_root "$t"
  rc="$(run_child "$t" --deliverable "$t/there-is-no-such-report")"
  expect "deliverable absent" 2 "$rc"

  # 12. deliverable mode: a file it cannot read is not a pass.
  t="$TMPD/st12"; mk_fake_root "$t"; mkdir -p "$t/deliv"
  printf '# report\n' >"$t/deliv/report.md"; printf '\001\002\003' >"$t/deliv/evidence.bin"
  rc="$(run_child "$t" --deliverable "$t/deliv")"
  expect "deliverable with an unreadable file" 2 "$rc"

  # 13. deliverable mode: clean report -> 0; leaking report -> 1.
  t="$TMPD/st13"; mk_fake_root "$t"; mkdir -p "$t/deliv"
  printf '# report\n\nEvidence: [REDACTED:secret] at src/app.py:12 (ghp_ prefix, 40 chars).\n' \
    >"$t/deliv/report.md"
  rc="$(run_child "$t" --deliverable "$t/deliv")"; expect "clean deliverable" 0 "$rc"
  printf 'Evidence: %s\n' "$tok" >>"$t/deliv/report.md"
  rc="$(run_child "$t" --deliverable "$t/deliv")"; expect "leaking deliverable" 1 "$rc"

  # 14. the false-positive control fixture itself disappears -> 2.
  t="$TMPD/st14"; mk_fake_root "$t"
  mv "$t/scripts/gates/fixtures/report/good" "$t/scripts/gates/fixtures/report/gone"
  rc="$(run_child "$t")"; expect "false-positive control missing" 2 "$rc"

  [ "$ST_FAIL" -eq 0 ] || return 1
  return 0
}

# ===========================================================================
# MAIN
# ===========================================================================
gate_header "report-contract"
gate_scope "report.md still declares its mandatory sections, rules and placeholder classes; and no offline-recognisable secret format appears in what we ship (or in --deliverable)"
gate_out_of_scope "PII, internal hostnames and payloads (no format to key on); whether a real report's prose is honest; repository-wide secret scanning"

if [ "$ONLY_SELFTEST" -eq 1 ]; then
  if self_test; then
    printf '\ngate-report-contract: self-test passed\n'; gate_verdict 0; exit "$GATE_OK"
  fi
  printf '\ngate-report-contract: the gate does NOT pass its own battery\n' >&2
  gate_verdict 1; exit "$GATE_FAIL"
fi

check_spec
check_selfscan
check_deliverable

BATTERY_OK=1
if [ "${EHS_SELFTEST_CHILD:-0}" = "1" ]; then
  : # a case of the battery: it must not run the battery again, and that is not
    # a skip — the parent is the one proving the gate.
elif [ "${GATE_SELFTEST:-1}" != "0" ]; then
  self_test || BATTERY_OK=0
else
  SELFTEST_SKIPPED=1
fi

section "summary"
info "$N_CHECKED check(s) over the specification and the shipped corpus"

# ---------------------------------------------------------------------------
# VERDICT PRECEDENCE. A MEASURED failure outranks a broken instrument, and both
# outrank silence.
#
# The order matters here for a concrete reason: the battery's baseline case is a
# copy of the live report.md. Break the specification and that baseline breaks
# with it, so the battery starts failing as a CONSEQUENCE of the failure the run
# has already measured. Letting the battery win would answer "I could not
# measure" to a question that was just measured, and would replace a precise
# diagnosis ("you deleted the ruled-out section") with a vague one.
# ---------------------------------------------------------------------------
if [ "$FAILURES" -gt 0 ]; then
  if [ "$BATTERY_OK" -eq 0 ]; then
    info "the battery also failed. Its baseline is the very specification this run just failed, so while the spec is broken the battery cannot be conclusive; the failures above are the measurement."
  fi
  printf '\ngate-report-contract: rc=1 — %d MEASURED failure(s)\n' "$FAILURES" >&2
  gate_verdict 1
  exit "$GATE_FAIL"
fi

if [ "$SELFTEST_SKIPPED" -eq 1 ]; then
  gate_warn "battery skipped via GATE_SELFTEST=0: an unproved gate cannot return 0"
  gate_verdict 2
  exit "$GATE_UNMEASURABLE"
fi

if [ "$BATTERY_OK" -eq 0 ]; then
  gate_warn "the gate does not pass its own battery, and nothing else failed: the instrument is broken, so the green above is worth nothing"
  gate_verdict 2
  exit "$GATE_UNMEASURABLE"
fi

printf '\ngate-report-contract: rc=0 — measured and conforming\n'
gate_verdict 0
exit "$GATE_OK"
