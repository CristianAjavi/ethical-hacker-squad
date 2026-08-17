# scripts/gates/lib/negative-evidence.awk
#
# Detector used by gate-negative-evidence.sh. Reads ONE markdown file and prints
# one record per finding:
#
#   FAIL|<file>|<line>|<rule>|<message>
#   UNMEAS|<file>|<line>|<rule>|<message>
#
# WHAT IT LOOKS FOR
#   Text that INSTRUCTS somebody to turn an absence of evidence into a
#   favourable verdict. Three shapes:
#
#   absence-inference   an absence signal ("no matches", "the suite passed",
#                       "does not reproduce") in the same block as a favourable
#                       conclusion ("is safe", "as fixed", "nothing there"),
#                       with nothing in the block rejecting the inference.
#   error-as-pass       a failure of the harness itself (build failed, command
#                       not found, exit 127, missing fixture) disposed of as a
#                       pass, a skip or something to ignore.
#   absence-as-verdict  one of the three terms that mean "no measurement"
#                       (inconclusive / not executed / blocked) written as
#                       markup and then equated with a favourable verdict.
#
# IT READS BLOCKS, NOT LINES
#   The corpus is hard-wrapped at about ninety columns, so the defect routinely
#   straddles a line break: "the suite passed, therefore the vulnerability\nis
#   fixed". A line-based detector misses exactly those and reports itself green.
#   Not a hypothesis - the first version was line-based and its own fixture
#   self-test caught it. So text is accumulated into blocks (a paragraph, a list
#   item, a table row, a heading) and each block is judged whole, at the line
#   where it starts. Table rows stay separate blocks on purpose: the verdict
#   tables of vocabulary.md put an absence term in one row and a conclusive term
#   in the next, and joining them would invent an inference nobody wrote.
#
# WHY THE FILTERING IS BUILT THIS WAY  (false positives are the whole design)
#   This repository argues against the inference on nearly every page: "a clean
#   scan is not evidence of absence" appears in the README, SKILL.md, tooling.md,
#   web-api.md, bibliography.md and two agent contracts. A detector that fired on
#   the TOPIC would flag ~20 correct lines on its first run and be deleted the
#   same day. So it fires on the ASSERTION, and four mechanisms keep it quiet on
#   the refusals:
#
#   1. TWO SIGNALS, NOT ONE. A block needs the absence AND the favourable
#      conclusion. "A clean scan is not evidence of absence" has the first and
#      not the second. (An inference connective - "so", "therefore", "treat as" -
#      was required at first as a third signal. It was dropped after MEASURING:
#      over the 52 markdown files of this repository, requiring it removed no
#      false positive whatsoever, and it lost the commonest phrasing of the real
#      defect, "if the scan returns no matches, the endpoint is safe", which
#      joins the two halves with a comma. A signal that suppresses nothing and
#      hides something is not a filter, it is a hole.)
#   2. REFUSAL CUES SUPPRESS. Searched AFTER masking the absence and conclusion
#      phrases, so the "not" inside "does not reproduce" or "not vulnerable"
#      cannot be mistaken for a refusal by the author. To reject the inference in
#      English you have to negate something, and that is what is looked for.
#   3. VERDICT TERMS ARE READ AS MARKUP, AS WHOLE TOKENS. absence-as-verdict
#      only counts terms written in backticks or bold, which is how this
#      repository writes every verdict; and the tokens are held in a
#      newline-delimited list so that `not verified` is ONE token and never a
#      sighting of `verified`. Both halves were needed: without the first, prose
#      about a pass reads as a verdict; without the second, competitive-analysis
#      line 503 fires on a table cell that states the opposite of the rule -
#      space-padding was not enough, because `not verified` has a space in it.
#   4. EVERY PATTERN IS LEFT-ANCHORED at a non-letter. Without it "declare"
#      matches "undeclared", "proves" matches "improves" and "thus" matches
#      "enthusiasm" - measured, not imagined; the first two happened on the first
#      run over this repository.
#
#   Everything the detector cannot see is declared by the gate, never implied.
#
# ESCAPE HATCH, WITH ITS OWN LOCK
#   A file that must quote the forbidden sentence in order to forbid it wraps it
#   in <!-- reach-proof:counterexample --> ... <!-- /reach-proof:counterexample -->.
#   Inside such a region the three rules are suspended. Two locks stop that from
#   becoming a way to smuggle an instruction in:
#     - the region must contain a refusal cue, or it is a FAIL
#       (counterexample-without-refusal): you may quote the bad sentence only in
#       the act of rejecting it;
#     - a region left open silences the rest of the file, so an unbalanced region
#       is UNMEAS (unbalanced-region), never a silent pass.
#
# INPUT
#   -v FILE=<path shown in the records>   (defaults to FILENAME)
#
# Portability: POSIX ERE only, no interval expressions {n,m} (the awk shipped
# with macOS does not implement them reliably), no gensub, no length(array).

BEGIN {
  if (FILE == "") FILE = FILENAME

  # Left boundary. awk ERE has no \b; this is the substitute, and it is applied
  # to every pattern below rather than to the ones that seemed to need it.
  B = "(^|[^a-z])"

  # --- absence signals: the check produced nothing ------------------------
  ABS = "(no|zero) (findings|finding|hits|hit|matches|match|results|result|output|errors|alerts)" \
        "|empty output|nothing (was )?(found|returned|reported)" \
        "|clean (scan|run|report|result|bill)|scan (is|was|came back|came out) clean" \
        "|(tests?|suite|build|pipeline|ci|scan|scanner) (pass|passes|passed|is green|are green|was green|succeeds|succeeded|is clean|are clean)" \
        "|(does|did) not reproduce|doesn't reproduce|no longer reproduces|failed to reproduce" \
        "|absence of (a |an )?(finding|output|error|alert)|the silence"

  # --- favourable conclusions --------------------------------------------
  # Bare "verified" / "fixed" are deliberately absent: they are the words the
  # verifier is supposed to write when it HAS the evidence. Only the forms that
  # assert the state ("is fixed", "as verified") count.
  CONC = "is secure|are secure|is safe|are safe|is fine|is clean|is fixed|are fixed|is resolved" \
         "|no vulnerabilit|not vulnerable|no weakness|no weaknesses|no bug|no bugs|no issue|no issues" \
         "|nothing there|nothing to report|no finding to report|not exploitable|is closed|can be closed" \
         "|as verified|as fixed|as safe|as clean|as secure|as a pass|as pass|as ok|as green|as resolved" \
         "|is verified|are verified"

  # --- connectives and imperatives (required by absence-as-verdict only) --
  CONN = "so( |,|$)|therefore|thus|hence|means( |,|$)|means that|which means" \
         "|implies|proves|prove that|confirms|demonstrates|shows that|it follows|=>|⇒|->|→" \
         "|then( |,|$)|because of that|on that basis|allows us to"
  IMPER = "treat|mark|record|classify|conclude|declare|count (it|them)|call (it|them)" \
          "|assume|set the (status|outcome|verdict)|write (it|them) (up )?as|sign off"

  # --- refusal cues: the author is rejecting the inference ----------------
  REFUSAL = "never|not the same|no evidence|nothing more|instead|rather than" \
            "|must not|cannot|can't|do not|don't|is not|are not|was not|were not|does not|is no |there is no" \
            "|forbidden|banned|refuse|is wrong|a defect|mistake|beware|fallacy|myth|error to|a trap"

  # --- error-as-pass ------------------------------------------------------
  ERRSIG = "(build|builds|test|tests|suite|command|script|check|harness|runner|it|they) (fail|fails|failed|error|errors|errored|crash|crashes|crashed)" \
           "|exit(s|ed)? (code )?(1|127)|non-?zero exit|exits? non-?zero|returns? non-?zero" \
           "|(command|binary|tool|file|fixture|target|dependency) (is )?(not found|missing|unavailable)" \
           "|missing (file|fixture|binary|tool|dependency|target)|could not (be )?run|cannot be run|does not exist"
  # The disposal verb must reach its favourable target WITHOUT crossing a comma,
  # a semicolon or a full stop. With a plain [^.]* gap this fired on
  # agents/ehs-remediator.md - "Write the test, run it against the unpatched
  # code, show it failing, then apply the patch and show it passing" - which is
  # not a disposal at all but the benign-control rule, correctly stated. A verb
  # and a good word in the same sentence are not a sentence that disposes of a
  # failure; the binding is what makes it one.
  BENIGN = "(treat|mark|record|report|count|consider|classify|call|write)[^.,;]*( as | to be )(a |an )?(pass|passing|ok|green|clean|fine|safe|secure|fixed|verified|success)" \
           "|skip (it|the|that)|ignore (it|the|that)|assume[^.,;]*(fine|safe|clean|ok|secure|passed|passing)" \
           "|move on|carry on|no need to (re-?run|investigate)"

  # --- absence-as-verdict -------------------------------------------------
  ABSTERM = "inconclusive|not executed|blocked"
  FAV     = "pass|passed|verified|partially verified|refuted|clean|secure|safe|fine|green|success|fixed|closed|ok"

  # Compiled forms.
  ABS_RE     = B "(" ABS ")"
  CONC_RE    = B "(" CONC ")"
  CONN_RE    = B "(" CONN ")"
  IMPER_RE   = B "(" IMPER ")"
  REFUSAL_RE = B "(" REFUSAL ")"
  ERRSIG_RE  = B "(" ERRSIG ")"
  BENIGN_RE  = B "(" BENIGN ")"
  ABSTOK_RE  = "\n(" ABSTERM ")\n"   # markup tokens, matched whole
  FAVTOK_RE  = "\n(" FAV ")\n"
  ABSTERM_RE = B "(" ABSTERM ")"     # prose forms, used only for masking
  FAV_RE     = B "(" FAV ")"

  # A line that opens a new block rather than continuing the previous one.
  BLOCK_START = "^[ \t]*($|#|\\||[-*+][ \t]|[0-9]+\\.[ \t]|>|```|~~~|<!--)"

  inside_ce = 0; ce_open_line = 0; ce_has_refusal = 0
  unit = ""; unit_mk = "\n"; unit_start = 0
}

# --------------------------------------------------------------------------
# block accumulation
# --------------------------------------------------------------------------
function add_line(text, n,    raw, t) {
  if (unit == "") { unit_start = n; unit = text; unit_mk = "\n" }
  else            { unit = unit " " text }

  raw = text
  while (match(raw, /`[^`]+`/)) {
    t = tolower(substr(raw, RSTART + 1, RLENGTH - 2))
    gsub(/^[ \t]+|[ \t.,;:]+$/, "", t)
    unit_mk = unit_mk t "\n"
    raw = substr(raw, RSTART + RLENGTH)
  }
  raw = text
  while (match(raw, /\*\*[^*]+\*\*/)) {
    t = tolower(substr(raw, RSTART + 2, RLENGTH - 4))
    gsub(/^[ \t]+|[ \t.,;:]+$/, "", t)
    unit_mk = unit_mk t "\n"
    raw = substr(raw, RSTART + RLENGTH)
  }
}

function flush(    l, masked, n, i, s, refctx) {
  if (unit == "") return
  l = tolower(unit)
  gsub(/[`*_"]/, " ", l)
  gsub(/[ \t]+/, " ", l)

  # REFUSAL CONTEXT. A negation only counts as the author rejecting the
  # inference if it sits in a sentence that is TALKING about the inference, so
  # refusals are searched over the signal-bearing sentences of the block and not
  # over the block as a whole. Both halves of that were measured:
  #   - block-wide was too generous. "If the build fails, mark the finding as
  #     verified and move on; a broken build is not our problem here" was
  #     suppressed by a negation about something else entirely.
  #   - sentence-only was too strict. remediation.md names the defect in one
  #     sentence ("treating the fix as verified because the test suite is
  #     green") and refuses it in the next; that file is correct and must stay
  #     silent, and it does, because the refusing sentence carries a signal too.
  n = split(l, s_arr, /[.;:] |[.;:]$/)
  refctx = ""
  for (i = 1; i <= n; i++) {
    s = s_arr[i]
    if (s ~ ABS_RE || s ~ CONC_RE || s ~ ERRSIG_RE || s ~ BENIGN_RE || s ~ ABSTERM_RE)
      refctx = refctx " " s " "
  }

  # --- rule 1: absence-inference -----------------------------------------
  if (l ~ ABS_RE && l ~ CONC_RE) {
    masked = refctx
    gsub(ABS_RE, " ", masked)
    gsub(CONC_RE, " ", masked)
    if (masked !~ REFUSAL_RE) {
      print "FAIL|" FILE "|" unit_start "|absence-inference|" \
            "this passage derives a favourable conclusion from an absence of evidence; a negative verdict needs a reach proof, and without one the outcome is inconclusive"
    }
  }

  # --- rule 2: error-as-pass ---------------------------------------------
  if (l ~ ERRSIG_RE && l ~ BENIGN_RE) {
    masked = refctx
    gsub(ERRSIG_RE, " ", masked)
    if (masked !~ REFUSAL_RE) {
      print "FAIL|" FILE "|" unit_start "|error-as-pass|" \
            "this passage disposes of a harness failure as a pass, a skip or something to ignore; a failure of the check is could-not-measure, never no-bug-found"
    }
  }

  # --- rule 3: absence-as-verdict ----------------------------------------
  # Here a connective IS required, and here it does suppress: the tables of
  # vocabulary.md legitimately name an absence term and a conclusive one at once.
  if (unit_mk ~ ABSTOK_RE && unit_mk ~ FAVTOK_RE && (l ~ CONN_RE || l ~ IMPER_RE)) {
    masked = refctx
    gsub(ABSTERM_RE, " ", masked)
    gsub(FAV_RE, " ", masked)
    if (masked !~ REFUSAL_RE) {
      print "FAIL|" FILE "|" unit_start "|absence-as-verdict|" \
            "this passage equates a term that means no-measurement with a favourable verdict; the three absence terms are the honest outcome, not a weaker version of a good one"
    }
  }

  unit = ""; unit_mk = "\n"; unit_start = 0
}

# --------------------------------------------------------------------------
# counterexample regions
# --------------------------------------------------------------------------
/<!--[ \t]*\/reach-proof:counterexample[ \t]*-->/ {
  flush()
  if (!inside_ce) {
    print "FAIL|" FILE "|" NR "|unbalanced-region|closing reach-proof:counterexample without an opening one"
  } else if (!ce_has_refusal) {
    print "FAIL|" FILE "|" ce_open_line "|counterexample-without-refusal|" \
          "this reach-proof:counterexample region quotes the forbidden inference without rejecting it anywhere inside; a counterexample that is not refused is an instruction"
  }
  inside_ce = 0; ce_has_refusal = 0
  next
}
/<!--[ \t]*reach-proof:counterexample[ \t]*-->/ {
  flush()
  if (inside_ce) {
    print "FAIL|" FILE "|" NR "|unbalanced-region|nested reach-proof:counterexample region"
  }
  inside_ce = 1; ce_open_line = NR; ce_has_refusal = 0
  next
}

inside_ce {
  if (tolower($0) ~ REFUSAL_RE) ce_has_refusal = 1
  next
}

# --------------------------------------------------------------------------
# every other line feeds the block accumulator
# --------------------------------------------------------------------------
{
  if ($0 ~ BLOCK_START) flush()
  if ($0 ~ /^[ \t]*$/) next
  add_line($0, NR)
}

END {
  flush()
  if (inside_ce) {
    print "UNMEAS|" FILE "|" ce_open_line "|unbalanced-region|" \
          "a reach-proof:counterexample region was opened and never closed: everything after it was excluded from the scan, so this file was not measured"
  }
}
