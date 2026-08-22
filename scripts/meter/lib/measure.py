#!/usr/bin/env python3
# scripts/meter/lib/measure.py
#
# Measurement core of the project meter. meter.sh is the entry point; this file
# does the reading and the arithmetic and prints either a human table or JSON.
#
# EXIT CODE DOCTRINE (the same one the gates use, applied to the meter itself):
#   0 = every metric was MEASURED and no measured failure was found
#   1 = everything MEASURED, and at least one measured FAILURE exists
#       (gate suite reported FAIL, or a procedure is missing a mandatory field,
#        or two procedures share an ID, or the baseline contradicts itself)
#   2 = at least one metric COULD NOT BE MEASURED
#
# The rule that this file exists to enforce: a metric that cannot be taken is
# emitted as {"status": "not_measured", "reason": ...}. It is never emitted as
# zero and it is never omitted. A zero in this output always means "I counted
# and the count was zero".
#
# Only the standard library is used. No third-party imports, ever.

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

SCHEMA = "ehs.meter/v1"

STATUS_MEASURED = "measured"
STATUS_NOT_MEASURED = "not_measured"

ANSI = re.compile(r"\x1b\[[0-9;]*m")


# --------------------------------------------------------------------------
# metric constructors: the only two shapes a number is allowed to have
# --------------------------------------------------------------------------
def m(value):
    """A measured value."""
    return {"status": STATUS_MEASURED, "value": value}


def nm(reason):
    """Could not be measured. Carries the reason, never a substitute number."""
    return {"status": STATUS_NOT_MEASURED, "reason": reason}


def is_measured(metric):
    return isinstance(metric, dict) and metric.get("status") == STATUS_MEASURED


def val(metric, default=None):
    return metric["value"] if is_measured(metric) else default


def fmt(metric, formatter=str, absent="NOT MEASURED"):
    return formatter(metric["value"]) if is_measured(metric) else absent


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def read_json(path):
    """(data, error). Never raises: an unreadable input is a NOT MEASURED, not a crash."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh), None
    except FileNotFoundError:
        return None, "file not found: %s" % path
    except json.JSONDecodeError as exc:
        return None, "invalid JSON in %s: %s" % (path, exc)
    except OSError as exc:
        return None, "cannot read %s: %s" % (path, exc)


def read_text(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read(), None
    except OSError as exc:
        return None, "cannot read %s: %s" % (path, exc)


def git_fact(root, args):
    try:
        out = subprocess.run(
            ["git", "-C", root] + args,
            capture_output=True, text=True, timeout=15, check=False,
        )
        if out.returncode != 0:
            return nm("git %s returned %d" % (" ".join(args), out.returncode))
        return m(out.stdout.strip())
    except (OSError, subprocess.SubprocessError) as exc:
        return nm("git unavailable: %s" % exc)


# --------------------------------------------------------------------------
# 1. CORPUS
# --------------------------------------------------------------------------
def measure_corpus(root, cfg):
    """Procedures, lines, bytes and six-field completeness, per pack."""
    section = {
        "what_it_measures": (
            "Numbered procedures per pack, size of the pack files, and whether each "
            "procedure carries the six mandatory fields. Lines and bytes are whole-file "
            "figures: they include each file's loading index and prose, not only the "
            "procedure bodies."
        ),
        "what_it_does_not_measure": (
            "Quality, accuracy or exploitability of any procedure. A procedure with all "
            "six fields filled with nonsense counts as complete here."
        ),
    }

    kdir = os.path.join(root, cfg.get("knowledge_dir", ""))
    if not os.path.isdir(kdir):
        section["status"] = STATUS_NOT_MEASURED
        section["reason"] = "knowledge directory not found: %s" % kdir
        for key in ("packs", "totals", "id_integrity"):
            section[key] = nm(section["reason"])
        return section, [], []

    try:
        fields = [(f["name"], f["label"], re.compile(f["pattern"], re.M))
                  for f in cfg["required_fields"]]
        head_re = re.compile(cfg["procedure_heading"], re.M)
    except (KeyError, re.error) as exc:
        reason = "packs.json is malformed: %s" % exc
        section["status"] = STATUS_NOT_MEASURED
        section["reason"] = reason
        for key in ("packs", "totals", "id_integrity"):
            section[key] = nm(reason)
        return section, [], []

    trace_field = cfg.get("traceability_field", "traceability")
    declared = set()
    for pack in cfg["packs"]:
        for fname in pack["files"]:
            declared.add(fname)
    declared |= set(cfg.get("non_procedure_files", []))

    on_disk = sorted(f for f in os.listdir(kdir) if f.endswith(".md"))
    undeclared = [f for f in on_disk if f not in declared]

    packs_out = []
    procedures = []          # every procedure, flat
    problems = []            # measured failures
    total_lines = total_bytes = 0
    unreadable = []          # full diagnostics, one per unreadable file
    unread_names = []        # just the filenames, for a reason line a human can read

    for pack in cfg["packs"]:
        p_lines = p_bytes = 0
        p_files = []
        p_procs = []
        for fname in pack["files"]:
            fpath = os.path.join(kdir, fname)
            text, err = read_text(fpath)
            if err:
                unreadable.append(err)
                unread_names.append(fname)
                p_files.append({"file": fname, "status": STATUS_NOT_MEASURED, "reason": err})
                continue
            nbytes = os.path.getsize(fpath)
            nlines = text.count("\n") + (0 if text.endswith("\n") or not text else 1)
            p_lines += nlines
            p_bytes += nbytes
            p_files.append({"file": fname, "status": STATUS_MEASURED,
                            "lines": nlines, "bytes": nbytes})

            # split the file into procedure bodies
            heads = list(head_re.finditer(text))
            for idx, head in enumerate(heads):
                start = head.start()
                end = heads[idx + 1].start() if idx + 1 < len(heads) else len(text)
                body = text[start:end]
                # a "## " section heading ends the procedure before the next "### "
                nxt = re.search(r"^## ", body[3:], re.M)
                if nxt:
                    body = body[: nxt.start() + 3]
                prefix, number = head.group(1), head.group(2)
                pid = "%s-%s" % (prefix, number)
                present, missing = [], []
                for fname_key, label, rx in fields:
                    (present if rx.search(body) else missing).append(fname_key)
                proc = {
                    "id": pid,
                    "prefix": prefix,
                    "number": int(number),
                    "pack": pack["pack"],
                    "file": fname,
                    "line": text[:start].count("\n") + 1,
                    "fields_present": present,
                    "fields_missing": missing,
                    "complete": not missing,
                    "traceability_raw": _trace_raw(body, dict(
                        (n, rx) for n, _l, rx in fields), trace_field),
                }
                p_procs.append(proc)
                procedures.append(proc)
                if missing:
                    problems.append(
                        "%s (%s:%d) is missing mandatory field(s): %s"
                        % (pid, fname, proc["line"], ", ".join(missing)))

        complete = [p for p in p_procs if p["complete"]]
        incomplete = [p for p in p_procs if not p["complete"]]
        readable_files = [f for f in p_files if f["status"] == STATUS_MEASURED]
        all_readable = len(readable_files) == len(pack["files"])
        total_lines += p_lines
        total_bytes += p_bytes

        packs_out.append({
            "pack": pack["pack"],
            "role": pack.get("role"),
            "files": p_files,
            "procedures": m(len(p_procs)) if all_readable else nm("a pack file is unreadable"),
            "lines": m(p_lines) if all_readable else nm("a pack file is unreadable"),
            "bytes": m(p_bytes) if all_readable else nm("a pack file is unreadable"),
            "complete_6_fields": m(len(complete)) if all_readable else nm("a pack file is unreadable"),
            "incomplete": m([{"id": p["id"], "missing": p["fields_missing"],
                              "at": "%s:%d" % (p["file"], p["line"])} for p in incomplete])
                          if all_readable else nm("a pack file is unreadable"),
            "id_range": m(_id_ranges(p_procs)) if all_readable else nm("a pack file is unreadable"),
        })

    # ---- Is this corpus WHOLE? Every aggregate below is a statement about the
    # ---- corpus as a whole, so it may only be published when the whole corpus
    # ---- was actually read. A file that could not be read, or a file nobody
    # ---- declared, means the totals would be a partial sum wearing the clothes
    # ---- of a complete one - and a plausible undercount is a worse lie than a
    # ---- missing number, because nothing on screen invites you to doubt it.
    whole = True
    reasons = []
    if unreadable:
        whole = False
        reasons.append("%d declared pack file(s) could not be read: %s"
                       % (len(unreadable), ", ".join(sorted(unread_names))))
    if undeclared:
        whole = False
        reasons.append("%d knowledge file(s) on disk are not declared in packs.json, so "
                       "their procedures are in no count: %s"
                       % (len(undeclared), ", ".join(undeclared)))
    partial_reason = "; ".join(reasons)

    def agg(value):
        """An aggregate over the corpus: publishable only if the corpus was whole."""
        return m(value) if whole else nm(partial_reason)

    # ---- ID integrity (cheap, and it is exactly the class of error that a
    # ---- parallel merge introduces: two areas claiming the same number)
    seen = {}
    duplicates = []
    for p in procedures:
        seen.setdefault(p["id"], []).append("%s:%d" % (p["file"], p["line"]))
    for pid, where in sorted(seen.items()):
        if len(where) > 1:
            duplicates.append({"id": pid, "at": where})
            # A duplicate FOUND is real whatever else went unread; only the
            # claim "there are none" depends on having read everything.
            problems.append("duplicate procedure ID %s at %s" % (pid, ", ".join(where)))

    gaps = []
    by_prefix = {}
    for p in procedures:
        by_prefix.setdefault(p["prefix"], []).append(p["number"])
    for prefix, numbers in sorted(by_prefix.items()):
        missing = sorted(set(range(min(numbers), max(numbers) + 1)) - set(numbers))
        if missing:
            gaps.append({"prefix": prefix, "missing": missing})
            # A hole in the numbering is a procedure that a merge dropped. It is
            # only a FINDING when the corpus was whole: in a partial read the
            # "missing" numbers are simply the ones in the file we could not open.
            if whole:
                problems.append(
                    "numbering gap in %s: %s missing. A gap is a procedure lost in a "
                    "merge until someone proves otherwise."
                    % (prefix, ", ".join("%s-%02d" % (prefix, n) for n in missing)))

    section["status"] = STATUS_MEASURED
    section["knowledge_dir"] = cfg["knowledge_dir"]
    section["packs"] = packs_out
    section["corpus_is_whole"] = m(True) if whole else nm(partial_reason)
    section["undeclared_files"] = m(undeclared)
    section["unreadable_files"] = m(unreadable)
    section["totals"] = {
        "packs": m(len(packs_out)),
        "procedures": agg(len(procedures)),
        "lines": agg(total_lines),
        "bytes": agg(total_bytes),
        "complete_6_fields": agg(sum(1 for p in procedures if p["complete"])),
        "incomplete_6_fields": agg(sum(1 for p in procedures if not p["complete"])),
    }
    section["id_integrity"] = {
        # The list of duplicates/gaps FOUND is always real. Publishing it as
        # "measured" when files went unread would assert that the list is
        # exhaustive, which it is not.
        "duplicate_ids": agg(duplicates),
        "numbering_gaps": agg(gaps),
        "found_anyway": m({"duplicate_ids": duplicates, "numbering_gaps": gaps}),
    }
    if undeclared:
        problems.append(
            "knowledge file(s) present on disk but not declared in packs.json: %s"
            % ", ".join(undeclared))
    if unreadable:
        section["status"] = STATUS_NOT_MEASURED
        section["reason"] = partial_reason
    return section, procedures, problems


def _trace_raw(body, field_rx, trace_field):
    rx = field_rx.get(trace_field)
    if rx is None:
        return ""
    out = []
    for match in rx.finditer(body):
        eol = body.find("\n", match.start())
        out.append(body[match.start(): eol if eol != -1 else len(body)])
    return "\n".join(out)


def _id_ranges(procs):
    ranges = {}
    for p in procs:
        lo, hi = ranges.get(p["prefix"], (p["number"], p["number"]))
        ranges[p["prefix"]] = (min(lo, p["number"]), max(hi, p["number"]))
    return ["%s-%02d..%s-%02d" % (k, v[0], k, v[1]) for k, v in sorted(ranges.items())]


# --------------------------------------------------------------------------
# 2. TRACEABILITY
# --------------------------------------------------------------------------
LABEL_RE = re.compile(r"^\*\*Traceability\*\*\s*:?\s*", re.M)


def _extract_identifiers(payload, families, expanders):
    """Pull every standard identifier out of one Traceability payload.

    Returns (ids_by_family, leftover_segments). Extracted spans are blanked out
    as they are consumed, so what remains is exactly the prose the corpus wrote
    instead of an identifier - which is a fact worth printing, not noise to drop.
    """
    found = {}
    work = payload

    # Chapter-list abbreviations first: 'ASVS 5.0 V1, V2, V8' is three citations.
    # The whole span is consumed here, otherwise the trailing ', V2, V8' would be
    # left behind and reported as prose.
    for exp in expanders:
        def _expand(mt, exp=exp):
            span_text = mt.group(0)
            pre = exp["prefix"].search(span_text)
            if not pre:
                return span_text
            head = re.sub(r"\s+", " ", pre.group(0)).strip()
            for item in exp["item"].finditer(span_text):
                found.setdefault(exp["family"], set()).add("%s %s" % (head, item.group(0)))
            return " " * len(span_text)
        work = exp["span"].sub(_expand, work)

    for family, _owner, rx in families:
        def _blank(mt, fam=family):
            found.setdefault(fam, set()).add(re.sub(r"\s+", " ", mt.group(0)).strip())
            return " " * len(mt.group(0))
        work = rx.sub(_blank, work)

    leftovers = []
    for seg in re.split(r"·|\n", work):
        seg = seg.replace("`", " ").strip(" \t,;.-")
        seg = re.sub(r"\s+", " ", seg)
        if len(seg) >= 3:
            leftovers.append(seg)
    return found, leftovers


def measure_traceability(procedures, corpus_status, families_path):
    section = {
        "what_it_measures": (
            "How many procedures cite at least one standard identifier in their "
            "Traceability field, how many distinct identifiers are cited, and how many "
            "standard families they belong to. Identifiers are extracted from the field "
            "payload whether or not they are wrapped in backticks."
        ),
        "what_it_does_not_measure": (
            "Whether the cited identifier is the RIGHT one for the procedure, whether it "
            "exists in the published standard, or whether the standard version is "
            "current. An invented CWE-99999 would be counted. Text in a Traceability "
            "field that carries no identifier is reported as a prose segment, never "
            "silently discarded and never counted as a citation."
        ),
    }

    fam_cfg, err = read_json(families_path)
    if err:
        section["status"] = STATUS_NOT_MEASURED
        section["reason"] = err
        for key in ("procedures_with_identifier", "distinct_identifiers", "families_touched"):
            section[key] = nm(err)
        return section, []

    try:
        families = [(f["family"], f.get("owner"), re.compile(f["extract"]))
                    for f in fam_cfg["families"]]
        expanders = [{"family": e["family"],
                      "span": re.compile(e["span"]),
                      "prefix": re.compile(e["prefix"]),
                      "item": re.compile(e["item"])}
                     for e in fam_cfg.get("list_expanders", [])]
    except (KeyError, re.error) as exc:
        reason = "standards-families.json is malformed: %s" % exc
        section["status"] = STATUS_NOT_MEASURED
        section["reason"] = reason
        for key in ("procedures_with_identifier", "distinct_identifiers", "families_touched"):
            section[key] = nm(reason)
        return section, []

    if corpus_status != STATUS_MEASURED:
        reason = "the corpus could not be read, so its Traceability fields cannot be counted"
        section["status"] = STATUS_NOT_MEASURED
        section["reason"] = reason
        for key in ("procedures_with_identifier", "distinct_identifiers", "families_touched"):
            section[key] = nm(reason)
        return section, []

    backtick_rx = re.compile(r"`([^`]+)`")
    with_id, without_id, empty_field = [], [], []
    ids_seen = set()
    fam_ids, fam_procs = {}, {}
    prose_segments = {}
    unformatted = {}

    for proc in procedures:
        raw = proc.get("traceability_raw", "")
        payload = LABEL_RE.sub("", raw).strip()
        if not payload:
            empty_field.append(proc["id"])
            without_id.append({"id": proc["id"], "declares": ""})
            continue

        found, leftovers = _extract_identifiers(payload, families, expanders)
        backticked = set(t.strip() for t in backtick_rx.findall(payload))

        if not found:
            without_id.append({"id": proc["id"], "declares": payload[:110]})
        else:
            with_id.append(proc["id"])

        for fam, ids in found.items():
            fam_ids.setdefault(fam, set()).update(ids)
            fam_procs[fam] = fam_procs.get(fam, 0) + 1
            ids_seen.update(ids)
            for ident in ids:
                # cited as plain text where the corpus convention is code formatting
                if not any(ident in b or b in ident for b in backticked):
                    unformatted.setdefault(ident, set()).add(proc["id"])

        for seg in leftovers:
            prose_segments.setdefault(seg, []).append(proc["id"])

    fam_rows = sorted(
        ({"family": fam,
          "distinct_ids": len(fam_ids[fam]),
          "procedures": fam_procs.get(fam, 0)} for fam in fam_ids),
        key=lambda r: (-r["procedures"], r["family"]),
    )

    section["status"] = STATUS_MEASURED
    section["classifier"] = os.path.relpath(families_path)
    section["procedures_total"] = m(len(procedures))
    section["procedures_with_identifier"] = m(len(with_id))
    section["procedures_without_identifier"] = m(without_id)
    section["procedures_with_empty_field"] = m(empty_field)
    section["distinct_identifiers"] = m(len(ids_seen))
    section["families_touched"] = m(len(fam_rows))
    section["families"] = m(fam_rows)
    section["prose_only_segments"] = m(
        [{"text": k, "cited_by": v} for k, v in
         sorted(prose_segments.items(), key=lambda kv: -len(kv[1]))])
    section["identifiers_cited_without_code_formatting"] = m(
        [{"identifier": k, "in": sorted(v)} for k, v in sorted(unformatted.items())])

    problems = []
    if empty_field:
        problems.append("procedure(s) whose Traceability field is empty: %s"
                        % ", ".join(empty_field))
    return section, problems


# --------------------------------------------------------------------------
# 3. PCC (professional curriculum coverage) - read from DATA, never from prose
# --------------------------------------------------------------------------
def measure_pcc(baseline_path, corpus_packs):
    section = {
        "what_it_measures": (
            "The PCC baseline recorded in docs/coverage/baseline.json: covered topics, "
            "in-scope gaps and high-severity gaps per pack, plus the ratio recomputed "
            "from those two counts."
        ),
        "what_it_does_not_measure": (
            "Nothing here is measured against the corpus. The 'covered' column is the "
            "self-assessment of the five curriculum-mapping areas and contains at least "
            "one proven false positive, so every PCC value is a SELF-ASSESSED UPPER "
            "BOUND, not a measurement. The meter only re-derives the arithmetic and "
            "checks it against what the source document declared."
        ),
    }

    data, err = read_json(baseline_path)
    if err:
        section["status"] = STATUS_NOT_MEASURED
        section["reason"] = err + " (extract the prose report into this data file first)"
        for key in ("global", "packs"):
            section[key] = nm(section["reason"])
        return section, []

    try:
        packs = data["packs"]
        gdecl = data["global_declared"]
        conf = data["confidence"]
    except KeyError as exc:
        reason = "baseline.json is missing key %s" % exc
        section["status"] = STATUS_NOT_MEASURED
        section["reason"] = reason
        section["global"] = nm(reason)
        section["packs"] = nm(reason)
        return section, []

    problems = []
    rows = []
    sum_cov = sum_gap = sum_high = 0
    for row in packs:
        cov, gap = row["covered"], row["gaps"]
        denom = cov + gap
        recomputed = (cov / denom) if denom else None
        declared = row.get("pcc_declared")
        consistent = (
            recomputed is not None and declared is not None
            and abs(recomputed - declared) <= 0.011
        )
        if not consistent:
            problems.append(
                "baseline.json: pack %s declares pcc=%s but covered/(covered+gaps)=%s"
                % (row["pack"], declared,
                   "undefined" if recomputed is None else round(recomputed, 4)))
        sum_cov += cov
        sum_gap += gap
        sum_high += row.get("gaps_high", 0)
        rows.append({
            "pack": row["pack"],
            "covered": m(cov),
            "gaps": m(gap),
            "pcc_declared": m(declared),
            "pcc_recomputed": m(round(recomputed, 4)) if recomputed is not None
                              else nm("denominator is zero"),
            "gaps_high": m(row.get("gaps_high")) if row.get("gaps_high") is not None
                         else nm("baseline.json does not record gaps_high for this pack"),
            "consistent_with_source": m(consistent),
            "sample_note": row.get("sample_note"),
        })

    gdenom = sum_cov + sum_gap
    grecomputed = (sum_cov / gdenom) if gdenom else None
    gconsistent = (
        grecomputed is not None
        and abs(grecomputed - gdecl.get("pcc_declared", -1)) <= 0.011
        and sum_cov == gdecl.get("covered")
        and sum_gap == gdecl.get("gaps")
        and sum_high == gdecl.get("gaps_high")
    )
    if not gconsistent:
        problems.append(
            "baseline.json: the per-pack rows sum to covered=%d gaps=%d gaps_high=%d, "
            "but global_declared says covered=%s gaps=%s gaps_high=%s"
            % (sum_cov, sum_gap, sum_high, gdecl.get("covered"),
               gdecl.get("gaps"), gdecl.get("gaps_high")))

    baseline_names = set(r["pack"] for r in packs)
    corpus_names = set(corpus_packs)
    section["status"] = STATUS_MEASURED
    section["source_document"] = data.get("source", {}).get("document")
    section["extracted_on"] = data.get("extracted_on")
    section["is_upper_bound"] = m(conf.get("is_upper_bound"))
    section["self_assessed"] = m(conf.get("self_assessed"))
    section["caveat"] = conf.get("statement")
    section["known_false_positives"] = m(conf.get("known_false_positives", []))
    section["packs"] = rows
    section["global"] = {
        "covered": m(sum_cov),
        "gaps": m(sum_gap),
        "gaps_high": m(sum_high),
        "pcc_recomputed": m(round(grecomputed, 4)) if grecomputed is not None
                          else nm("denominator is zero"),
        "pcc_declared": m(gdecl.get("pcc_declared")),
        "consistent_with_source": m(gconsistent),
    }
    section["pack_alignment"] = {
        "in_baseline_not_in_corpus": m(sorted(baseline_names - corpus_names)),
        "in_corpus_not_in_baseline": m(sorted(corpus_names - baseline_names)),
    }
    for extra in sorted(baseline_names - corpus_names):
        problems.append("baseline.json scores pack '%s', which is not declared in packs.json" % extra)
    # A pack with no score is not automatically drift. The baseline is a
    # transcription whose own provenance forbids inventing rows, so a pack the
    # source document never saw is DECLARED in `unassessed` with the reason and
    # what would settle it. Listed there it is a known gap; in neither list it
    # is silence, and silence is what this check exists to catch. Same
    # distinction `engagement.coverage` draws between not_read and nothing.
    declared_unassessed = set()
    ub = data.get("unassessed") or {}
    for row in (ub.get("packs") or []):
        if isinstance(row, dict) and isinstance(row.get("pack"), str):
            if (row.get("reason") or "").strip() and (row.get("what_would_settle_it") or "").strip():
                declared_unassessed.add(row["pack"])
            else:
                problems.append(
                    "baseline.json declares pack '%s' unassessed with no reason or no way to settle it, "
                    "which is a placeholder rather than a declaration" % row.get("pack"))
    section["pack_alignment"]["declared_unassessed"] = m(sorted(declared_unassessed))
    for extra in sorted(declared_unassessed - corpus_names):
        problems.append("baseline.json declares pack '%s' unassessed, but it is not in the corpus" % extra)
    for missing in sorted(corpus_names - baseline_names - declared_unassessed):
        problems.append("pack '%s' exists in the corpus and has no PCC baseline row" % missing)
    return section, problems


# --------------------------------------------------------------------------
# 4. GATES
# --------------------------------------------------------------------------
SUMMARY_RE = re.compile(
    r"discovered:\s*(\d+)\s*\|\s*run:\s*(\d+)\s*\|\s*green:\s*(\d+)\s*\|\s*"
    r"FAIL:\s*(\d+)\s*\|\s*UNMEASURABLE:\s*(\d+)")


def measure_gates(raw_path, rc_raw, skipped_reason):
    section = {
        "what_it_measures": (
            "The result of scripts/gates/run-all.sh: how many gates returned 0 "
            "(measured, fine), 1 (measured, fails) and 2 (COULD NOT MEASURE), plus the "
            "gates that were declared as not runnable in this context."
        ),
        "what_it_does_not_measure": (
            "Whether the gates check the right things. A 2 is never counted as a pass: "
            "it means that check never happened."
        ),
    }
    if skipped_reason:
        section["status"] = STATUS_NOT_MEASURED
        section["reason"] = skipped_reason
        for key in ("runner_exit_code", "green", "failed", "unmeasurable", "discovered", "run"):
            section[key] = nm(skipped_reason)
        return section, []

    text, err = read_text(raw_path) if raw_path else (None, "no gate output captured")
    if err:
        section["status"] = STATUS_NOT_MEASURED
        section["reason"] = err
        for key in ("runner_exit_code", "green", "failed", "unmeasurable", "discovered", "run"):
            section[key] = nm(err)
        return section, []

    text = ANSI.sub("", text)
    match = SUMMARY_RE.search(text)
    if not match:
        reason = ("scripts/gates/run-all.sh produced no GATE SUMMARY line "
                  "(exit code was %s); its output cannot be parsed" % rc_raw)
        section["status"] = STATUS_NOT_MEASURED
        section["reason"] = reason
        section["runner_exit_code"] = m(rc_raw) if rc_raw is not None else nm("runner rc unknown")
        for key in ("green", "failed", "unmeasurable", "discovered", "run"):
            section[key] = nm(reason)
        section["raw_tail"] = text.strip().splitlines()[-12:]
        return section, []

    discovered, run, green, failed, unmeas = (int(g) for g in match.groups())

    per_gate = []
    tail = text[match.end():]
    for line in tail.splitlines():
        line = line.strip()
        gm = re.match(r"^(OK|FAIL|UNMEASURABLE)\s+(\S+)\s+—\s+(.*)$", line)
        if gm:
            code = {"OK": 0, "FAIL": 1, "UNMEASURABLE": 2}[gm.group(1)]
            per_gate.append({"gate": gm.group(2), "code": code, "detail": gm.group(3)})
    deferred = []
    dm = re.search(r"NOT RUN HERE \(declared, not silenced\):(.*)", text)
    if dm:
        deferred = [d for d in dm.group(1).split() if d]

    section["status"] = STATUS_MEASURED
    section["runner"] = "scripts/gates/run-all.sh"
    section["runner_exit_code"] = m(rc_raw) if rc_raw is not None else nm("runner rc unknown")
    section["discovered"] = m(discovered)
    section["run"] = m(run)
    section["green"] = m(green)
    section["failed"] = m(failed)
    section["unmeasurable"] = m(unmeas)
    section["deferred"] = m(deferred)
    section["per_gate"] = m(per_gate)
    section["note"] = ("UNMEASURABLE (2) is not a pass. %d of the %d gates that ran did "
                       "not perform their check." % (unmeas, run))

    problems = []
    if failed > 0:
        problems.append("%d gate(s) MEASURED A FAILURE: %s"
                        % (failed, ", ".join(g["gate"] for g in per_gate if g["code"] == 1)))

    # A 2 from a gate is a hole in THIS report too. Without this the meter would
    # print "UNMEASURABLE 1" in the gates block and still return 0 overall, which
    # is precisely the false green the doctrine exists to prevent.
    stuck = [g["gate"] for g in per_gate if g["code"] == 2]
    if unmeas > 0:
        section["unmeasured_gates"] = m(stuck)
        section["all_gate_checks_performed"] = nm(
            "%d of the %d gates that ran returned 2: %s. Those checks never happened, so "
            "the repository state they cover is unknown."
            % (unmeas, run, ", ".join(stuck) if stuck else "gate name not parsed"))
    else:
        section["all_gate_checks_performed"] = m(True)

    # The runner's own contract: anything other than 0/1/2 means the suite did not
    # honour the doctrine and its verdict cannot be trusted.
    if rc_raw is not None and rc_raw not in (0, 1, 2):
        section["runner_contract"] = nm(
            "scripts/gates/run-all.sh returned %s, which is outside the 0/1/2 contract"
            % rc_raw)

    # ---- The summary counters are TAKEN ON TRUST from the runner. Cross-check
    # them against the per-gate lines the runner printed underneath, because the
    # whole verdict of this meter hangs off those five integers.
    #
    # The check is DIRECTIONAL on purpose. A runner may legitimately print fewer
    # detail lines than it counted (truncation, a gate that prints nothing), so
    # "summary claims more than the detail shows" is not evidence of anything.
    # The opposite direction is: a detail line states that a gate FAILED or could
    # NOT BE MEASURED, while the summary counts zero of them. One of the two is
    # wrong, we cannot tell which, and believing the summary is how a broken gate
    # gets laundered into a green verdict. Unknown is 2.
    detail_failed = sum(1 for g in per_gate if g["code"] == 1)
    detail_unmeas = sum(1 for g in per_gate if g["code"] == 2)
    contradictions = []
    if detail_failed > failed:
        contradictions.append(
            "%d gate line(s) say FAIL (%s) but the summary counts FAIL: %d"
            % (detail_failed,
               ", ".join(g["gate"] for g in per_gate if g["code"] == 1), failed))
    if detail_unmeas > unmeas:
        contradictions.append(
            "%d gate line(s) say UNMEASURABLE (%s) but the summary counts UNMEASURABLE: %d"
            % (detail_unmeas,
               ", ".join(g["gate"] for g in per_gate if g["code"] == 2), unmeas))
    if run > 0 and not per_gate:
        contradictions.append(
            "the summary says %d gate(s) ran but the runner printed no per-gate line, "
            "so no individual result could be confirmed" % run)

    if contradictions:
        section["summary_matches_detail"] = nm(
            "scripts/gates/run-all.sh contradicts itself: %s. The gate results cannot be "
            "trusted until the runner agrees with its own output." % "; ".join(contradictions))
    else:
        section["summary_matches_detail"] = m(True)
    return section, problems


# --------------------------------------------------------------------------
# 5. REPO HYGIENE
# --------------------------------------------------------------------------
SHA_PIN = re.compile(r"^[^@\s]+@[0-9a-fA-F]{40}$")
USES_RE = re.compile(r"^\s*(?:-\s*)?uses:\s*['\"]?([^'\"\s#]+)")


def measure_hygiene(root, cfg):
    section = {
        "what_it_measures": (
            "Presence of the governance files GitHub and OpenSSF Scorecard look for, "
            "how many workflows exist, and whether every third-party action they use is "
            "pinned to a 40-character commit SHA."
        ),
        "what_it_does_not_measure": (
            "The CONTENT of any of those files. A LICENSE file with the wrong licence, "
            "or a SECURITY.md pointing at a dead address, is counted as present here. "
            "Pinning is checked by shape (40 hex after @), not by resolving the SHA."
        ),
    }
    artifacts = []
    for art in cfg.get("hygiene_artifacts", []):
        found = None
        for cand in art["candidates"]:
            if os.path.isfile(os.path.join(root, cand)):
                found = cand
                break
        artifacts.append({
            "artifact": art["name"],
            "present": m(found is not None),
            "path": m(found) if found else m(None),
            "searched": art["candidates"],
        })

    wdir = os.path.join(root, cfg.get("workflows_dir", ".github/workflows"))
    problems = []
    if not os.path.isdir(wdir):
        reason = "workflows directory not found: %s" % cfg.get("workflows_dir")
        section["status"] = STATUS_MEASURED
        section["artifacts"] = artifacts
        section["workflows"] = nm(reason)
        section["action_pinning"] = nm(reason)
        return section, problems

    wfiles = sorted(f for f in os.listdir(wdir) if f.endswith((".yml", ".yaml")))
    pinned, local, unpinned, docker = [], [], [], []
    unreadable = []
    for wf in wfiles:
        text, err = read_text(os.path.join(wdir, wf))
        if err:
            unreadable.append(err)
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            um = USES_RE.match(line)
            if not um:
                continue
            ref = um.group(1)
            where = {"workflow": wf, "line": lineno, "uses": ref}
            if ref.startswith("./"):
                local.append(where)
            elif ref.startswith("docker://"):
                docker.append(where)
            elif SHA_PIN.match(ref):
                pinned.append(where)
            else:
                unpinned.append(where)

    section["status"] = STATUS_MEASURED
    section["artifacts"] = artifacts
    section["workflows"] = {
        "count": m(len(wfiles)) if not unreadable else nm("; ".join(unreadable)),
        "files": m(wfiles),
    }
    section["action_pinning"] = {
        "total_uses": m(len(pinned) + len(local) + len(unpinned) + len(docker)),
        "pinned_by_sha": m(len(pinned)),
        "local_actions": m(len(local)),
        "docker_refs": m(len(docker)),
        "unpinned": m(unpinned),
        "unpinned_count": m(len(unpinned)),
    }
    if unpinned:
        problems.append(
            "%d workflow step(s) use an action that is not pinned to a 40-char SHA: %s"
            % (len(unpinned),
               ", ".join("%s:%d %s" % (u["workflow"], u["line"], u["uses"]) for u in unpinned)))
    return section, problems


# --------------------------------------------------------------------------
# verdict
# --------------------------------------------------------------------------
def collect_not_measured(node, path=""):
    """Walk the report and pull out every not_measured leaf, with its path."""
    out = []
    if isinstance(node, dict):
        if node.get("status") == STATUS_NOT_MEASURED and "reason" in node and len(node) <= 3:
            return [{"metric": path, "reason": node["reason"]}]
        for key, value in node.items():
            if key in ("what_it_measures", "what_it_does_not_measure", "caveat", "note",
                       "raw_tail", "searched", "reason"):
                continue
            child = "%s.%s" % (path, key) if path else key
            if key == "status" and value == STATUS_NOT_MEASURED:
                out.append({"metric": path, "reason": node.get("reason", "not stated")})
                continue
            out.extend(collect_not_measured(value, child))
    elif isinstance(node, list):
        for idx, item in enumerate(node):
            out.extend(collect_not_measured(item, "%s[%d]" % (path, idx)))
    return out


# --------------------------------------------------------------------------
# rendering
# --------------------------------------------------------------------------
BAR = "=" * 78
SUB = "-" * 78


def pct(x):
    return "%.1f%%" % (x * 100)


def render_table(rep, out):
    w = out.write
    sec = rep["sections"]

    w("%s\n" % BAR)
    w("  ethical-hacker-squad - PROJECT METER\n")
    w("  %s  |  branch %s  |  commit %s\n" % (
        rep["generated_at"],
        fmt(rep["git"]["branch"], absent="?"),
        fmt(rep["git"]["commit_short"], absent="?")))
    w("  0 = measured & fine   1 = measured & FAILS   2 = COULD NOT MEASURE\n")
    w("  A blank is never a zero: anything unmeasured is printed as NOT MEASURED.\n")
    w("%s\n\n" % BAR)

    # ---- corpus
    w("1. CORPUS\n%s\n" % SUB)
    corpus = sec["corpus"]
    # Guard on the SHAPE, not only on the status: when the corpus is unreadable
    # 'packs' is a not_measured object, not a list, and iterating it would crash
    # the renderer. A meter that dies while reporting a hole reports nothing.
    if not isinstance(corpus.get("packs"), list):
        w("  NOT MEASURED: %s\n\n" % corpus.get("reason", "reason not stated"))
    else:
        w("  %-15s %5s %7s %9s %8s  %s\n" %
          ("pack", "procs", "lines", "bytes", "6-field", "id range"))
        for p in corpus["packs"]:
            w("  %-15s %5s %7s %9s %8s  %s\n" % (
                p["pack"],
                fmt(p["procedures"], absent="n/m"),
                fmt(p["lines"], absent="n/m"),
                fmt(p["bytes"], absent="n/m"),
                fmt(p["complete_6_fields"], absent="n/m"),
                fmt(p["id_range"], lambda v: " ".join(v), absent="n/m")))
        tot = corpus["totals"]
        w("  %-15s %5s %7s %9s %8s\n" % (
            "TOTAL",
            fmt(tot["procedures"], absent="n/m"),
            fmt(tot["lines"], absent="n/m"),
            fmt(tot["bytes"], absent="n/m"),
            fmt(tot["complete_6_fields"], absent="n/m")))

        # When the corpus was not whole, every line below would be a claim about
        # files that were never opened. Say what is unknown, print what was found
        # anyway, and never print an all-clear over unread files.
        whole = corpus.get("corpus_is_whole", m(True))
        found = val(corpus["id_integrity"].get("found_anyway", m({})), {}) or {}
        if not is_measured(whole):
            w("\n  TOTALS NOT MEASURED - the corpus was not read whole:\n")
            for chunk in (whole.get("reason") or "").split("; "):
                if chunk:
                    w("    %s\n" % chunk)
            w("  Nothing can be totalled, and no all-clear can be given, over files that\n")
            w("  were never opened. The partial figures per pack are shown above as n/m.\n")
            fd = found.get("duplicate_ids") or []
            fg = found.get("numbering_gaps") or []
            w("  found in the part that WAS read - duplicate IDs: %s   numbering gaps: %s\n" % (
                (", ".join(d["id"] for d in fd) if fd else "none so far"),
                (", ".join("%s %s" % (g["prefix"], g["missing"]) for g in fg)
                 if fg else "none so far")))
        else:
            inc = val(tot["incomplete_6_fields"])
            if inc:
                w("\n  PROCEDURES MISSING A MANDATORY FIELD (%d):\n" % inc)
                for p in corpus["packs"]:
                    for item in val(p["incomplete"], []) or []:
                        w("    %-10s missing %-40s (%s)\n"
                          % (item["id"], ",".join(item["missing"]), item["at"]))
            else:
                w("  every procedure carries the six mandatory fields.\n")
            dups = val(corpus["id_integrity"]["duplicate_ids"], [])
            gaps = val(corpus["id_integrity"]["numbering_gaps"], [])
            w("  duplicate IDs: %s   numbering gaps: %s\n" % (
                (", ".join(d["id"] for d in dups) if dups else "none"),
                (", ".join("%s %s" % (g["prefix"], g["missing"]) for g in gaps)
                 if gaps else "none")))
        und = val(corpus["undeclared_files"], [])
        if und:
            w("  UNDECLARED knowledge files (present, not in packs.json): %s\n" % ", ".join(und))
    w("\n")

    # ---- traceability
    w("2. TRACEABILITY\n%s\n" % SUB)
    tr = sec["traceability"]
    if tr.get("status") != STATUS_MEASURED:
        w("  NOT MEASURED: %s\n" % tr.get("reason"))
    else:
        total = val(tr["procedures_total"])
        with_id = val(tr["procedures_with_identifier"])
        w("  procedures citing >=1 standard identifier : %d / %d (%s)\n"
          % (with_id, total, pct(with_id / total) if total else "n/a"))
        w("  distinct identifiers cited               : %d\n" % val(tr["distinct_identifiers"]))
        w("  standard families touched                : %d\n" % val(tr["families_touched"]))
        w("\n  %-20s %6s %6s\n" % ("family", "ids", "procs"))
        for row in val(tr["families"], []):
            w("  %-20s %6d %6d\n" % (row["family"], row["distinct_ids"], row["procedures"]))
        without = val(tr["procedures_without_identifier"], [])
        if without:
            w("\n  procedures citing NO external identifier (%d) - what they declare instead:\n"
              % len(without))
            for item in without:
                w("    %-10s %s\n" % (item["id"], item["declares"] or "(field is EMPTY)"))
        unf = val(tr["identifiers_cited_without_code_formatting"], [])
        if unf:
            w("\n  identifiers cited as plain text, not code-formatted (%d):\n" % len(unf))
            for item in unf[:12]:
                w("    %-24s in %s\n" % (item["identifier"], ", ".join(item["in"])))
            if len(unf) > 12:
                w("    ... and %d more (see --json)\n" % (len(unf) - 12))
        prose = val(tr["prose_only_segments"], [])
        if prose:
            w("\n  Traceability text carrying no identifier (%d distinct):\n" % len(prose))
            for item in prose[:8]:
                w("    \"%s\" x%d\n" % (item["text"][:62], len(item["cited_by"])))
            if len(prose) > 8:
                w("    ... and %d more (see --json)\n" % (len(prose) - 8))
    w("\n")

    # ---- pcc
    w("3. PCC - PROFESSIONAL CURRICULUM COVERAGE\n%s\n" % SUB)
    pc = sec["pcc"]
    if pc.get("status") != STATUS_MEASURED or not isinstance(pc.get("packs"), list):
        w("  NOT MEASURED: %s\n" % pc.get("reason", "reason not stated"))
    else:
        w("  source: %s (data: docs/coverage/baseline.json, extracted %s)\n"
          % (pc.get("source_document"), pc.get("extracted_on")))
        w("  *** SELF-ASSESSED UPPER BOUND, NOT A MEASUREMENT ***\n")
        w("  %-15s %8s %6s %8s %9s %6s\n"
          % ("pack", "covered", "gaps", "PCC", "declared", "HIGH"))
        for row in pc["packs"]:
            w("  %-15s %8s %6s %8s %9s %6s%s\n" % (
                row["pack"],
                fmt(row["covered"], absent="n/m"),
                fmt(row["gaps"], absent="n/m"),
                fmt(row["pcc_recomputed"], pct, absent="n/m"),
                fmt(row["pcc_declared"], pct, absent="n/m"),
                fmt(row["gaps_high"], absent="n/m"),
                "" if val(row["consistent_with_source"]) else "  <-- MISMATCH"))
        g = pc["global"]
        w("  %-15s %8s %6s %8s %9s %6s%s\n" % (
            "GLOBAL",
            fmt(g["covered"], absent="n/m"),
            fmt(g["gaps"], absent="n/m"),
            fmt(g["pcc_recomputed"], pct, absent="n/m"),
            fmt(g["pcc_declared"], pct, absent="n/m"),
            fmt(g["gaps_high"], absent="n/m"),
            "" if val(g["consistent_with_source"]) else "  <-- MISMATCH"))
        for fp in val(pc["known_false_positives"], []):
            w("  proven false positive in 'covered': %s (%s)\n"
              % (fp["topic"], fp["affects_pack"]))
        align = pc["pack_alignment"]
        extra = val(align["in_baseline_not_in_corpus"], [])
        missing = val(align["in_corpus_not_in_baseline"], [])
        if extra or missing:
            w("  pack alignment: baseline-only=%s corpus-only=%s\n" % (extra, missing))
    w("\n")

    # ---- gates
    w("4. GATES (scripts/gates/run-all.sh)\n%s\n" % SUB)
    ga = sec["gates"]
    if ga.get("status") != STATUS_MEASURED:
        w("  NOT MEASURED: %s\n" % ga.get("reason"))
        for line in ga.get("raw_tail", []):
            w("    | %s\n" % line)
    else:
        w("  runner exit code : %s\n" % fmt(ga["runner_exit_code"], absent="n/m"))
        w("  discovered %s | ran %s | green(0) %s | FAIL(1) %s | UNMEASURABLE(2) %s\n" % (
            fmt(ga["discovered"]), fmt(ga["run"]), fmt(ga["green"]),
            fmt(ga["failed"]), fmt(ga["unmeasurable"])))
        for g in val(ga["per_gate"], []):
            label = {0: "OK  0", 1: "FAIL 1", 2: "UNMEAS 2"}[g["code"]]
            w("    %-9s %-32s %s\n" % (label, g["gate"], g["detail"]))
        deferred = val(ga["deferred"], [])
        if deferred:
            w("  declared, not run here: %s\n" % " ".join(deferred))
        if val(ga["unmeasurable"], 0):
            w("  an UNMEASURABLE gate is NOT a pass: that check never happened.\n")
        smd = ga.get("summary_matches_detail")
        if smd is not None and not is_measured(smd):
            w("  !! GATE RESULTS NOT MEASURED - the runner contradicts itself:\n")
            w("     %s\n" % smd["reason"])
    w("\n")

    # ---- hygiene
    w("5. REPO HYGIENE\n%s\n" % SUB)
    hy = sec["hygiene"]
    if hy.get("status") != STATUS_MEASURED or not isinstance(hy.get("artifacts"), list):
        w("  NOT MEASURED: %s\n" % hy.get("reason", "reason not stated"))
    else:
        for art in hy["artifacts"]:
            present = val(art["present"])
            w("  %-14s %-9s %s\n" % (
                art["artifact"],
                "present" if present else "ABSENT",
                fmt(art["path"], absent="n/m") if present else
                "(searched: %s)" % ", ".join(art["searched"])))
        wf = hy["workflows"]
        if isinstance(wf, dict) and "count" in wf:
            w("  workflows      %-9s %s\n" % (
                fmt(wf["count"], absent="n/m"),
                ", ".join(val(wf["files"], []))))
        else:
            w("  workflows      NOT MEASURED: %s\n" % wf.get("reason"))
        ap = hy["action_pinning"]
        if isinstance(ap, dict) and "total_uses" in ap:
            w("  action refs    total %s | pinned-by-SHA %s | local %s | UNPINNED %s\n" % (
                fmt(ap["total_uses"]), fmt(ap["pinned_by_sha"]),
                fmt(ap["local_actions"]), fmt(ap["unpinned_count"])))
            for u in val(ap["unpinned"], []):
                w("    UNPINNED %s:%d  %s\n" % (u["workflow"], u["line"], u["uses"]))
        else:
            w("  action refs    NOT MEASURED: %s\n" % ap.get("reason"))
    w("\n")

    # ---- verdict
    verdict = rep["verdict"]
    w("%s\n" % BAR)
    w("  VERDICT: exit %d - %s\n" % (verdict["exit_code"], verdict["meaning"]))
    if verdict["measured_failures"]:
        w("  MEASURED FAILURES (%d):\n" % len(verdict["measured_failures"]))
        for item in verdict["measured_failures"]:
            w("    - %s\n" % item)
    if verdict["not_measured"]:
        w("  NOT MEASURED (%d) - these are holes, not zeros:\n" % len(verdict["not_measured"]))
        for item in verdict.get("not_measured_condensed") or verdict["not_measured"]:
            w("    - %s: %s\n" % (item["metric"], item["reason"]))
    w("%s\n" % BAR)


# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="ethical-hacker-squad project meter (core)")
    ap.add_argument("--root", required=True)
    ap.add_argument("--packs", required=True)
    ap.add_argument("--families", required=True)
    ap.add_argument("--baseline", default=None)
    ap.add_argument("--gates-raw", default=None)
    ap.add_argument("--gates-rc", default=None)
    ap.add_argument("--gates-skipped", default=None)
    ap.add_argument("--format", choices=("table", "json"), default="table")
    args = ap.parse_args()

    root = os.path.abspath(args.root)
    cfg, err = read_json(args.packs)
    if err:
        # Without the layout data nothing can be measured. Say so; do not invent zeros.
        report = {
            "schema": SCHEMA,
            "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "repo_root": root,
            "git": {"branch": nm("layout file unreadable"),
                    "commit_short": nm("layout file unreadable")},
            "sections": {"corpus": {"status": STATUS_NOT_MEASURED, "reason": err}},
            "verdict": {"exit_code": 2, "meaning": "COULD NOT MEASURE",
                        "measured_failures": [],
                        "not_measured": [{"metric": "all", "reason": err}]},
        }
        if args.format == "json":
            json.dump(report, sys.stdout, indent=2)
            sys.stdout.write("\n")
        else:
            sys.stdout.write("METER NOT MEASURED: %s\n" % err)
        return 2

    baseline_path = args.baseline or os.path.join(root, cfg.get("baseline_file", ""))

    corpus, procedures, prob_corpus = measure_corpus(root, cfg)
    trace, prob_trace = measure_traceability(
        procedures, corpus.get("status"), args.families)
    pcc, prob_pcc = measure_pcc(baseline_path, [p["pack"] for p in cfg["packs"]])
    rc_raw = None
    if args.gates_rc not in (None, ""):
        try:
            rc_raw = int(args.gates_rc)
        except ValueError:
            rc_raw = None
    gates, prob_gates = measure_gates(args.gates_raw, rc_raw, args.gates_skipped)
    hygiene, prob_hyg = measure_hygiene(root, cfg)

    report = {
        "schema": SCHEMA,
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "repo_root": root,
        "git": {
            "branch": git_fact(root, ["rev-parse", "--abbrev-ref", "HEAD"]),
            "commit_short": git_fact(root, ["rev-parse", "--short", "HEAD"]),
        },
        "doctrine": {
            "0": "measured and fine",
            "1": "measured and FAILS",
            "2": "COULD NOT MEASURE - never counted as a pass, never replaced by zero",
        },
        "sections": {
            "corpus": corpus,
            "traceability": trace,
            "pcc": pcc,
            "gates": gates,
            "hygiene": hygiene,
        },
    }

    failures = prob_corpus + prob_trace + prob_pcc + prob_gates + prob_hyg
    holes = collect_not_measured(report["sections"])
    # de-duplicate holes that repeat the same reason under a parent and its children
    seen_reason = set()
    unique_holes = []
    for hole in holes:
        key = (hole["metric"].split(".")[0], hole["reason"])
        if key in seen_reason:
            continue
        seen_reason.add(key)
        unique_holes.append(hole)

    # One broken input produces one hole per leaf it poisons. Listing forty of
    # them buries the verdict in noise and trains the reader to skip it, which is
    # its own way of hiding a hole. Cap the listing PER SECTION and state how many
    # were folded away: the count is never hidden, only the repetition.
    HOLES_SHOWN_PER_SECTION = 3
    per_section, capped = {}, []
    for hole in unique_holes:
        top = hole["metric"].split(".")[0] or "(root)"
        per_section[top] = per_section.get(top, 0) + 1
        if per_section[top] <= HOLES_SHOWN_PER_SECTION:
            capped.append(hole)
    for top, count in per_section.items():
        if count > HOLES_SHOWN_PER_SECTION:
            capped.append({
                "metric": top,
                "reason": "... and %d further NOT MEASURED leaf metric(s) under '%s', all "
                          "caused by the same unread input. They are listed in full in "
                          "--json." % (count - HOLES_SHOWN_PER_SECTION, top),
            })

    if unique_holes:
        code, meaning = 2, "COULD NOT MEASURE at least one metric"
    elif failures:
        code, meaning = 1, "measured, and something FAILS"
    else:
        code, meaning = 0, "everything measured, nothing failing"

    report["verdict"] = {
        "exit_code": code,
        "meaning": meaning,
        "measured_failures": failures,
        "not_measured": unique_holes,          # complete, always
        "not_measured_condensed": capped,      # same holes, folded for the table
    }

    if args.format == "json":
        json.dump(report, sys.stdout, indent=2, sort_keys=False)
        sys.stdout.write("\n")
    else:
        render_table(report, sys.stdout)
    return code


if __name__ == "__main__":
    # A crash in the measuring instrument is a COULD NOT MEASURE (2), never a
    # "measured and fails" (1) and never a partial report that looks complete.
    # Without this, a renderer bug would exit 1 and be read as a real failure.
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.stderr.write("meter: interrupted\n")
        sys.exit(2)
    except Exception as exc:  # noqa: BLE001 - deliberate: no crash may become a verdict
        import traceback
        sys.stderr.write("meter: NOT MEASURED - the measurement core crashed: %r\n" % (exc,))
        traceback.print_exc(file=sys.stderr)
        sys.exit(2)
