# ---------------------------------------------------------------------------
# workflow-triggers.awk - one line per workflow file: its name, whether it is
# triggered by `pull_request`, and whether that answer was actually parsed.
#
# Output, tab separated:   <file>  <name>  <yes|no>  <ok|unknown>
#
# The fourth field is the point. A workflow whose `on:` block is written in a
# shape this script does not understand reports `unknown`, and the caller is
# expected to treat that as COULD NOT MEASURE. Guessing `no` there would be the
# cheapest possible way to make a required workflow disappear from the
# requirement: the file stops being asked for, nothing goes red, and the reason
# is a parser that shrugged.
#
# WHAT IT UNDERSTANDS
#   on:                      block style, the only shape this repository uses
#     pull_request:          - a mapping key at two spaces
#     pull_request_target:   - counted separately; it is NOT pull_request
#
#   Anything else inside the `on:` block - flow style (`on: [pull_request]`),
#   a quoted key, an anchor - is reported as `unknown` rather than assumed.
#   `"on":` and `'on':` as the block header ARE understood, because YAML 1.1
#   readers turn a bare `on` into a boolean and some linters ask for the quotes.
#
# WHY NOT A YAML PARSER
#   Because the gates run on a machine with no third-party Python and the one
#   question asked here is answerable from column zero and two spaces. The
#   moment that stops being true the answer is `unknown`, not a wrong `no`.
# ---------------------------------------------------------------------------
BEGIN { FS = "\n" }

FNR == 1 {
  emit()
  file = FILENAME
  name = ""
  in_on = 0
  seen_pr = 0
  puzzled = 0
  saw_key = 0
  have_file = 1
}

# The workflow's display name - the string GitHub reports as the run's name,
# which is what a check list is matched against. A file with no `name:` is
# named after its path by GitHub, and that is a different string, so it is left
# empty here and the caller says so.
name == "" && /^name:[ \t]/ {
  name = $0
  sub(/^name:[ \t]+/, "", name)
  gsub(/^["']|["']$/, "", name)
  sub(/[ \t]+$/, "", name)
}

# The `on:` block opens at column zero. `on: [pull_request]` on the same line is
# flow style: understood well enough to know it is NOT understood.
/^("on"|'on'|on):/ {
  in_on = 1
  rest = $0
  sub(/^("on"|'on'|on):[ \t]*/, "", rest)
  if (rest != "" && rest !~ /^#/) puzzled = 1
  next
}

# Any other key at column zero closes it.
in_on && /^[^ \t#]/ { in_on = 0 }

in_on {
  line = $0
  if (line ~ /^[ \t]*$/ || line ~ /^[ \t]*#/) next
  # A mapping key at exactly two spaces is an event name. Deeper lines are that
  # event's own configuration and are none of this script's business.
  if (line ~ /^  [^ \t]/) {
    key = line
    sub(/^  /, "", key)
    sub(/:.*$/, "", key)
    gsub(/^["']|["']$/, "", key)
    saw_key = 1
    if (key == "pull_request") seen_pr = 1
    else if (key !~ /^[a-z_]+$/) puzzled = 1
  } else if (line !~ /^    / || !saw_key) {
    # Neither a two-space key nor deeper configuration: an indentation this
    # script cannot place, which is exactly when it must not answer. The
    # `!saw_key` half is not decoration - it was written after a probe fed the
    # parser `on:` followed directly by a SIX-space `pull_request:`, and it
    # answered "no, parsed fine". Deeper lines are configuration only once
    # there is a key for them to configure.
    puzzled = 1
  }
}

END { emit() }

function emit() {
  if (!have_file) return
  printf "%s\t%s\t%s\t%s\n", file, name, (seen_pr ? "yes" : "no"), (puzzled ? "unknown" : "ok")
}
