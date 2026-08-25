# Triage stage — arm `with`, run 5

OUTSIDE INFORMATION: only what appears in this prompt and your own reasoning. Nothing else. Do not open files, do not search the repository, and do not use any knowledge of where these cases came from.

Case order seed: `with-5`. Cases digest: `sha256:4c86d0df6c4e2ef76078c7f013d3fe9c0daed413c56d6b6e265b75ff7346734e`.

## The task

For the case below, name the triage rule the offered reason invokes, answer that rule from the closed vocabulary the rules file declares, and state what follows for the finding. Give the reason for the answer, naming the artifact it rests on.

## Reference in context: `triage.md`

# Triage rules — the ten questions that rule a finding out

Half the value of this corpus is knowing when **not** to report. Every procedure carries a `What rules it out (false positive)` field, and until now that field was free prose: nothing named the rules, nothing required an answer, and nothing could check that a specialist had worked through them. A distributed discipline that nobody verifies is a discipline in name only.

This file closes that. Ten rules, each with an identifier, each **answerable**, derived from the exculpating conditions the corpus already uses — they were read out of 370 `What rules it out` bullets, not invented.

## How a rule is answered

Each rule asks whether an **exculpating condition** holds. Four answers, and only these four:

| Answer | Meaning | Consequence |
|---|---|---|
| `HOLDS` | The condition is true **and you can point at the artifact that shows it** | The finding is ruled out, or drops to `informational` if the rule says so |
| `DOES_NOT_HOLD` | You checked and it is false | The finding survives this rule |
| `UNKNOWN` | You could not establish it | The finding **cannot** be reported as `confirmed`; `probable` is its ceiling |
| `NOT_APPLICABLE` | The rule does not apply to this class of finding | Nothing |

Three invariants, and they are the point of the file:

1. **A finding reported as `confirmed` has every invoked rule answered, none of them `HOLDS`, and none of them `UNKNOWN`.** An unanswered rule is not a silent `DOES_NOT_HOLD` — this is the same doctrine as the gates' exit code `2`: could-not-measure is never a pass.
2. **`HOLDS` and `UNKNOWN` require a written reason** naming the file, the line, the configuration or the document that supports the answer. "It looked fine" is not an answer.
3. **Absence of evidence is never `HOLDS`.** `FP-08` exists precisely because the tempting move — "they said the platform handles it" — is the most common way a real finding disappears.

Answers travel with the finding, in the `triage` block of the return format in `references/team.md`, and into the report through `references/report.md`.

## The rules

<!-- triage:rules -->
| Id | The exculpating condition | A `HOLDS` requires |
|---|---|---|
| `FP-01` | **A compensating control enforces it in a layer that cannot be skipped.** Row-level security, a mandatory middleware, a server-side invariant, signature verification with a pinned key. | The control's location, and the argument for why no code path reaches the sink around it. A control that a caller may forget is not this rule. |
| `FP-02` | **The value is not attacker-controlled.** A literal, a constant, a value constrained by an allowlist before it reaches the sink, a placeholder such as `${VAR}` or `changeme`. | The origin of the value traced backwards to something outside an attacker's reach. |
| `FP-03` | **The sink is not dangerous in the form it is reached.** Text rather than HTML, a format that does not execute (`safetensors` rather than a pickle), an API that parses instead of evaluating. | The exact sink call, and what the framework does with that argument in the version in use. |
| `FP-04` | **The path does not exist in what ships.** Debug-only, a test fixture, removed by the release build, behind an environment flag that production does not set. | Evidence from the shipped artifact, not from the source. The build that ships is the authority. |
| `FP-05` | **The exposure is intended and bounded.** A public load balancer on `443`, a log agent that needs host access, a minified bundle that is the declared distribution artifact. | What bounds it — and the finding usually **moves** rather than disappearing, to whatever sits behind the intended exposure. |
| `FP-06` | **No boundary is crossed: there is no second principal.** Same user, a private per-user directory, an internal-only binding, an agent unreachable from outside its orchestrator. | The boundary named explicitly. On a local surface this is `local-app.md` §0, and a finding that cannot name a second principal is a hardening note. |
| `FP-07` | **The data has no security value.** Public content, synthetic fixtures, non-personal records — where `PRV-01` decides what is personal, not intuition. | What the data is, and who decided it is not sensitive. |
| `FP-08` | **The control lives outside the repository and the evidence arrived.** An organization ruleset, a provider console setting, a support subscription, a landing-zone policy. | The exported artifact, the ticket or the written statement. **Without it the answer is `UNKNOWN`, never `HOLDS`** — "the platform takes care of it" is the most common way a real finding disappears. |
| `FP-09` | **The construct is not what it looks like.** A Terraform module rather than a root, a Rails partial, legitimate Unicode in Arabic or Hebrew text, an emoji modifier. | The reading that makes it benign, in a sentence a reviewer can check in one step. |
| `FP-10` | **It is real but bounded to `informational`.** A client-side check whose server-side equivalent exists, a missing attestation where provenance is already stored and verified, a defence in depth that is absent but not load-bearing. | Why the impact does not reach the user: this rule downgrades severity, it does not delete the finding, and the finding is still written down. |
<!-- /triage:rules -->

## What this does not do

It does not decide whether a procedure's detection pattern is right — a wrong pattern produces a finding these rules cannot save you from. It does not measure severity beyond the `FP-10` downgrade. And a rule answered honestly can still be answered wrongly: the rules make the reasoning visible and checkable, not automatically correct.

## Citing them from a procedure

A procedure's `What rules it out (false positive)` field **ends with a line naming the rules it invokes**:

```
Rules: FP-02, FP-04, FP-08
```

The bullets stay as they are — they say what the exculpation looks like in that stack. The line says which questions this class demands, so a specialist knows what must be answered before reporting, and a gate can check that the field was written as a triage step rather than as prose.

Rules are cited where they apply. A procedure that genuinely invokes only one rule cites one, and a procedure whose class admits **no** exculpation writes `Rules: none (reason).` — `AI-22` does, because only the user can change the squad's rules and never the audited content, and three `VER-*` procedures do, because they always run.


Answer every case. For each one return exactly these four fields:

    case         the case id, copied
    rule         the id of the triage rule the offered reason invokes
    answer       one of HOLDS, DOES_NOT_HOLD, UNKNOWN, NOT_APPLICABLE
    why          one sentence, naming the artifact your answer rests on

Return a single JSON array of those objects and nothing else - no prose before
it, no code fence, no commentary after it. An answer outside the four tokens
above is scored as wrong rather than interpreted.


## The cases
### Case TS-09

**Finding.** Shared cache directory created world-writable

The cache helper creates `/var/tmp/appcache` with mode 0777 and writes serialised session objects into it.

`app/cache.py`
```
import os
import pickle

CACHE_DIR = "/var/tmp/appcache"


def _ensure():
    os.makedirs(CACHE_DIR, mode=0o777, exist_ok=True)
    os.chmod(CACHE_DIR, 0o777)


def put(key, value):
    _ensure()
    with open(os.path.join(CACHE_DIR, key), "wb") as fh:
        pickle.dump(value, fh)


def get(key):
    with open(os.path.join(CACHE_DIR, key), "rb") as fh:
        return pickle.load(fh)
```

`deploy/api.service`
```
[Service]
User=invoicer-api
ExecStart=/usr/bin/python -m app.api
```

`deploy/reindex.service`
```
[Service]
User=invoicer-batch
ExecStart=/usr/bin/python -m app.reindex
```

**The reason offered for not reporting it.** The reviewer says the directory belongs to the process that writes it, so there is only one party involved.

**Evidence available.** app/cache.py; deploy/api.service; deploy/reindex.service


### Case TS-06

**Finding.** Administrative command endpoint behind a settings flag

`admin_tools.py` registers `/__ops/run`, which executes a command string from the request body when a settings flag is on.

`src/app/admin_tools.py`
```
import subprocess
from flask import request
from app.settings import settings

def register(app):
    if not settings.DEBUG:
        return
    @app.post("/__ops/run")
    def _run():
        return subprocess.run(request.json["cmd"], shell=True,
                              capture_output=True).stdout
```

`src/app/settings.py`
```
import os
from dataclasses import dataclass

@dataclass(frozen=True)
class Settings:
    DEBUG: bool = os.environ.get("APP_DEBUG", "0") == "1"

settings = Settings()
```

`README.md`
```
## Running locally

    APP_DEBUG=1 python -m app

`APP_DEBUG` turns on the operator endpoints. Production does not set it.
```

**The reason offered for not reporting it.** The reviewer says production never sets the flag, so the route is not registered there.

**Evidence available.** src/app/admin_tools.py; src/app/settings.py; README.md

**Evidence that was asked for and did not arrive.** the built artifact; any deployment manifest, Helm values, task definition or environment listing for a production environment


### Case TS-15

**Finding.** Role check performed in the browser

The bulk-delete control is hidden from non-administrators in the front end, and the check can be removed by anyone editing the page.

`web/src/InvoiceToolbar.jsx`
```
export function InvoiceToolbar({ user, ids }) {
  const canDelete = user.role === 'admin';
  return (
    <div className="toolbar">
      {canDelete && (
        <button onClick={() => bulkDelete(ids)}>Delete selected</button>
      )}
    </div>
  );
}
```

`api/invoices.py`
```
from app.auth import require_role

@app.post("/invoices/bulk-delete")
@require_role("admin")
def bulk_delete():
    ids = request.json["ids"]
    Invoice.query.filter(Invoice.id.in_(ids)).delete()
    return {"deleted": len(ids)}
```

`app/auth.py`
```
def require_role(role):
    def deco(fn):
        @functools.wraps(fn)
        def wrapper(*a, **kw):
            if g.session.role != role:
                abort(403)
            return fn(*a, **kw)
        return wrapper
    return deco
```

**The reason offered for not reporting it.** The reviewer says the same decision is taken again on the server before anything is deleted.

**Evidence available.** web/src/InvoiceToolbar.jsx; api/invoices.py; app/auth.py


### Case TS-05

**Finding.** Administrative command endpoint in the application

`debug_routes.py` registers `/__admin/exec`, which runs a command string taken from the request body.

`src/app/debug_routes.py`
```
import subprocess
from flask import request

def register(app):
    @app.post("/__admin/exec")
    def _exec():
        return subprocess.run(request.json["cmd"], shell=True,
                              capture_output=True).stdout
```

`pyproject.toml`
```
[project]
name = "invoicer"
version = "1.4.0"

[tool.hatch.build.targets.wheel]
packages = ["src/app"]
exclude = ["src/app/debug_routes.py"]
```

`evidence/wheel-listing.txt`
```
$ python -m zipfile -l dist/invoicer-1.4.0-py3-none-any.whl
File Name                                        Modified             Size
app/__init__.py                           2026-08-20 11:04:12         214
app/api.py                                2026-08-20 11:04:12        7710
app/settings.py                           2026-08-20 11:04:12        1902
app/templates/invoice.html                2026-08-20 11:04:12        3140
invoicer-1.4.0.dist-info/METADATA         2026-08-20 11:04:12         988
invoicer-1.4.0.dist-info/RECORD           2026-08-20 11:04:12         512
```

**The reason offered for not reporting it.** The reviewer says the build strips that module before it is published.

**Evidence available.** src/app/debug_routes.py; pyproject.toml; evidence/wheel-listing.txt, a listing of the published wheel taken from the release job


### Case TS-03

**Finding.** Uploaded model file deserialised on the worker

The model-import worker reads an uploaded file and reconstructs a Python object from it.

`worker/import_model.py`
```
import pickle
import io


def load_uploaded_model(blob: bytes):
    # Historically these were .safetensors; the endpoint still accepts both.
    if blob[:8] == b'{"__meta':
        return _load_safetensors(blob)
    return pickle.loads(blob)


def _load_safetensors(blob: bytes):
    import json
    header_len = int.from_bytes(blob[:8], "little")
    return json.loads(blob[8:8 + header_len])
```

`api/models.py`
```
from worker.import_model import load_uploaded_model

@app.post("/models/import")
def import_model(request):
    return load_uploaded_model(request.files["model"].read())
```

**The reason offered for not reporting it.** The reviewer says the loader parses a tensor container rather than evaluating anything.

**Evidence available.** worker/import_model.py in full; api/models.py, the calling endpoint


### Case TS-08

**Finding.** Load balancer security group open to the internet

`alb.tf` allows 0.0.0.0/0 inbound on port 443 to the public load balancer.

`infra/alb.tf`
```
resource "aws_security_group" "alb" {
  name   = "public-alb"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "public" {
  name               = "public-alb"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
}
```

`infra/app.tf`
```
resource "aws_security_group" "app" {
  name   = "app-tier"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]   # only from the ALB
  }
}

resource "aws_instance" "app" {
  count                  = 3
  subnet_id              = var.private_subnet_ids[count.index]
  vpc_security_group_ids = [aws_security_group.app.id]
}
```

**The reason offered for not reporting it.** The reviewer says a public load balancer on 443 is what this component is for, and the tier behind it is reachable only from the balancer.

**Evidence available.** infra/alb.tf; infra/app.tf


### Case TS-04

**Finding.** Customer name rendered into an HTML template

The invoice renderer passes a customer-supplied display name into a template string that is returned as `text/html`.

`render/invoice.py`
```
from jinja2 import Template

TPL = "<div class='header'>Invoice for {{ name }}</div>"


def render_header(name: str) -> str:
    return Template(TPL).render(name=name)
```

`requirements.txt`
```
flask>=2.0
jinja2>=2.10
psycopg2-binary>=2.9
```

`Dockerfile`
```
FROM python:3.11-slim
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . /app
CMD ["python", "-m", "app"]
```

**The reason offered for not reporting it.** The reviewer says the template engine escapes the value on its way out.

**Evidence available.** render/invoice.py; requirements.txt; Dockerfile

**Evidence that was asked for and did not arrive.** any lock file, `pip freeze` output, or image manifest that resolves the template engine to a single version


### Case TS-12

**Finding.** Repository has no branch-protection configuration in the tree

Nothing in the checkout requires review before a change reaches the default branch, and the deploy workflow runs from it.

`.github/workflows/deploy.yml`
```
name: deploy
on:
  push:
    branches: [main]
permissions:
  contents: read
  id-token: write
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh
```

`evidence/org-ruleset-export.json`
```
{
  "id": 4417,
  "name": "require-review-everywhere",
  "target": "branch",
  "source_type": "Organization",
  "source": "example-org",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] },
    "repository_name": { "include": ["~ALL"], "exclude": [] }
  },
  "rules": [
    { "type": "pull_request",
      "parameters": { "required_approving_review_count": 2,
                      "dismiss_stale_reviews_on_push": true } },
    { "type": "non_fast_forward" }
  ]
}
```

**The reason offered for not reporting it.** The reviewer says an organisation ruleset enforces review on the default branch of every repository.

**Evidence available.** .github/workflows/deploy.yml; evidence/org-ruleset-export.json, exported from the organisation settings on 2026-08-20 and attached to the engagement


### Case TS-07

**Finding.** Test-only credential helper reachable from the package

`fixtures/seed_users.py` writes a fixed administrator password and is described in review as test scaffolding.

`src/app/fixtures/seed_users.py`
```
from app.db import session
from app.models import User

# Used by the integration suite to get a known operator account.
def seed():
    session.add(User(email="ops@example.test", password="Sup3rS3cret!",
                     role="admin"))
    session.commit()
```

`pyproject.toml`
```
[project]
name = "invoicer"
version = "1.4.0"

[tool.hatch.build.targets.wheel]
packages = ["src/app"]
```

`evidence/wheel-listing.txt`
```
$ python -m zipfile -l dist/invoicer-1.4.0-py3-none-any.whl
File Name                                        Modified             Size
app/__init__.py                           2026-08-20 11:04:12         214
app/api.py                                2026-08-20 11:04:12        7710
app/db.py                                 2026-08-20 11:04:12        2201
app/fixtures/__init__.py                  2026-08-20 11:04:12           0
app/fixtures/seed_users.py                2026-08-20 11:04:12         381
app/models.py                             2026-08-20 11:04:12        4402
app/settings.py                           2026-08-20 11:04:12        1902
invoicer-1.4.0.dist-info/RECORD           2026-08-20 11:04:12         512
```

**The reason offered for not reporting it.** The reviewer says this is a test fixture and does not reach the distribution.

**Evidence available.** src/app/fixtures/seed_users.py; pyproject.toml; evidence/wheel-listing.txt, a listing of the published wheel taken from the release job


### Case TS-13

**Finding.** Repository has no branch-protection configuration in the tree

Nothing in the checkout requires review before a change reaches the default branch, and the deploy workflow runs from it.

`.github/workflows/deploy.yml`
```
name: deploy
on:
  push:
    branches: [main]
permissions:
  contents: read
  id-token: write
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh
```

`evidence/org-ruleset-export.json`
```
{
  "id": 4418,
  "name": "require-review-everywhere",
  "target": "branch",
  "source_type": "Organization",
  "source": "example-org",
  "enforcement": "evaluate",
  "conditions": {
    "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] },
    "repository_name": { "include": ["~ALL"],
                         "exclude": ["example-org/invoicer"] }
  },
  "rules": [
    { "type": "pull_request",
      "parameters": { "required_approving_review_count": 2 } }
  ]
}
```

**The reason offered for not reporting it.** The reviewer says an organisation ruleset enforces review on the default branch of every repository.

**Evidence available.** .github/workflows/deploy.yml; evidence/org-ruleset-export.json, exported from the organisation settings on 2026-08-20 and attached to the engagement; the repository is example-org/invoicer


### Case TS-10

**Finding.** Workflow runs a third-party action from a moving reference

The release workflow calls a third-party action at a branch reference, so the code it runs can change between runs without the repository changing.

`.github/workflows/release.yml`
```
name: release
on:
  push:
    tags: ['v*']
permissions:
  contents: write
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: some-vendor/publish-action@main
        with:
          token: ${{ secrets.REGISTRY_TOKEN }}
```

**The reason offered for not reporting it.** The reviewer says everything this pipeline touches is open-source code that anyone can read, so there is no sensitive material at stake.

**Evidence available.** .github/workflows/release.yml


### Case TS-11

**Finding.** Release workflow can be triggered by any pushed branch

The release workflow reads a registry credential and runs on any pushed branch, so a contributor with push access can publish from unreviewed code.

`.github/workflows/release.yml`
```
name: release
on:
  push:
permissions:
  contents: write
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/publish.sh
        env:
          REGISTRY_TOKEN: ${{ secrets.REGISTRY_TOKEN }}
```

`CONTRIBUTING.md`
```
## Review

Every change is reviewed before it lands. Direct pushes to protected branches
are not part of our process.
```

**The reason offered for not reporting it.** The reviewer says the organisation applies a ruleset that requires review everywhere, so the platform handles this outside the repository.

**Evidence available.** .github/workflows/release.yml; CONTRIBUTING.md

**Evidence that was asked for and did not arrive.** any export of the organisation ruleset; any branch-protection settings export; a ticket or written statement from whoever administers the organisation


### Case TS-14

**Finding.** Storage bucket declared without a public-access block

`main.tf` declares a bucket and no `aws_s3_bucket_public_access_block` accompanies it.

`main.tf`
```
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration { status = var.versioning }
}

output "bucket_id"  { value = aws_s3_bucket.this.id }
output "bucket_arn" { value = aws_s3_bucket.this.arn }
```

`variables.tf`
```
variable "bucket_name" { type = string }
variable "tags"        { type = map(string), default = {} }
variable "versioning"  { type = string, default = "Enabled" }
```

`versions.tf`
```
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
```

**The reason offered for not reporting it.** The reviewer says this directory is not the thing that gets applied.

**Evidence available.** main.tf; variables.tf; versions.tf; the full file listing of the directory, which contains no other .tf file


### Case TS-01

**Finding.** Report filter concatenated into SQL

The `/reports` handler builds its WHERE clause by concatenating the `org` query parameter into the statement text before it reaches the driver.

`routes/reports.js`
```
const express = require('express');
const router = express.Router();
const { pool } = require('../lib/db');
const { sanitizeQuery } = require('../lib/sanitize');

// The billing export goes through the sanitiser.
router.get('/billing', sanitizeQuery, async (req, res) => {
  const rows = await pool.query('SELECT * FROM invoices WHERE org = $1', [req.query.org]);
  res.json(rows);
});

// The report export does not.
router.get('/reports', async (req, res) => {
  const sql = "SELECT id, total FROM reports WHERE org = '" + req.query.org + "'";
  const rows = await pool.query(sql);
  res.json(rows);
});

module.exports = router;
```

`lib/sanitize.js`
```
// Strips quotes and semicolons from every value in req.query.
// Applied per route, by the route author.
function sanitizeQuery(req, res, next) {
  for (const k of Object.keys(req.query)) {
    req.query[k] = String(req.query[k]).replace(/['";]/g, '');
  }
  next();
}
module.exports = { sanitizeQuery };
```

**The reason offered for not reporting it.** The team says a sanitising middleware covers the query parameters on this router.

**Evidence available.** routes/reports.js in full; lib/sanitize.js in full


### Case TS-02

**Finding.** Archive name interpolated into a shell command

`backup.py` builds a `tar` command line by interpolation and runs it through a shell.

`jobs/backup.py`
```
import subprocess
import datetime

ARCHIVE_PREFIX = "nightly"          # module constant, never reassigned
RETENTION_DAYS = 14


def run_backup(data_dir):
    stamp = datetime.date.today().isoformat()
    cmd = f"tar -czf /var/backups/{ARCHIVE_PREFIX}-{stamp}.tgz {data_dir}"
    subprocess.run(cmd, shell=True, check=True)


def prune():
    subprocess.run(
        f"find /var/backups -name '{ARCHIVE_PREFIX}-*.tgz' -mtime +{RETENTION_DAYS} -delete",
        shell=True, check=True)
```

`jobs/schedule.py`
```
from jobs.backup import run_backup, prune

# The only two call sites in the tree.
def nightly():
    run_backup("/srv/app/data")
    prune()
```

**The reason offered for not reporting it.** The reviewer says the interpolated pieces never come from a request.

**Evidence available.** jobs/backup.py in full; jobs/schedule.py, which holds the only call sites in the tree
