# Knowledge pack - ai-safety

> **When to load this file:** when the inventory contains calls to a language model, an agent with tools, an MCP client or server, a RAG pipeline, persistent memory, or a chatbot exposed to users.
> **Do not load it if:** the project only uses a model for offline classification, with no tools, no retrieval and no output reaching an executable sink; the web/API coverage is enough there.
> **Cost:** ~285 lines. Load by section using the index; §0 is mandatory whenever an agent with tools exists.
> **This pack ships in three files, and this one is the entry point.** `ai-safety-data-output.md` holds §4-§10 and `AI-12`..`AI-22` plus `AI-24` — RAG, the vector store deployment, memory poisoning, model output reaching an executable sink, context and secret leakage, unbounded consumption, payload obfuscation, adversarial evaluation, and the squad's own self-protection. `ai-safety-agent-runtime.md` holds §11-§12 and `AI-25`..`AI-28` — installable skills and plugins, the agent's writable scope and inherited credentials, inter-agent handoff, and attribution of what the agent did. `AI-22` applies to every engagement without exception; the identifier compatibility notes at the end of this file govern all three.

## Selective loading index

| Section | Load it if the inventory has | Procedures |
|---|---|---|
| §0 Lethal trifecta | any agent with two or more tools | AI-01 |
| §1 Instruction/data boundary | prompts built from external content (web, email, files, tickets, RAG) | AI-02, AI-03, AI-04 |
| §2 Tool authorization | the model decides which function runs | AI-05, AI-06, AI-07 |
| §3 MCP and tool chain | `.mcp.json`, `mcp_servers`, MCP SDK, first- or third-party servers | AI-08, AI-09, AI-10, AI-11 |

Sections §4 to §10 (`AI-12`..`AI-22`, `AI-24`) are in `ai-safety-data-output.md`. Sections §11 and §12 (`AI-25`..`AI-28`) are in `ai-safety-agent-runtime.md`: load it when the target installs or ships agent packages, hands an agent a shell or write tool, or runs more than one agent.

## How to use a procedure

Locate the pattern with **Where to look**, using the globs of the real stack rather than the ones in the example. Confirm it against **Vulnerable pattern** and clear it with the false-positive list before writing anything down. Run **Minimal test** only if it is local, inert and imposes no cost on someone else; if it needs a live endpoint, mark it `REQUIRES AUTHORIZATION` and do not run it. Report using the identifiers in **Traceability**, and describe what the tool proves, never what it suggests.

## §0 The master check: the lethal trifecta

### AI-01 Per-agent capability inventory and trifecta detection

The dangerous combination, formulated by Simon Willison on 2025-06-16, is a single agent holding (1) access to private data, (2) exposure to untrusted content and (3) an outbound communication channel. With two of the three the attacker is a nuisance; with all three they read and exfiltrate without exploiting any flaw, just by writing text the agent obeys. This procedure comes first and orders all the others.

**Where to look**
- LangChain/LangGraph: `**/*agent*.py`, `**/*graph*.py` → `Tool(`, `@tool`, `bind_tools(`, `ToolNode(`, `create_react_agent(`; direct Anthropic/OpenAI SDK: the `tools=[...]` array and the `tool_use`/`tool_calls` dispatcher
- MCP: `.mcp.json`, `claude_desktop_config.json` → `server.tool(`, `@mcp.tool()`, `list_tools`; other frameworks: `crewai`, `autogen`, `llama_index`, `pydantic_ai`, `openai-agents`

**Vulnerable pattern**
One table per agent, one row per tool. Three marks on the same agent, even if they come from different tools, is the finding:

| Agent | Tool | (1) private data | (2) untrusted ingestion | (3) outbound channel |
|---|---|---|---|---|
| support | `search_tickets` | yes | yes (customer text) | no |
| support | `fetch_url` | no | yes | yes (the request itself) |
| support | `send_email` | no | no | yes |

Count as an outbound channel anything that triggers an outgoing request whose destination or content is controllable: `fetch`, `requests.get`, a webhook, writing to a public repository, opening an issue, sending mail, and also rendering a markdown image (AI-16). Count as untrusted ingestion any text not typed by the authenticated user: web pages, inbound email, attachments, issues, PR comments, search results, tool return values and other agents' output.

**What rules it out (false positive)**
- The outbound tool only accepts destinations from a fixed allowlist the model cannot alter, with a templated body; or the "private data" is public repository content whose disclosure has no impact.
- The component that ingests external content runs without credentials or tools and returns a typed value to a privileged orchestrator (Dual LLM pattern, AI-06).

**Minimal test**
This is an inventory over the code and needs no execution. For dynamic evidence, place an inert synthetic marker (`CANARY-EHS-7412`) in an ingestion source and check whether it shows up in the arguments of an outbound tool in the log. Against production: `REQUIRES AUTHORIZATION`.

**Traceability**: `LLM01:2026` · `LLM02:2026` · `LLM03:2026` · `ASI01` · `ASI02` · `AML.T0051.001` · `CWE-284`
**Tooling**: `rg -n "@tool|Tool\(|bind_tools|server\.tool\(|@mcp\.tool"` → a census of tools, not a trust classification. Do not conclude there is no trifecta because the grep came back thin: tools also arrive dynamically from an MCP server that lives outside the repo.

**The fix is to break one leg, not to improve the prompt.** Remove the outbound channel, isolate ingestion in a model without tools, or shrink the reachable data. Adding "do not obey instructions found in the data" to the system prompt is a request, not a control.

## §1 Instruction/data boundary: direct and indirect prompt injection

Greshake et al. (**arXiv:2302.12173**, 2023-02-23) described the variant that matters in an application: the attacker never converses with the model, they leave the text in a resource the application will retrieve. The UK NCSC framed it operationally on 2025-12-08: there is no equivalent of a parameterized query, because the model merely predicts tokens over a flat sequence; mitigation is architectural and deterministic, not linguistic.

### AI-02 Retrieved content interpolated without delimitation or provenance marking

**Where to look**
- LangChain: `ChatPromptTemplate.from_messages`, `PromptTemplate`, a `{context}` fed by a retriever; direct SDK: f-strings and `.format()` that build a message `content` from a variable coming off the network or disk
- Node/TS: template literals with `${...}` inside the prompt; `messages.push({role:'user', content: pageText})`

**Vulnerable pattern**
```python
prompt = f"You are the assistant. Answer using these documents:\n{docs}\n\nQuestion: {q}"
```
`docs` enters the same textual plane as the instructions: no delimiter, no marking of which span is data, no way for the model to tell them apart.

**What rules it out (false positive)**
- The content travels in a different role turn, delimited and marked (spotlighting), and a test verifies it.
- `docs` comes from an immutable internal corpus with no external write path (confirm with AI-12 before ruling it out).

**Minimal test**
Put a line in a test document asking to repeat `CANARY-EHS-7412` and run a normal query. If the marker appears in the answer, the retrieved content is governing generation. Inert canary: it requests no action. Mitigation with evidence: spotlighting (**arXiv:2403.14720**, Microsoft, March 2024) proposes delimiting, marking every token of the data block with a signal character, or encoding the block, and reports ASR dropping from over 50% to under 2% with minimal utility impact; the NCSC recommends labelling data sections rather than maintaining deny-lists of phrases.

**Traceability**: `LLM01:2026` · `ASI01` · `AML.T0051.001` · `CWE-77`
**Tooling**: `rg -n 'f"[^"]*\{(context|docs|content|page|body|text)\}' -tpy` → finds interpolations. A hit does not prove exploitability: you still have to show a third party writes that variable.

### AI-03 Indirect ingestion channels with no inventory

**Where to look**
- Browsing and reading: `fetch_url`, `browse`, `WebBaseLoader`, `PyPDFLoader`, `UnstructuredLoader`, `playwright`
- Integrations: email (`imaplib`, Gmail API), Slack, Jira, GitHub (issues, PR comments), calendar, CRM; and the JSON from a third-party API that returns into context as text

**Vulnerable pattern**
Any tool whose return value is concatenated into history without an origin label. The classic case is an agent summarizing the inbox: the attacker sends an email, never talks to the model, and their text enters with the same standing as the user's instruction.

**What rules it out (false positive)**
- The content passes through a deterministic extractor that returns typed fields (date, amount, sender) and never free text.
- The source has a single trusted writer and is authenticated end to end.

**Minimal test**
A table of source → who can write to it → does it reach the context yes/no. The absence of that table in the project documentation is already a design finding.

**Traceability**: `LLM01:2026` · `ASI06` · `AML.T0051.001` · `CWE-20`
**Tooling**: targeted manual review. No scanner knows your product's trust model.

### AI-04 Versioned instruction files the agent reads on its own

Maloyan and Namiot (**arXiv:2601.17548**, 2026-01-24) systematize attacks against agentic coding assistants across 42 techniques and a meta-analysis of 78 studies from 2021 to 2026: with adaptive strategies the success rate exceeds 85% and most defenses mitigate less than 50%. The distinctive vector is that the payload travels in files of the repository itself that the assistant loads without anyone asking. Pillar Security documented on 2025-03-18 the Rules File Backdoor variant with invisible characters in rules files, which survives a fork.

**Where to look**
- `.mcp.json`, `.cursor/rules/**`, `CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`, `skills/*/SKILL.md`, `.windsurfrules`, `.clinerules`, `.continue/**`
- Any file the tooling loads automatically when the repository is opened

**Vulnerable pattern**
An instruction file arriving through an external PR, merged with the light review documentation gets, from which it steers the behavior of the whole team's assistant. It is worse if it contains non-printable characters (AI-20).

**What rules it out (false positive)**
- They are in `CODEOWNERS` with mandatory security review and the repository does not accept external PRs.
- The assistant is configured not to load them automatically.

**Minimal test**
`git log --follow -- CLAUDE.md AGENTS.md .cursor/rules .mcp.json` to see authorship and review, plus the binary sweep from AI-20 over each one.

**Traceability**: `LLM01:2026` · `LLM04:2026` · `ASI04` · `ASI06` · `AML.T0051.001` · `CWE-829`
**Tooling**: `git log --format='%h %an %s' -- CLAUDE.md AGENTS.md .mcp.json` → history. An external author is not a finding in itself; the finding is the absence of security-minded review over a file that steers an agent with tools.

## §2 Tool authorization

### AI-05 Authorization decided by the model's text

**Where to look**
- The dispatcher: where `tool_use`/`tool_calls` is received and executed; LangChain: `AgentExecutor`, `ToolNode`, `handle_tool_call`; MCP: the body of each `server.tool(...)`

**Vulnerable pattern**
```python
def dispatch(call, user):
    fn = REGISTRY[call.name]
    return fn(**call.args)          # no role, no object, no limit
```
The permission check lives in the system prompt ("only query the current user's data") instead of in code, and identity never travels down to the sensitive operation.

**What rules it out (false positive)**
- Each tool receives an identity context the model cannot control and authorizes against the concrete object.
- The destination backend already authorizes per object using the end user's token and the model cannot impersonate the subject.

**Minimal test**
Unit test on the dispatcher: a well-formed call to a sensitive tool with the context of a user lacking permission. It must fail in authorization, not in argument validation.

**Traceability**: `LLM03:2026` · `ASI02` · `ASI03` · `A01:2025` · `CWE-862` · `CWE-863` · `ASVS 5.0 V8`
**Tooling**: manual review of the dispatcher; a scanner cannot tell a real authorization from a cosmetic one.

### AI-06 No privilege degradation after ingesting external content

The NCSC's operating principle (2025-12-08): when a model processes information from a party, its privileges must drop to that party's level. In code that is a taint mark on the agent's state. **Its absence is the finding.**

**Where to look**
- Agent state (`AgentState`, `GraphState`, `session`, `context`) → `trust_level`, `tainted`, `untrusted_seen`, `provenance`
- The point where the available tools for this turn are decided

**Vulnerable pattern**
The tool list is constant for the whole session: after reading an arbitrary web page the agent keeps exactly the same permissions it had when it received the user's instruction.

**What rules it out (false positive)**
- The mark exists and write or outbound tools are filtered out when it is set.
- A structural pattern makes it unnecessary: the Dual LLM pattern (Willison, 2023-04-25), where a privileged model with tools never sees untrusted tokens and a quarantined model, without tools, processes them and returns symbolic references; or CaMeL (**arXiv:2503.18813**, v2 2025-06-24), which extracts control and data flow from the trusted query and enforces capabilities and policy at the call site, solving 77% of AgentDojo tasks with provable security against 84% with no defense at all. The catalogue in **arXiv:2506.08837** (2025-06-10) adds Action-Selector, Plan-Then-Execute, LLM Map-Reduce, Code-Then-Execute and Context-Minimization; its declared anti-pattern is re-planning while reading every untrusted result.

**Minimal test**
Trace the path from the return of an external-read tool to the next tool decision. If there is no branch that depends on the content's origin, there is no degradation.

**Traceability**: `LLM01:2026` · `LLM03:2026` · `ASI01` · `ASI03` · `CWE-269`
**Tooling**: `rg -n "trust_level|tainted|untrusted|provenance|is_external"` → if it returns nothing in the agent module, write it up as a design finding with severity proportional to what the tools can do.

### AI-07 Human confirmation gate absent, cosmetic or fatigued

ASI09 Human-Agent Trust Exploitation covers this: a gate the user approves without reading is not a control.

**Where to look**
- `interrupt(`, `human_in_the_loop`, `require_approval`, `confirm=True`, approval queues
- The approval UI: does it show the real arguments or a summary written by the model itself?

**Vulnerable pattern**
The text shown to the human is written by the model, so a compromised agent describes the action as benign and executes another one. Variants: the gate covers only one of the dangerous tools, or it is switched off by a global flag in production.

**What rules it out (false positive)**
- The confirmation shows the literal arguments, safely rendered, and their hash is validated at execution time.
- Every tool with an irreversible effect is on the approval list, with no configuration-based exceptions.

**Minimal test**
Compare two sets: tools with side effects and tools behind a gate. The difference is the finding.

**Traceability**: `LLM03:2026` · `ASI09` · `CWE-807`
**Tooling**: manual comparison of both lists; no scanner does it.

## §3 MCP and tool supply chain

Exposure: Wiz (State of AI in the Cloud 2026) reports MCP servers present in 80% of environments, 90% of organizations running self-hosted models, 68% of those ingesting them through third-party software, and 57% deploying self-hosted agents. The census in **arXiv:2510.16558** (accepted at DSN 2026) covers more than 67,000 servers across 6 registries: 833 vulnerable and 18 with suspicious descriptions.

### AI-08 Tool poisoning, rug pull and cross-server shadowing

Invariant Labs described the three primitives in April 2025: instructions hidden in a tool's `description` field, visible to the model and not to the user; changing the description after the user approved the server; and a tool from one server redefining the behavior of another server's tool. MCPTox (**arXiv:2508.14925**, 2025-08-19) measured it across 45 real servers, 353 authentic tools, 1,312 cases and 20 agents: o1-mini fell 72.8% of the time and Claude-3.7-Sonnet refused less than 3% of the time. The counterintuitive finding you should cite: **the more capable models are more susceptible because they follow instructions better**; alignment is not the defense. "Parasites in the Toolchain" (**arXiv:2509.06572**) censused 12,230 tools across 1,360 servers and describes a three-phase chain requiring no victim interaction.

**Where to look**
- The descriptions as the client actually receives them, not as they appear in the server's README
- `.mcp.json` and equivalents (which servers are enabled and with what scope); if the project publishes an MCP server, its own `description` fields and docstrings

**Vulnerable pattern**
A description that, besides explaining what the tool does, includes instructions aimed at the model (read a file before calling, pass a certain value into another parameter, do not mention anything to the user). Another signal: descriptions disproportionately long for a trivial function.

**What rules it out (false positive)**
- Descriptions come from a hash-pinned manifest and any change breaks startup.
- The server is first-party, lives in the repository, and its descriptions are reviewed as code.

**Minimal test**
Dump the descriptions the client actually receives and review them by hand, applying the AI-20 sweep as well. Storing a hash per tool and comparing it at every startup turns a rug pull into a detectable failure.

**Traceability**: `LLM01:2026` · `LLM04:2026` · `ASI02` · `ASI04` · `ASI07` · `AML.T0051.001` · `CWE-829` (the ATLAS ID for publishing poisoned agent tools has an unresolved conflict between two entries → (ID not verified - omitted))
**Tooling**: the client's `list_tools` dump plus `rg` over it. Imperative text in a description is a signal, not proof: you must show it reaches the model's context.

### AI-09 MCP servers installed without version pinning or provenance checks

**Where to look**
- `.mcp.json`, `claude_desktop_config.json` → `command`, `args`; also `Dockerfile` and startup scripts

**Vulnerable pattern**
```json
{ "command": "npx", "args": ["-y", "some-mcp-server"] }
```
`-y` accepts installation without asking and without a pinned version: every startup can pull different code published by whoever controls that name. It is the direct path from a registry compromise to execution on the developer's machine, with every credential in the environment within reach.

**What rules it out (false positive)**
- An exact version pinned with lockfile integrity, or a container image referenced by digest.
- The server runs from a local path inside the repository itself.

**Minimal test**
Classify each server: pinned / unpinned, first-party / third-party, with network / without network, and which credentials sit in its environment. The combination unpinned + third-party + credentials is the finding.

**Traceability**: `LLM04:2026` · `ASI04` · `A03:2025` · `A08:2025` · `CWE-829` · `CWE-1104`
**Tooling**: `rg -n '"command"|npx|uvx' .mcp.json claude_desktop_config.json` → inventory. Do not confuse lack of pinning with compromise: it is supply chain risk, not an incident.

### AI-10 Token passthrough, unvalidated `aud` and confused deputy in OAuth

The Security Best Practices section of the MCP specification names: that an MCP server must not accept tokens that were not issued to it (validate the audience), the confused deputy in OAuth proxies with a static `client_id`, SSRF during OAuth metadata discovery, state handle hijacking, validating the authorization URL to block `javascript:` and `data:` schemes, escalation through a stdio proxy, and localhost redirect URI impersonation.

**Where to look**
- The MCP server: where `Authorization` is read → `jwt.decode(`, `verify(`, `introspect`
- OAuth configuration: `redirect_uri`, `client_id`, `state`, discovery metadata

**Vulnerable pattern**
```python
claims = jwt.decode(token, key, algorithms=["RS256"])   # no audience=
```
Without validating `aud`, a legitimate token issued for another service opens this one. Complementary: forwarding the user's token verbatim to the destination API, turning the server into an uncontrolled credential bridge.

**What rules it out (false positive)**
- `aud`, `iss` and expiry are validated, and the server exchanges the token for a narrowly scoped one of its own before calling downstream.
- Local stdio transport, with no network exposure and no proxy.

**Minimal test**
A test with a token signed by the same issuer but with another service's `aud`: it must be rejected. This is local, with a test key, not an attack.

**Traceability**: `ASI03` · `ASI07` · `A01:2025` · `A07:2025` · `CWE-863` · `CWE-918` · `ASVS 5.0 V9` · `ASVS 5.0 V10`
**Tooling**: `rg -n "jwt.decode|verify\(|audience|aud"` → finds the validation. The call existing does not prove it validates the audience; read the arguments.

### AI-11 Secrets in MCP configuration files

GitGuardian (2026) found 24,008 unique secrets in MCP configuration files, 2,117 of which were still valid. Orca (2025-2026) reports that 41.88% of organizations leak AI/ML credentials.

**Where to look**
- `.mcp.json`, `claude_desktop_config.json`, `.cursor/mcp.json` → the `env` block
- `.env*`, `docker-compose.yml`, example files with real values pasted in, and the git history of those same files

**Vulnerable pattern**
API keys inside `env` in a versioned file, or the file left out of `.gitignore`. It is worse when the token has broad scope (a full-repository PAT, a provider key with no spending limit).

**What rules it out (false positive)**
- The value is a substitution placeholder (`${VAR}`, `changeme`) or an example key with an invalid format.
- The file is ignored and was never versioned (confirm with `git log`, not with `git status`).

**Minimal test**
`git log -p -- .mcp.json | rg -n "sk-|ghp_|xoxb-|AKIA"`. Never print the full value: report prefix, length and location. If it looks active, escalate to the lead and do not verify it against the provider.

**Traceability**: `LLM02:2026` · `LLM04:2026` · `ASI03` · `A02:2025` · `CWE-798` · `CWE-312`
**Tooling**: `gitleaks detect` or `trufflehog filesystem .` → a hit requires confirming context and validity; a clean file does not prove there are no secrets elsewhere.

## Identifier compatibility and severity calibration

`LLM0x:2026` refers to the 2026 edition of the OWASP Top 10 for LLM Applications, published on 2026-08-03 by the OWASP GenAI Security Project, built from 75% community vote and 25% analysis of 7,714 real incidents (6,639 classified). The list is LLM01:2026 Prompt Injection, LLM02:2026 Sensitive Information Disclosure, LLM03:2026 Excessive Agency, LLM04:2026 Supply Chain, LLM05:2026 Data and Model Poisoning, LLM06:2026 Unbounded Consumption, LLM07:2026 Misinformation, LLM08:2026 Hidden Context Exposure, LLM09:2026 Vector and Embedding Weaknesses, LLM10:2026 Improper Output Handling. If the project documents its posture against the 2025 edition (2024-11-18), translate when reporting: Excessive Agency moved from LLM06 to `LLM03:2026`; Improper Output Handling from LLM05 to `LLM10:2026`; Unbounded Consumption from LLM10 to `LLM06:2026`; Misinformation from LLM09 to `LLM07:2026`; Supply Chain from LLM03 to `LLM04:2026`; Data and Model Poisoning from LLM04 to `LLM05:2026`; and System Prompt Leakage (LLM07 in 2025) was replaced by `LLM08:2026` Hidden Context Exposure, which is broader.

`ASIxx` refers to the OWASP Top 10 for Agentic Applications 2026 (announced 2025-12-09, version 2.01 of 2026-06-01): ASI01 Agent Goal Hijack, ASI02 Tool Misuse & Exploitation, ASI03 Identity & Privilege Abuse, ASI04 Agentic Supply Chain Vulnerabilities, ASI05 Unexpected Code Execution (RCE), ASI06 Memory & Context Poisoning, ASI07 Insecure Inter-Agent Communication, ASI08 Cascading Failures, ASI09 Human-Agent Trust Exploitation, ASI10 Rogue Agents. The earlier agentic threats and mitigations taxonomy uses a `T1..T15` scheme: cite it by document name, not by number (titles not verified). For the risk framework and generic countermeasures use NIST AI 100-2e2025 (2025-03-24), NIST AI 100-1 AI RMF 1.0 (2023-01-26, under revision per NIST) and NIST AI 600-1 Generative AI Profile (2024-07-26), all public domain in the United States.

Two data points for calibrating severity: HiddenLayer (2026) reports that 1 in 8 AI-related breaches already involves agentic systems and that 31% of organizations do not know whether they have suffered one. Checkmarx (2026) measures that frontier models produce functional code between 83% and 95% of the time, but only between 24% and 36% of it is both secure and functional, rising to just 47-56% after one review round: AI-generated code is reviewed as hard as human code, never less.
