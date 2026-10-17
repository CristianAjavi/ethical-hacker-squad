# Running the squad on pull requests

[`examples/ehs-pull-request.yml`](examples/ehs-pull-request.yml) is a workflow to copy into **your** repository. On every pull request from the same repository it runs a `quick` audit of the change with [`anthropics/claude-code-action`](https://github.com/anthropics/claude-code-action) — which installs this plugin through its `plugin_marketplaces` and `plugins` inputs — exports `findings.json` with `scripts/ehs sarif`, and uploads it to GitHub code scanning, where findings appear on the lines the pull request touches.

## Before you enable it

- **It spends API credits on every pull request.** `--max-turns 80` caps one run; the quick mode caps the procedures it reads. Measure a few runs before leaving it on, and use `scripts/ehs cost` locally to see what a run of the same size spends.
- **The pull request is untrusted input to an agent holding your API key.** The workflow runs only for branches of the same repository (forks get no secrets anyway), grants `contents: read` and `security-events: write` and nothing else, and asks for an audit with no writes, installs or network. The plugin's auditors also run under its shell guard. None of that makes a prompt injection in the diff harmless: treat a finding that tells you to do something unusual as a finding about the pull request.
- **Uploading publishes.** Code-scanning alerts are visible to whoever can see the repository's security tab. The SARIF export refuses an artifact with an unredacted secret, but what the findings say about the code is published as written.
- **Pin what you run.** Every action is pinned by commit SHA. The second checkout pulls this repository at `main`; pin it to a commit you have read.

## Turning it into a gate

To fail the job on new high-severity findings rather than only report them, keep the `findings.json` of the base branch as a baseline and add:

```yaml
      - name: Fail on new high findings
        run: python3 .ehs/scripts/ehs compare baseline/findings.json ehs-out/findings.json --fail-on high
```

`compare` matches findings by the same fingerprint the SARIF export uses (rule, file, component; not the line), so code that moved is not reported as new. A suppressions file (`--suppress`) holds `{fingerprint, reason, expires}` for accepted risks; an expired entry hides nothing.

## What it does not do

It reviews the change, not the repository: a defect in code the pull request does not touch, and does not call, is out of its scope. Run a full audit periodically for that.
