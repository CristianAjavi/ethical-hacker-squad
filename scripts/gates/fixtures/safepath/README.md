# safepath fixtures — and the mutant bank behind them

The fixtures in `bad/`, `good/` and `unmeasurable/` are the self-test
`gate-promotion-safepath.sh` runs before it audits anything. A negative fixture
declares the rule it must trigger in a `# gate-expect:` header; if any of the
three groups stops behaving, the gate returns `2` and audits nothing, because a
gate that has not measured itself cannot sign a green.

Fixtures prove the gate against files written to be caught. They do not prove it
against the file it exists for. That is what the mutant bank is: the real
`.github/workflows/release.yml`, damaged one way at a time.

| | Mutation of `release.yml` | Expected | Measured |
|---|---|---|---|
| `M0` | none — the file as it is | `0` | `0` |
| `M1` | delete `PYTHONSAFEPATH: '1'` | `1` | `1` |
| `M2` | rename the key to `PYTHONSAFEPATH_UNUSED` | `1` | `1` |
| `M3` | replace `working-directory: source` with a `cd source`, key deleted | `1` | `1` |
| `M4` | `PYTHONSAFEPATH: ''` — declared, inert | `1` | `1` |
| `M5` | `PYTHONSAFEPATH: '0'` | `0` | `0` |
| `M6` | restored | `0` | `0` |

Two of those rows are the reason the gate reads the way it does.

**`M1`, on the first version, measured `0`.** The rule was "a step whose `run:`
invokes python outside the workspace root", and the word `python` appears
nowhere in the step that runs the gates over the candidate — it runs
`./scripts/gates/run-all.sh`, and python is reached through the gates that
runner invokes. The gate passed the exposed workflow. Trigger `T1` — two trees
checked out, a step running inside one of them — is what that measurement
bought, and `bad/4` is that shape with no python in it anywhere.

**`M5` is a pass on purpose.** CPython acts on `PYTHONSAFEPATH` when it is set
to a *non-empty string*: `'0'` switches it **on**. The value is not read as a
boolean, so failing that row would be the gate inventing a defect. The row that
does fail is `M4`, the empty value, which is the only spelling that declares the
mitigation and delivers nothing.

Reproducing the bank is four `sed` calls over a copy of the workflow and one
invocation of the gate per row; it is deliberately not automated, because a
mutant bank that runs in CI against the live release workflow is a mutation of
the live release workflow.
