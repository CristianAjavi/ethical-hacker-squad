# 2026-08-26 — clone siblings per security finding

**The median is 1. So is the mean, and so is the maximum.** Across 37 findings in two
repositories, not one sits in a function that has an identical-up-to-renaming sibling
anywhere in its own tree.

[The method](METHOD.md) was fixed and committed before any number was computed, and it names
this outcome in advance: *"If the median is 1, the 'one generator defect becomes N' story
collapses — and this repository would have been the one to show it."*

## What was measured

| | `pyload` @ `6c52b198d` | Django @ `08187c94ed` |
|---|---|---|
| functions indexed | 2,386 | 27,738 |
| distinct shapes | 2,085 | 22,688 |
| **functions in a clone group** | **301 (12.6%)** | **5,050 (18.2%)** |
| findings resolved to a function | 30 (24 distinct) | 7 (7 distinct) |
| **findings in a clone group** | **0 (0.0%)** | **0 (0.0%)** |
| siblings per finding — median / mean / max | 1 / 1 / 1 | 1 / 1 / 1 |

## The control that makes the zero mean something

A detector that never matches anything also reports a median of 1. So the first number to read
is not the findings — it is **12.6% and 18.2%**: the share of all functions that *do* have a
clone sibling under exactly these rules. The detector works, at a rate these codebases make
plausible.

Against that base rate, random placement of 31 distinct finding-bearing functions would put
roughly four of them in clone groups. **Zero of 31.**

## What this supports

In these two repositories, **security findings sit in code that is not duplicated**, while one
function in six or eight overall is. The mechanism the amplification story needs — a defect
landing in a unit that has copies — is **absent here**.

That is a narrower claim than the one it touches, and deliberately: it is the **human-authored
baseline** against which any claim about generated code would have to be measured. Nobody had
published it, because clone research counts clones and security research counts findings.

## What this does not support, and it is most of it

- **Neither repository is generator-authored.** This measures nothing about AI-written code.
  It measures the assumption underneath the claim, in code where that claim is not being made.
- **Type-1 and type-2 only.** A near-clone with one statement added does not match. If
  generated duplication is mostly gapped, this method is blind to it and the zero above says
  nothing about that.
- **The findings are ours.** They come from this project's own blinded audits, and an auditor
  drawn to entry points, handlers and helpers may be drawn to code that is unique for reasons
  that have nothing to do with defects. **31 distinct functions is a small sample and it is not
  a random one.**
- **One finding in each repository had no enclosing function** and was excluded, as the method
  says. 179 units in `pyload` and 2,637 in Django fell below the declared size floor.

## What this forces

- **The corpus must not argue from finding amplification** without saying that its own
  measurement found none. Anywhere it multiplies a clone rate by a finding count, this page is
  the citation that says the multiplication has no support here.
- **The next version of this needs a corpus labelled by authorship.** Without one, the
  interesting question stays unasked — and that is a sampling problem, not a method problem.
- **Type-3 detection would change what this can see.** Until it exists, the zero is a zero
  about identical siblings and nothing wider.

Reproduce with:

```
python3 scripts/bench/clone_siblings.py --target <tree> --label <name> \
  --findings bench/runs/<round>/runs --out <file>
```
