# Knowledge pack - privacy-abuse

> **When to load this file:** when the project handles data about identifiable people (accounts, profiles, contacts, location, health, payments, user content) or exposes flows a third party can abuse at scale.
> **Do not load it if:** the artifact processes no personal data (a computation library, a template engine, a CLI with no telemetry). The risk there is purely technical and the other roles cover it.
> **Cost:** ~328 lines. Load by section using the index; §1 first, always.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §1 Inventory and classification | models, schemas, migrations, DTOs holding data about people | PRV-01, PRV-02 |
| §2 Minimization and retention | historical fields, backups, soft delete, exports | PRV-03, PRV-04 |
| §3 Multitenant isolation | more than one customer or organization in the same database | PRV-05 |
| §4 Telemetry and third-party SDKs | analytics, crash reporting, pixels, mobile SDKs | PRV-06 |
| §5 Data entering AI models | prompts with real data, fine-tuning, external provider | PRV-07 |
| §6 Data subject rights | end-user accounts, privacy panel, support | PRV-08 |
| §7 Leakage through logs and errors | structured logging, APM, traces, Sentry | PRV-09 |
| §8 Product abuse paths | open sign-up, invitations, referrals, user search | PRV-10, PRV-11 |
| §10 Where the data lands | any `region`/`location` argument, cross-region replication, global services, a declared jurisdiction | PRV-12 |
| §9 Traceability of reads | admin panels, support tooling, BI over a production replica, cloud stores holding personal data | PRV-13 |

`PRV-12` is reserved for the pending data-location procedure (where the personal data physically lands and where it is replicated). The gap in the numbering is deliberate, not a procedure lost in a merge.

## How to use a procedure

Locate the data with **Where to look**, confirm it against **Vulnerable pattern** and clear it with the false positives before writing. **Minimal test** runs only with synthetic data and on environments you own; never query real people's records to demonstrate a finding, the schema and one test row are enough. In **Traceability** use technical identifiers.

**Hard rule of this role, apply it to every finding before reporting it.** Always separate three things and label them:
- **Technical vulnerability**: a control is missing or broken and it can be demonstrated (an endpoint returns another user's data).
- **Privacy risk**: the system works as designed, but collects, retains or shares more than necessary. There is no bug; there is exposure.
- **Product decision**: someone deliberately chose that behavior (open sign-up, public profiles, unlimited invitations). Report it as a risk with mitigation options, not as a defect.

Second rule: **do not rule on legal compliance.** We are not lawyers and the applicable framework depends on jurisdiction, processing role and contracts you cannot see. Describe the observed technical fact and, at most, point out what kind of obligation might be touched (minimization, storage limitation, data subject rights, third-party transfers) using conditional wording. Never write that the project breaches a regulation.

## §1 Inventory and classification of personal data

### PRV-01 Inventory: where the personal data actually lives

**Where to look**
- Schema: `models.py`, `schema.prisma`, `entity/*.ts`, `*.sql`, `migrations/**` → names such as `email`, `phone`, `dni`, `nit`, `address`, `lat`, `lon`, `birth`, `ip`, `device_id`
- Outside the database: queues and their payloads, uploaded files, caches (Redis), search indexes, exported spreadsheets, fixtures and test seeds holding real data

**Vulnerable pattern**
There is no inventory and no classification: nobody knows which fields are personal, which are sensitive (health, biometrics, political opinion, sexual orientation, financial situation) and which are merely operational. Without that, no later decision on retention, encryption or access can be correct, because there is no way to know what to apply it to. A frequent alarm signal: test fixtures or development dumps holding real production data.

**What rules it out (false positive)**
- A maintained data map exists (even as a markdown file) covering store, field, category and owner, and it matches the real schema.
- The fields that look personal are synthetic and a check prevents loading real data outside production.

**Minimal test**
Generate the schema column list and classify it into three buckets: direct identifier / personal attribute / sensitive data. The absence of that list in the repository is already the finding (privacy risk, not vulnerability).

**Traceability**: `CWE-359` · `CWE-200` · `ASVS 5.0 V14` · `MASVS-PRIVACY-1` when a mobile app is in scope
**Tooling**: `rg -in "email|phone|telefono|cedula|dni|nit|address|birth|latitude|ip_addr|device_id" --glob '*migrations*'` → name-based candidates. Conclude nothing from the name: a free-text `notes` field can hold more personal data than one called `email`.

### PRV-02 Over-exposure in API responses and serializers

**Where to look**
- Serializers and DTOs: `ModelSerializer` with no explicit `fields`, `select *`, `res.json(user)`, an inherited `toJSON()`, a missing `@Expose()`
- Error and listing responses; search or autocomplete endpoints returning the whole object

**Vulnerable pattern**
```python
class UserSerializer(ModelSerializer):
    class Meta:
        model = User
        fields = "__all__"      # drags along hash, phone, internal notes
```
The whole object travels to the client and the frontend only displays the name. The data already left the server: hiding it in the interface does not protect it. A common variant: a mention autocomplete returning the email and phone of any user in the organization.

**What rules it out (false positive)**
- The field list is explicit and a test fails when a new undeclared field appears.
- The endpoint is internal, authenticated with a service credential and not reachable from the browser.

**Minimal test**
Call the endpoint with a test user and compare the returned JSON against what the interface displays. Every extra field is a finding. Synthetic data, environment you own.

**Traceability**: `CWE-200` · `CWE-213` · `A01:2025` · `ASVS 5.0 V4` · `ASVS 5.0 V14`
**Tooling**: `rg -n '"__all__"|SELECT \*|res\.json\(user' ` → candidates. A hit requires seeing the real response: the ORM may exclude fields by another route.

## §2 Minimization and retention

### PRV-03 Data collected and stored without use

**Where to look**
- Sign-up and profile forms against real usage: search for every schema field across the rest of the code
- Webhooks and integrations that persist the whole payload "just in case"; audit tables that copy the full record

**Vulnerable pattern**
Fields appearing only in the model, the migration and the form, and nowhere in business logic. They were requested once, nobody uses them, and they sit there increasing the impact of any future breach. Typical case: a full date of birth when the product only needs to know whether the user is of legal age; or storing the raw payment gateway payload with the cardholder name and last digits.

**What rules it out (false positive)**
- The field is used in a job, a report or an integration that grep does not reach (search email templates and BI queries too before reporting it).
- There is documented justification for why it is collected.

**Minimal test**
For every personal field in the schema, `rg` its name across the whole repository and count uses outside model, migration and form. Zero uses = minimization candidate.

**Traceability**: `CWE-359` · `ASVS 5.0 V14` · `MASVS-PRIVACY-2` when a mobile app is in scope
**Tooling**: `rg -c "<field>" --stats` per field. A zero does not prove it is useless: it may be consumed from another repository or from the analytics warehouse.

### PRV-04 Retention: soft delete that deletes nothing, and eternal copies

**Where to look**
- `deleted_at`, `is_active`, `soft_delete`, `paranoid`, `SoftDeleteMixin`, and what the "delete account" path actually does
- Backups and their rotation; read replicas; the analytics warehouse and spreadsheet exports; uploaded files in the bucket; caches and queues with infinite TTL

**Vulnerable pattern**
Deleting the account flips a flag and all personal data stays indefinitely, including derived data: analytics events, sent emails, bucket attachments, rows in the analytics warehouse, entries in the search index. There is no retention policy and no task enforcing expiry. Backups are kept without limit and nobody knows whether deletion should propagate to them.

**What rules it out (false positive)**
- The soft delete is intentional and bounded (a known recovery window) and a job purges or anonymizes at expiry, with evidence that it runs.
- The retained data is strictly what an accounting or legal obligation requires keeping, and it is segregated with restricted access.

**Minimal test**
Follow the account deletion path and list every store the data reached (database, bucket, index, analytics, email, queues). Mark which ones deletion propagates to. The ones left without propagation are the finding. Use a synthetic account created for the test.

**Traceability**: `CWE-212` · `CWE-359` · `ASVS 5.0 V14`
**Tooling**: `rg -n "deleted_at|soft_delete|paranoid|is_deleted"` and the bucket retention configuration. The existence of `deleted_at` says nothing about propagation; you have to trace it.

## §3 Multitenant isolation and direct object references

### PRV-05 Separation between customers and access by identifier

This procedure **overlaps with the web-api role**: there it is broken access control (A01) and here it is exposure of third-party data. Say so explicitly in the report and cross-reference: one single finding with both readings, not two findings. If the web-api role is active in the audit, hand it the technical demonstration and keep the impact assessment on the affected people.

**Where to look**
- Queries filtering by resource identifier but not by tenant: `.get(id=`, `findById(`, `where id = ?`
- The middleware or policy injecting the tenant (mandatory, or forgettable in a new endpoint?); sequential identifiers in URLs, exports and shared files

**Vulnerable pattern**
Isolation depends on every query remembering to add the filter. A single new endpoint written in a hurry is enough to expose another organization's records. Sequential identifiers make it worse, because enumeration is trivial and the leak goes from one record to the whole set.

**What rules it out (false positive)**
- The tenant filter is applied in a mandatory layer (row-level security in the database, a default manager, an access policy) that cannot be skipped by oversight.
- The identifier is opaque and unguessable, and there is also an ownership check (the first alone is not enough).

**Minimal test**
Integration test with two synthetic tenants: A requests one of B's identifiers and must receive 404 or 403 without leaking whether the resource exists.

**Traceability**: `CWE-284` · `CWE-639` · `A01:2025` · `ASVS 5.0 V8`
**Tooling**: `rg -n "objects\.get\(|findById\(|findOne\(\{ *id" -A2` → queries with no visible filter. A hit may be covered by a default manager; confirm before reporting.

## §4 Telemetry and third-party SDKs

### PRV-06 What leaves the product, to whom, and on what basis

**Where to look**
- Web: `gtag(`, `analytics.track(`, `Sentry.init(`, `posthog`, `mixpanel`, `hotjar`, pixels and tags in the HTML; and the `beforeSend`/scrubbing configuration
- Mobile: dependencies in `build.gradle` / `Podfile`, `Firebase`, `AppsFlyer`, `Adjust`, `Facebook SDK`; `AndroidManifest.xml` and `Info.plist` for permissions and identifiers. And the consent manager: does it block the SDK from loading until acceptance, or does it load anyway and only flip a flag?

**Vulnerable pattern**
The SDK starts on first render and sends device identifiers, IP address and navigation path before any interaction. The event property carries the user's email as the identifier. In a mobile app, the crash reporting session attaches the last screen with form data. Nobody holds the list of which events are sent or with which fields.

**What rules it out (false positive)**
- The SDK loads only after effective consent, with a pseudonymous identifier, and scrubbing is configured and verified over what is sent.
- Telemetry is first-party, stays on project infrastructure and never travels to a third party.

**Minimal test**
Open the product with the network console and list the destination domains and the body of the first events, before and after accepting consent. On mobile, review the dependency declaration and the declared permissions. Environment you own, synthetic account.

**Traceability**: `CWE-359` · `CWE-200` · `ASVS 5.0 V14` · `MASVS-PRIVACY-1`, `MASVS-PRIVACY-3` (the PRIVACY group of MASVS v2.1.0, 4 controls)
**Tooling**: the browser network tab or `rg -n "gtag|mixpanel|posthog|Sentry.init|AppsFlyer|Adjust"`. The presence of an SDK says nothing about what it sends; only observed traffic does. And what you observed in your session does not cover every path in the product.

## §5 Data entering AI models

### PRV-07 PII in prompts, training and provider logs

**Where to look**
- Where the prompt is built: which user fields get interpolated (see AI-02 in the ai-safety pack)
- Provider configuration: retention, consent for training use, processing region and request logging; and the fine-tuning or evaluation pipelines, where their examples come from

**Vulnerable pattern**
The full conversation history, with name, email, address and purchase history, is sent to an external API on every turn; the provider logs it and the organization has no signed agreement on retention. Worse variant: a fine-tuning dataset built from real support conversations without pseudonymization, so personal data becomes embedded in the weights and is no longer selectively deletable.

**What rules it out (false positive)**
- Data is pseudonymized before sending (identifiers replaced by tokens reversible only inside the system) and the prompt carries only what the task needs.
- The model runs on first-party infrastructure with no transfer to a third party, or there is an agreement with zero retention verifiable in the configuration.

**Minimal test**
Capture a real assembled prompt in a development environment with synthetic data and classify every interpolated field: necessary / unnecessary / sensitive. And check in the provider console whether retention and training use are disabled.

**Traceability**: `LLM02:2026` · `CWE-359` · `CWE-200` · `ASVS 5.0 V14`
**Tooling**: review of the prompt builder. A field that is necessary today may stop being so after a product change; record the criterion, not just the list.

## §6 Data subject rights

### PRV-08 Export, portability, rectification and deletion

**Where to look**
- Endpoints or screens for "download my data", "delete account", "correct my data"; administrative tasks support performs by hand today
- What the export includes against the PRV-01 inventory

**Vulnerable pattern**
Account deletion is executed by an engineer with direct database access whenever a request arrives by email, with no log, no deadline and no identity check. Or automated export exists but covers only the main table and omits attachments, messages and analytics events, so the data subject receives a fraction of what is held. Third variant: there is no identity verification at all, so the rights mechanism itself becomes a leak channel.

**What rules it out (false positive)**
- The flows exist, are automated, require step-up authentication, cover the full inventory and leave an auditable trail.
- The product has no identifiable end users (an internal tool with corporate accounts managed by the customer, who owns those flows).

**Minimal test**
Run the export with a synthetic account that generated data in every store from PRV-04 and compare the file contents against the inventory. Every missing store is a finding.

**Traceability**: `CWE-359` · `ASVS 5.0 V14` · `MASVS-PRIVACY-4` when a mobile app is in scope
**Tooling**: manual review of the flow. Describe the technical fact (the export omits X) without asserting a breach of any regulation.

## §7 Leakage through logs, errors and traces

### PRV-09 Personal data in logs, exceptions and APM

**Where to look**
- `logger.info(f"...{user}...")`, `console.log(req.body)`, `print(payload)`, middleware logging full request and response
- Exception handlers including body or parameters; `Sentry` without `send_default_pii=False`; traces carrying user attributes. And where those logs end up: aggregator retention, who has access, whether they leave the organization

**Vulnerable pattern**
```python
logger.info("record received: %s", request.body)   # email, phone, national ID
```
The application log ends up holding the same data as the database but with none of its controls: different retention, different encryption, far broader access (the whole engineering team and often a SaaS provider). The URL counts too: identifiers and emails in the query string stay in the load balancer log, the proxy log and the browser.

**What rules it out (false positive)**
- There is centralized redaction by field list applied in the formatter, with a test covering it, and the APM has PII sending disabled.
- Only opaque identifiers are logged, with no personal attributes, and correlation requires database access.

**Minimal test**
Trigger a validation error with a synthetic account and search for its values in the log output. If they appear, it is proved. Do not run this test against production nor with real people's data.

**Traceability**: `CWE-532` · `CWE-359` · `A09:2025` · `ASVS 5.0 V16`
**Tooling**: `rg -n "log.*(request\.body|req\.body|payload|user\b)" -g '!*test*'` → candidates. A hit requires looking at the formatter: there may be redaction downstream.

## §8 Product abuse paths

Advance warning, mandatory in the report: **what follows is almost never a technical vulnerability.** These are product design properties a third party can exploit at scale. Report them labelled as a product decision or abuse risk, with the cost of mitigating and the cost of not mitigating, and leave the decision to the product owner. Confusing this with a vulnerability creates noise and burns the report's credibility.

### PRV-10 User enumeration and directory scraping

**Where to look**
- Differentiated responses in sign-up, login, password recovery and invitation ("that email already exists" versus a neutral message); and response time differences between existing and non-existing
- User search endpoints, mention autocomplete, public profiles by sequential identifier and sitemaps; and the rate limiting: does it exist, and on which key (IP, account, session)?

**Vulnerable pattern**
An attacker confirms whether an email has an account and, with unrate-limited user search, rebuilds the full directory with name, photo and job title. No control is broken: every individual request is legitimate. The damage is in the volume, and the volume is unbounded.

**What rules it out (false positive)**
- Responses are uniform in content and timing, and there is rate limiting per account and per origin on the search endpoints.
- The directory is public by design and communicated as such to users (then it is a documented product decision, not a finding).

**Minimal test**
Compare the response and the timing for an existing and a non-existing email, with synthetic accounts you own. Two requests are enough: do not generate volume to prove it.

**Traceability**: `CWE-204` · `CWE-200` · `CWE-799` · `A07:2025` · `ASVS 5.0 V6` · `ASVS 5.0 V7`
**Tooling**: `curl` with two cases and timing measurement. A small difference may be network noise; repeat a few times before asserting it.

### PRV-11 Abuse of invitations, referrals and flows with economic value

**Where to look**
- Sign-up: is the email verified before value is granted? are plus-addressing aliases and disposable domains accepted?
- Referrals and credits: where the reward is credited and what triggers it; whether the same device, card or IP can claim it several times
- Invitations: how many a new account can send, with what free text and from which sender; idempotency and race conditions in balance crediting

**Vulnerable pattern**
An unverified new account can send unlimited invitations with free text from the product's domain: the attacker uses your email reputation to deliver spam or phishing. Or the referral program credits balance when the invitee signs up, with no cross-verification, so one person creates accounts in a loop and turns the mechanism into a tap. The race condition in crediting allows claiming the same reward several times with simultaneous requests.

**What rules it out (false positive)**
- Value is credited after a verified milestone (payment, real usage) and there is duplicate control based on independent signals, plus idempotency in the balance operation.
- Sends go out with the system's own sender, a per-account quota and templated content with no free text.

**Minimal test**
Model the flow on paper: cost to the attacker, value obtained, controls it crosses. If the value exceeds the cost and there is no intermediate verification, it is proved without executing anything. **Do not abuse the real flow**: sending invitations or creating accounts in volume affects third parties and falls outside the security contract.

**Traceability**: `CWE-841` · `CWE-799` · `CWE-362` · `A06:2025` · `ASVS 5.0 V2`
**Tooling**: manual review of the flow plus a local concurrency test on the crediting operation. A theoretically possible abuse does not always deserve mitigation: present it with its cost and let others decide.

## §9 Traceability of reads

### PRV-13 Reading personal data leaves no trace

This procedure **overlaps with the infra-cloud role**: `INF-06` audits control-plane logging — who changed the infrastructure. This one covers the data plane — who read the record. They are different switches, and the data-plane one is off by default in the three major providers and billed by volume, which is precisely why it stays off. Report a single finding with both readings and cross-reference it, never two.

**Where to look**
- The data-plane switch in the infrastructure code, which is a separate object from the audit trail itself: `aws_cloudtrail` with an `event_selector` / `advanced_event_selector` covering a `data_resource` (S3 objects, DynamoDB tables); `google_project_iam_audit_config` with `log_type = "DATA_READ"` (admin activity is recorded by default, data access is not); `azurerm_monitor_diagnostic_setting` attached to the storage or database sub-resource with the read category enabled, not only the write one
- The application side, where most reads actually happen: generated back offices and admin panels, the support tool, BI or notebooks pointed at a production replica, a shared database account used from a bastion, and the export button — the read that takes the whole table at once
- The trail itself: where it is written, who can delete or rewrite it, how long it is kept, and whether it now duplicates the personal data it was meant to account for (PRV-09)

**Vulnerable pattern**
```hcl
resource "aws_cloudtrail" "audit" {   # every API call that CHANGES something
  is_multi_region_trail = true
}                                     # and not one data event selector: who read
                                      # the objects is recorded nowhere
```
Every write is audited and no read is. After an incident nobody can answer the only question the affected people care about — whose data was read — so the whole population has to be treated as affected. Two variants look covered and are not: read logging enabled on the main database while the same data also lives in the search index, the analytics warehouse, the exports bucket and the backups, so the answer is still no; and a "trail" that is really the request log at INFO level, with no actor, no subject and no reason, which on top of everything else is a PRV-09 finding. The internal case is more frequent than the external one: a support tool where any agent opens any account, with no reason recorded and no entry written.

**What rules it out (false positive)**
- Read logging is enabled on the stores PRV-01 says hold personal data — all of them, not only the primary — with retention that outlives a plausible detection window, and written where the identity that reads the data cannot delete or rewrite it. Retention shorter than that window reduces the finding; it does not clear it.
- Every operator read goes through an application layer that records actor, subject identifier, timestamp and reason, and that record is reviewed by someone other than the person using the tool. The provider-level switch is then defence in depth, and anything missing is reported at that lower severity.
- The store holds no personal data — PRV-01 decides that, not the resource name. A missing read trail on a build-artifact bucket belongs to `INF-06`, not to this role.

What does **not** rule it out: a SIEM connected to the account while the read category is disabled at the source; "the provider keeps 90 days of everything", which is the control plane; masking or dynamic data masking, which changes what the reader sees and records nothing about the read; and access reviews, which say who *could* read, never who *did*.

**Minimal test**
Two steps, both non-destructive. First, diff the configuration against the inventory —
`rg -n 'DATA_READ|advanced_event_selector|data_resource|StorageRead|category *= *"\w*Read"' -g '*.tf' -g '*.bicep' -g '*.y*ml'`
— and every store from PRV-01 with no hit is a candidate. Second, settle the application side with one synthetic subject in an environment you own: read it once through each operator path (admin panel, support tool, direct query, export) and then look for the entry with `rg -n "<synthetic_subject_id>" ./logs`. A path that produced no entry naming actor and subject is the finding. Never demonstrate this over a real person's record: the paths are enumerated from the code and the configuration, and the single read you perform is against data you created. If the destination is the provider's log service rather than a local file, querying it touches the client's own account and runs only inside the engagement's written scope (REQUIRES AUTHORIZATION).

**Traceability**: `CWE-778` · `CWE-223` · `CWE-359` · `A09:2025` · `ASVS 5.0 V14` · `ASVS 5.0 V16` · `NIST 800-53 AU` · `CCM LOG`
**Tooling**: no scanner reports this well — an infrastructure rule sees the trail resource and passes, which is how it stays missing for years; cross-reference `INF-06` and the infra-cloud material on audit trails the workload identity can delete. Expect "we turned it off because it costs money" as the honest answer, because these logs are billed by volume. Apply the first hard rule of this role when writing it up: with no demonstrated unauthorized read this is a privacy risk, and once it was switched off knowingly it is also a product decision with a named owner — report it as an accepted risk whose consequence is spelled out (every incident is scoped to the entire population), not as a technical vulnerability and not as an oversight.

## §10 Where the data lands

### PRV-12 Where the personal data physically lands, and where it is replicated

**Where to look**
- The `region`/`location` argument of every resource holding data, and the difference between the product's declared jurisdiction and the actual region of the primary store, the backups, the queues, the search index and the CDN
- Replication and global services: cross-region bucket replication, global tables, multi-region accounts, read replicas in another region, and the third parties from PRV-06 and PRV-07, whose processing region is a configuration setting rather than a property of the product

**Vulnerable pattern**
The product is described as operating in one jurisdiction and the code deploys the database in another; or the primary store is correct and the backups, logs and analytics events replicate to a second region nobody wrote down. The most common variant is the invisible one: the main database is regional and correct while the error tracker, the analytics platform and the model provider are global by default.

**What rules it out (false positive)**
- There is a written statement of where each category of data is stored and processed, it covers backups, logs and third parties, and it matches the code
- The data is not personal — PRV-01 decides that, not intuition

**Minimal test**
For every store in the PRV-01 inventory, write down four values: region of the primary, of the backup, of the replicas, and of the third parties that receive it. The finding is any store where the code disagrees with the declared statement, or where no statement exists. State the technical fact ("backups land in region X") and **do not rule on whether a transfer is lawful**: that depends on contracts and jurisdictions you cannot see — the second hard rule of this role applies in full.

**Traceability**: `CWE-359` · `CWE-200` · `ASVS 5.0 V14` · `CCM DSP`
**Tooling**: `rg -n 'region|location\s*=' --glob '*.tf'` produces candidates and nothing else; the interesting part usually lives in a provider console (PRV-06, PRV-07), not in the repository. Declare in the report which third parties you could not check.
