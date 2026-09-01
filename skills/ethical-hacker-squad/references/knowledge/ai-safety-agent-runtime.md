# Knowledge pack - ai-safety (agent runtime: packages, boundary, topology and accountability)

> **When to load this file:** the target installs or ships agent packages (a skill, a plugin, an editor extension, a rules file), hands an agent a shell or a filesystem write tool, runs two or more agents that pass work to each other, takes actions with real effects whose author has to be reconstructable weeks later, or reaches a model provider through a base URL that configuration decides.
> **Do not load it if:** there is a single agent with no installable package, no write or shell tool, no side effects and a provider endpoint fixed in code — the prompt boundary and the tool chain are already covered by `ai-safety.md` §0-§3.
> **Cost:** ~180 lines. Third file of this pack. `ai-safety.md` holds §0-§3 (`AI-01`..`AI-11`) plus the identifier compatibility notes that govern all three files; `ai-safety-data-output.md` holds §4-§10 (`AI-12`..`AI-22`, `AI-24`). `AI-01` orders this file too: every procedure below assumes you already know which agent holds which tool.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §11 Agent packages and execution boundary | installable skills, plugins or extensions; a shell or write tool; credentials in the launching environment | AI-25, AI-28 |
| §12 Multi-agent topology and accountability | two or more agents, a handoff route or queue, actions with irreversible effects | AI-26, AI-27 |
| §13 The inference endpoint | a base URL, an AI gateway or a proxy between the client and the model provider; any provider host that configuration can move | AI-30 |

## How to use a procedure

Locate the pattern with **Where to look**, using the globs of the real stack rather than the ones in the example. Confirm it against **Vulnerable pattern** and clear it with the false-positive list before writing anything down. Run **Minimal test** only if it is local, inert and imposes no cost on someone else; if it needs a live endpoint, mark it `REQUIRES AUTHORIZATION` and do not run it. Report using the identifiers in **Traceability**, and describe what the tool proves, never what it suggests. The full statement of the contract is in `ai-safety.md`.

## §11 Agent packages and execution boundary

Both procedures here are read from configuration and are visible before any attack takes place: they describe what the agent is permitted to do, not what someone managed to make it do.

### AI-25 Agent skills and plugins: declared capability versus what the package does

A skill or a plugin is not a document. It is instructions the model obeys, plus files that may execute, plus a declared permission set — installed with one command and refreshed without one. OWASP gave the class its own top ten in 2026 (`AST01`..`AST10`); the three that drive this procedure are malicious skills, over-privileged skills and update drift.

**Where to look**
- Manifests: `skills/*/SKILL.md` frontmatter (`name`, `description`, `allowed-tools`), `.claude-plugin/plugin.json` and its `agents`, `hooks`, `commands` and `mcpServers` entries, a `.mcp.json` bundled inside the package, `manifest.json`, `package.json` `contributes` and `activationEvents`, `.cursor/rules/**`
- What ships beside the manifest: `scripts/**`, `hooks/**`, `bin/**`, `*.sh`, `*.py`, `postinstall`, and every network call inside them
- The declaration of each subagent the package ships: the tools it grants itself, next to the role its own description claims
- Installation and update: the marketplace entry or git URL, whether a commit or a version is pinned, and whether updates apply on their own

**Vulnerable pattern**
Three findings live here.
1. The manifest declares narrow capability while a bundled file does something else — reads `~/.aws/credentials`, curls an endpoint, appends to a shell rc file.
2. The declared permission set is wider than the task needs: a general shell tool for a formatting helper, or a subagent whose description says read-only while its declaration grants a shell. Any injection landing in that session inherits the whole set.
3. The source is a marketplace entry or a git URL with no pinned revision and automatic updates, so what was reviewed once is not what runs tomorrow — the rug pull of `AI-08`, applied to packages instead of tool descriptions.

Then apply `AI-01` to the package itself: instructions, private data and an egress path inside a single installable unit is the lethal trifecta with an installer attached.

**What rules it out (false positive)**
- First-party package living in this repository, covered by `CODEOWNERS` with security review, installed from a pinned commit or digest.
- The manifest declares no capability with side effects and the directory ships no executable file: a documentation-only package, whose remaining risk is its text (`AI-04`).
- Execution is confined to a sandbox with no credentials and no network, and the confirmation prompt shows the literal command (`AI-07`).
- The wide permission is exercised by a step that a gate outside the model authorizes — a CI job, a signed workflow — and not by the model's own decision.

Rules: FP-01, FP-02, FP-05.

**Minimal test**
One two-column table per package: capability declared in the manifest, against capability observed in the files it ships. Build the right-hand column with `rg -n "curl|wget|requests\.|urllib|subprocess|os\.environ|~/\.aws|~/\.ssh|npx|pip install" <package dir>`, and list what is not documentation with `fd -t f -E '*.md' . <package dir>`. Any row present on the right and absent on the left is the finding, and it needs no execution — do not run the package to find out what it does. Run the `AI-20` sweep over the manifest and the instruction files as well: this is exactly the file class the Rules File Backdoor targets.

**Traceability**: `LLM04:2026` · `ASI04` · `ASI02` · `AST01` · `AST03` · `AST07` · `AML.T0010.005` · `AML.T0011.002` · `AML.T0110.001` · `CWE-829` · `CWE-250`
**Tooling**: `fd -H 'SKILL\.md|plugin\.json|manifest\.json' <target>` for the inventory, then `rg` per package directory for the observed column. A package with no executable file can still be a finding through its text alone, and a clean grep says nothing about the next version of a package pinned to nothing. This procedure applies to the tooling you are running too: a squad that never audits the skill directory it ships has not applied `AI-22`.

### AI-28 Agent execution boundary: writable scope, self-modification and inherited credentials

**Where to look**
- The filesystem and shell tools and the scope declared for them: `Read`, `Write`, `Edit`, `Bash`, `run_command`, `python_repl`, `shell`, MCP filesystem servers and the directories mounted into them — the root path, the allow or deny list, and whether the path is canonicalized before it is checked
- Whether that scope reaches the files that steer the agent: `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/**`, `skills/*/SKILL.md`, the subagent definitions, `.mcp.json`, the memory store, the tool registry, and the records of `AI-27`
- The process environment: `~/.aws/credentials`, `~/.ssh`, `~/.kube/config`, `~/.netrc`, `~/.docker/config.json`, `gh` tokens, browser profiles, `.env`; the container or sandbox declaration; and any flag that disables confirmation globally

**Vulnerable pattern**
Two failures with one root cause — nobody drew the boundary.
1. The agent can write the files that govern it. One successful injection then stops being a session problem and becomes persistence: rules rewritten, a tool definition altered, memory seeded, and every later session — including other people's, if the artifact is distributed — starts compromised.
2. The agent inherits the ambient credentials of whoever launched it. The blast radius is not "the repository", it is every account, cluster and registry that machine can reach. The model never needs to exfiltrate a key when it can run the CLI that already holds one.

Read the tool declaration, not the role description. An agent documented as read-only that declares a general shell tool is not read-only: a shell writes files and reaches the network, so the prose states intent while the declaration sets the actual boundary.

**What rules it out (false positive)**
- The write scope is an explicit allowlist enforced inside the tool — not requested in the prompt — and it excludes instruction, configuration, memory and audit paths.
- The agent runs as its own principal in a container carrying only short-lived credentials scoped to its task, with no host mount of the developer's home directory.
- Every side-effecting command passes the `AI-07` gate showing the literal argument, with no global bypass flag set in the environment.
- The agent holds no shell and no write tool, and no MCP server hands it one indirectly (check the servers, not only the framework's tool list).

Rules: FP-01, FP-03, FP-06.

**Minimal test**
Two lists and one intersection; no exploitation needed. List A: the paths the agent can write, taken from the tool declaration and the sandbox mounts. List B: the steering, memory and audit paths above, plus the credential files present in the runtime — `ls -d ~/.aws ~/.ssh ~/.kube ~/.docker ~/.netrc 2>/dev/null` on the machine being audited, with its owner's permission. A non-empty intersection is the finding. `env | rg -i "token|key|secret|password" | sed 's/=.*/=<redacted>/'` inventories what the process inherits without printing a single value.

**Traceability**: `LLM03:2026` · `ASI03` · `ASI06` · `AML.T0081` · `AML.T0083` · `AML.T0112.000` · `AML.M0026` · `CWE-732` · `CWE-269` · `CWE-250`
**Tooling**: `rg -n "allowed[_-]?tools|allowedDirectories|dangerously|skip.?permissions|auto.?approve"` plus a read of the sandbox declaration. The absence of any sandbox declaration is the common case and is itself the finding. A container proves the process is isolated, not the credentials mounted into it, and a deny-list of paths proves intent, not enforcement, until you find the code that applies it.

## §12 Multi-agent topology and accountability

Two agents are not one agent twice. The handoff is a trust boundary, and once several actors share one effect the question stops being "was it authorized" and becomes "who can be shown to have caused it".

### AI-26 Inter-agent handoff without provenance or authentication

**Where to look**
- Orchestration: `crewai` (`Crew(`, `Task(`, `delegate`), `autogen` (`GroupChat`, `initiate_chat`), LangGraph (`Send(`, `Command(goto=`, subgraphs), `openai-agents` (`handoff(`), or the spawn call of a homegrown framework
- Transport: the HTTP route or queue where one agent posts work for another (`/agent`, `/task`, Redis, SQS, a Kafka topic) and whether it authenticates the caller
- The receiving side: where the other agent's output lands — user turn, system turn or a typed field — and which tools the receiver holds

**Vulnerable pattern**
Agent A's output is written into agent B's context as if it were an instruction, with no marker of where it came from and no record of what A had read first. If A ingested untrusted content the taint crosses the boundary silently, and B usually holds a different tool set — often the more dangerous one — so relaying the message is itself the escalation. The transport variant: the handoff endpoint accepts any caller, so work is injected straight into the swarm without ever passing through the user-facing agent. Text that instructs each agent to carry it into the next handoff needs nothing beyond these two gaps to keep propagating.

**What rules it out (false positive)**
- Every inter-agent message carries origin and trust level, and the receiver's tool set is filtered on it — `AI-06` applied across the boundary.
- The handoff is a typed structure with a closed schema, and the receiver never interpolates the sender's prose into instructions.
- Transport is authenticated with per-agent identities and no agent is reachable from outside the orchestrator.
- There is one agent. A single loop calling its own tools is `AI-01` and `AI-03`, not this procedure; a subagent that only returns a value the orchestrator parses is a typed edge, not a handoff.

Rules: FP-01, FP-06, FP-09.

**Minimal test**
Draw the graph — nodes are agents, edges are handoffs — and annotate each edge with what crosses (free text or typed), whether the origin is marked, and which tools the receiver holds. An edge carrying free text from an agent with untrusted ingestion into an agent with a write or outbound tool is the finding, proved by construction and without executing anything. For dynamic evidence, place the `AI-01` canary in the first agent's ingestion source and look for it in the last agent's tool arguments.

**Traceability**: `LLM01:2026` · `ASI07` · `ASI08` · `ASI10` · `AML.T0061` · `AML.T0080.001` · `CWE-346` · `CWE-306` · `CWE-501`
**Tooling**: `rg -n "Crew\(|GroupChat|initiate_chat|handoff\(|Command\(goto|Send\("` → the edges, not the trust model. A framework advertising "secure handoffs" is describing transport, not provenance: read where the text lands.

### AI-27 Agent actions that cannot be attributed: no trace, no retention, no reconstruction

**Where to look**
- The dispatcher and the tool wrapper: is there a record per tool call carrying subject, tool, arguments, outcome and a correlation id? `logging`, `structlog`, OpenTelemetry spans, `langfuse`, `langsmith`, `traceloop`
- What travels with it: the assembled prompt, the identifiers of the retrieved context, and the model and version that decided
- Where those records go, how long they are kept, whether the agent itself can write to them (`AI-28`), and whether they leave the perimeter
- The identity the action runs under: the end user's, or one service account shared by everybody

**Vulnerable pattern**
The agent takes actions with real effects — sends, writes, pays, deploys — and the only evidence afterwards is the provider's usage counter plus whatever the model narrated in the chat. Nobody can answer which input produced the action, which document was retrieved, which model version decided, or on whose behalf it ran. That is not a monitoring gap, it is non-repudiation: the effect is real and unattributable. When every user shares one service account, attribution has already collapsed at the identity layer before logging is even discussed. The mirror failure belongs here too — traces recording whole prompts with personal data, shipped to a third-party observability vendor under no agreement; hand that leg to `privacy-abuse` (`PRV-06`).

**What rules it out (false positive)**
- Every invocation with side effects emits a structured record with the authenticated subject, the turn's correlation id, the tool, redacted arguments and the outcome, retained beyond the discovery window, in storage the agent cannot write to.
- The agent holds no tool with side effects: a read-only assistant has nothing to attribute (verify that against the tool declaration, not the description — see `AI-28`).
- The effect lands in a system that keeps its own attributable trail and the agent's identity reaches it: the ticket, the commit or the payment record names the caller.

Rules: FP-01, FP-03, FP-08.

**Minimal test**
Take one irreversible action the agent can perform and trace backwards in code, from the effect to the record, asking a single question: six weeks from now, could I reconstruct who caused it and with what input, without relying on the model's own account of what it did? Every missing link is the finding. Then run the agent once locally against a fixture and read what it actually emitted, instead of what the logging configuration claims it emits.

**Traceability**: `LLM03:2026` · `ASI03` · `ASI10` · `AML.M0024` · `A09:2025` · `CWE-778` · `CWE-223` · `NIST 800-53 AU` · `ASVS 5.0 V16`
**Tooling**: `rg -n "logger\.|structlog|opentelemetry|langfuse|langsmith"` over the agent module → tracing that exists for debugging is not an audit trail; check subject, retention and tamper resistance before calling it one. Overlaps `infra-cloud` `INF-06` (platform logging): agree who writes it, so the finding is reported once, at the agent layer.

## §13 The inference endpoint

An agent's model provider is a dependency like any other, except that nothing in the repository pins it. The client library takes a base URL from configuration, and whoever sets that value sees every prompt, every retrieved document and every key that travels beside them — and answers with text the application already trusts.

There is a dynamic way to ask this question: send probes through the endpoint in use and look for inconsistencies between what it claims to be and how it behaves. That instrument exists, it is good, and it is not this one. It needs a working key, it spends the client's credits against a third party, and it can only run once traffic is already flowing. The procedure below asks the same question from the configuration alone: it costs nothing, needs no key, and runs before the first request is made.

### AI-30 The inference endpoint nobody pinned: what decides where the model traffic goes

**Where to look**
- The value itself: `OPENAI_BASE_URL`, `OPENAI_API_BASE`, `ANTHROPIC_BASE_URL`, `AZURE_OPENAI_ENDPOINT`, `base_url=`, `baseURL:`, `api_base`, `endpoint=`, `LITELLM_PROXY_URL`, `OLLAMA_HOST`, `HF_ENDPOINT`, `--api-base`, and the `api_base` field of a LiteLLM or LangChain model config
- Where the value comes from, which is the whole procedure: a committed `.env`, a Helm value, a ConfigMap, a CI variable, a code default that falls back to something that is not the provider — and, worst of all, a settings row or admin field that changes the endpoint with no deploy and no review
- What sits in between: LiteLLM, one-api, new-api, portkey, helicone, openrouter, an internal "AI gateway", or plain `HTTPS_PROXY`/`NO_PROXY` reaching the client library — and, for each, who operates it and under whose authority
- The transport on that client: `verify=False`, `httpx.Client(verify=…)`, `rejectUnauthorized: false`, `NODE_TLS_REJECT_UNAUTHORIZED=0`, a custom CA bundle mounted into the image
- What happens to the answer: whether tool-call arguments returned by the endpoint are re-validated before execution (`AI-03`), and whether the response is believed when it names its own model

**Vulnerable pattern**
Three findings, in the order they compound.
1. **The endpoint is externally controlled.** An environment variable, a ConfigMap or an admin field decides it, and the authority to change that value is not the authority to read every prompt the system sends. Nobody had to break in; the setting was always meant to be set.
2. **The relay is trusted to be who it says.** No host pinning, or verification switched off, so whatever sits on that path reads the traffic and rewrites it. A gateway is a legitimate architecture; an unverified one is a party with full read and write on the conversation.
3. **The answer is trusted as content.** The response can carry a rewritten tool command — an install pointed at a different index, a `curl … | sh`, an `eval` — and the application runs it because a model said so. The quieter variant injects instructions instead: a system prompt nobody in the project wrote, prepended by the relay, steering an agent whose operator never chose that text.

The third is `AI-03` with the trust boundary moved. The sink is unchanged; what changed is that the untrusted author is the transport rather than a retrieved document, which is why a review that cleared the retrieval path can still be reading a compromised answer.

**What rules it out (false positive)**
- The base URL is a constant in code with no environment override and no settings row, and the deployment sets no proxy variable that reaches the client (`FP-02`).
- The host is pinned to the provider with verification on, **and** a test fails when it changes. The test is the exculpation; the constant on its own only records today's intent (`FP-01`).
- The gateway is operated by the same trust principal as the application, under the same change control, and it already sees prompts that principal may read. The finding then moves to that gateway rather than disappearing: its own endpoint configuration is this procedure again, one hop along (`FP-05`).
- No response is trusted as an instruction: tool calls are re-validated against a closed schema and an allowlist before execution, and no returned text reaches a shell (`AI-03`).
- The control is an egress policy outside the repository — a network rule that permits only the provider's host. That is `FP-08`: without the exported rule the answer is `UNKNOWN`, not `HOLDS`.

Rules: FP-01, FP-02, FP-05, FP-08.

**Minimal test**
Two halves, both local, both inert, neither needing a key or a single token of budget.

*Resolve, do not call.* Load the configuration the way the application loads it and print the client's resolved base URL and whether certificate verification is on, for each environment that ships — printing a fingerprint of the key, never the key. An endpoint that moves when an environment variable moves, and no deploy pipeline that sets it, is finding 1, established without contacting anyone.

*Answer it yourself.* Point the client at a stub on loopback that returns a provider-shaped response containing a tool call, and watch whether the application executes it. That is finding 3, demonstrated against your own process. A `python3 -m http.server` sibling with a canned JSON body is enough; nothing leaves the machine.

The dynamic half — probing an endpoint already in use to see whether it substitutes the model, injects tokens or rewrites commands — spends the client's credits against a third party and is `REQUIRES AUTHORIZATION`. Ask for it with a cap, and do not run it to satisfy curiosity: the static half above decides whether it is worth asking.

**Traceability**: `LLM01:2026` · `LLM04:2026` · `LLM10:2026` · `ASI04` · `ASI05` · `CWE-15` · `CWE-346` · `CWE-345` · `CWE-295` · `CWE-494` · `CWE-829`
**Tooling**: `rg -n "base_url|baseURL|api_base|BASE_URL|OPENAI_API_BASE|OLLAMA_HOST|HF_ENDPOINT|LITELLM"` gives the call sites; `rg -n "verify\s*=\s*False|rejectUnauthorized|NODE_TLS_REJECT_UNAUTHORIZED"` gives the transport. Neither answers the question that matters, which is where the value comes from — grep finds the read, and you still have to walk back to the writer. A grep that returns nothing is worth reporting only after you have shown the same grep firing on a line you planted; otherwise the empty result is `NOT MEASURED`, not absence.

## Identifier note for this file

`AST0x` is the OWASP Agentic Skills Top 10, 2026 edition. Only the three cited above were verified against the project repository on 2026-08-16: `AST01` Malicious Skills, `AST03` Over-Privileged Skills, `AST07` Update Drift. The material is CC BY-SA 4.0, so identifiers and titles are cited as facts and none of its wording is reproduced. The `LLM0x:2026`, `ASIxx` and `AML.*` schemes, and the severity calibration, are documented once at the end of `ai-safety.md` and govern this file as well.
