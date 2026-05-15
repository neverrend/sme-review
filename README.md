# sme-review

A Claude Code skill that turns the **staff-engineer review** into something you can invoke mid-conversation. Run rigorous domain-expert critique on a design section *while you're still iterating* — before you commit to building it.

```
You:    "Here's my proposed auth design: [section pasted]. Get a web-app
         security SME review of it."

Claude: [Internally: dispatches a security expert subagent, then pushes
         back across multiple rounds until convergence]

         ### SME Review: User Authentication Service
         > Reviewed as security expert specializing in web-app.
         > Rounds: 2 of 4 — converged
         > Status: All findings resolved

         #### Findings
         **[Critical] SQL injection in /register and /login username lookup**
         - Reasoning: Unauthenticated attacker submits
           `username=' UNION SELECT 1, '<sha256 of known password>' --` ...
         - Recommendation: Parameterized queries; bandit B608 lint rule.
         - Status: validated.

         **[Critical] Unsalted SHA-256 password storage**
         - Reasoning: An RTX 4090 computes ~22 GH/s of SHA-256.
           The 8-char keyspace exhausts in ~127s; no salt means rainbow
           tables crack the entire user base in one pass. NIST SP 800-63B
           §5.1.1.2 requires an approved KDF with ≥32-bit salt.
         - Recommendation: argon2id (m=19MiB, t=2, p=1) per OWASP Password
           Storage Cheat Sheet. Per-user CSPRNG salt.
         - Status: validated.

         [...13 more findings, then a fully revised section]
```

## What it does

Replaces a manual workflow: presenting a design section to Claude, then asking *"now act as a senior security engineer and tear this apart, validating every assumption with concrete evidence — and then I'll push back on you, and we'll iterate until we settle on a stronger design."* The skill bakes that into one invocation.

Output for every review:

- **Validated assumptions** with `verified by:` evidence in one of 5 shapes (file path, executable check, calculation, threat scenario, citation). Hand-waves like "based on experience" trigger pushback.
- **Findings** at Critical / High / Medium / Minor severity, each with concrete reasoning, recommendation, and lifecycle status (`validated` / `refined`).
- **Disputed findings** surfaced separately when the loop genuinely deadlocks — both positions for you to adjudicate.
- **Considered and resolved** tail showing what the loop pushed back on and resolved.
- **Revised section** ready to drop in.

## Install

```sh
git clone https://github.com/neverrend/sme-review.git
cd sme-review
./install.sh
```

Modes:

- `./install.sh` — **copy** mode (default, recommended). iCloud-safe.
- `./install.sh symlink` — symlink mode. Catalog edits take effect immediately. For active development.
- `./install.sh --force` — overwrite an existing install.

Verify: `ls -la ~/.claude/skills/sme-review`.

Requires Claude Code's personal-skills directory (`~/.claude/skills/`) to be picked up by the loader. The script auto-creates it.

## Usage

After a design section is presented in conversation, invoke naturally:

- *"Get a backend expert review of this."*
- *"Do a network security SME review."*
- *"Get a Postgres-perf backend expert on this section."*
- *"Review this for distributed-systems concerns."*
- *"Get a SOC analyst review."* — falls through to the freeform path with recognition gate.

The skill auto-triggers when your prompt asks for a domain-expert critique of **pre-implementation** design content. It declines for:
- Code review of committed work → use `requesting-code-review` instead.
- Brainstorming a design from scratch → use `brainstorming`.
- Open-ended questions without an articulated section → it'll prompt you to articulate first.

## Curated experts (12)

Each is a complete subagent specification — a domain lens, failure-mode catalog, rubric, and reasoning standard.

| Expert | What they reason about |
|---|---|
| `backend` | Request paths, persistence, processing logic, contention/amplification |
| `api-design` | Contracts, versioning, idempotency, breaking-change surface |
| `frontend` | Rendering, state, accessibility, slow-network behavior |
| `prompting` | Prompt design, eval design, system-prompt architecture |
| `agent-systems` | Tool-use loops, memory, multi-agent orchestration |
| `security` | Adversarial review, trust boundaries, attack scenarios |
| `data-modeling` | Schemas, query patterns, indexing, migration cost |
| `infrastructure` | Deploy topology, networking, k8s/serverless/bare-metal |
| `distributed-systems` | Consistency, ordering, partitions, scale failure modes |
| `reliability` | SLOs, blast radius, graceful degradation, recovery |
| `performance` | Capacity math, latency budgets, hot-path analysis |
| `testing` | Testability, seams, observability hooks, fakeable boundaries |

Plus a **freeform fallback** for specialties not in the catalog (e.g., "SOC analyst", "compiler design"). The fallback applies a `{SPECIALTY}` substitution and a recognition gate that refuses unrecognized expertise rather than confabulating.

## Specialties (sub-domain lenses)

Each curated expert has 5–8 specialties. Examples:

- **security**: `network`, `web-app`, `mobile`, `supply-chain`, `identity-and-access`, `cryptography`, `secrets-management`
- **backend**: `request-path`, `postgres-perf`, `kafka-streaming`, `batch-etl`, `idempotency-and-retries`, `caching-tiers`, `background-jobs`
- **infrastructure**: `k8s`, `serverless`, `bare-metal`, `networking`, `edge-cdn`, `iac-and-config`, `multi-region`

Specifying a specialty narrows the lens. *"Network security review"* and *"web-app security review"* are different reviews — different rubric, different failure-mode catalog, different evidence shapes.

## How it works

When you invoke the skill, it:

1. **Extracts** the design section from recent conversation. Emits a one-line preview before proceeding (so you can correct mis-extraction).
2. **Parses** `(domain, specialty)` from your invocation.
3. **Resolves state path** at `~/.claude/sme-reviews/<section-slug>/<domain>/<specialty-slug>.md`. Last-write-wins; no lockfile.
4. **Cache check.** If a prior review for `(section, domain, specialty)` exists and the section content hash matches, returns the cached result with a `force re-review` discoverability prompt.
5. **Loads the persona** — `experts/<domain>.md` for curated, `experts/_freeform-template.md` with `{SPECIALTY}` substitution for freeform.
6. **Runs the debate loop** — soft cap 4 rounds, hard ceiling 6. Each round: dispatch expert subagent → main agent applies the 5-item pushback rubric → expert responds → check convergence. State written at end of every round.
7. **Synthesizes the output** per the format above.

The loop's design is in [`operations.md`](operations.md). The output template is in [`output-template.md`](output-template.md).

## Customization

**Adding a new persona.** Drop `experts/<slug>.md` following the format in any existing persona file. Identity (≤3 sentences, no personality), 5–8 specialties, rubric, "what rigorous reasoning looks like" mapped to the 5 evidence shapes, and explicit out-of-scope items. Then add the slug to the catalog list in `operations.md` and the index in `experts/README.md`.

**Adding a specialty to an existing persona.** Append a `### <specialty-slug>` block to the `## Specialties` section with a one-sentence Lens and 3–5 "Especially watches for" bullets.

**Adjusting the round cap.** Default soft cap 4, hard ceiling 6. To revisit, see `CONTRIBUTING.md` → "Cap tuning."

## Cost per invocation

A typical run is 4 rounds × (expert subagent dispatch + main-agent pushback) plus the round-1 setup and final synthesis. Pre-telemetry estimate: roughly **$0.50–$3 per invocation** depending on section length and the model used. A long, contested section that hits the soft cap on Opus can land at the upper end; a short section that converges in 1–2 rounds on a smaller model is well under a dollar.

Real numbers will land after Batch 1 of the telemetry run (`docs/sme-review-telemetry/`) and this estimate will be updated. Until then: invoke deliberately, not reflexively. If you're running this 5+ times in a planning session, you're paying real money.

## Scope (v1)

- **One section per invocation.** For multi-section reviews, invoke once per section. The orchestrator suggests follow-up specialties for cross-cutting concerns (e.g., a security review of an architecture proposal might suggest a follow-up `infrastructure` or `data-modeling` review).
- **Single-user concurrency.** State writes are last-write-wins. Firing the same `(section, domain, specialty)` triple twice in parallel may clobber; cross-invocation continuity across *different* `(domain, specialty)` pairs on the same section still works via the continuation reader.
- **Pre-implementation design only.** For code review of committed work, use `requesting-code-review`.
- **Personal install.** v0.1 deploys to `~/.claude/skills/sme-review/` via `install.sh`. Plugin packaging (one-click marketplace install) is on the roadmap.

See `KNOWN-ISSUES.md` for the v0.1 test-harness gaps (deferred to v0.2).

## Files

| Path | Purpose |
|---|---|
| `SKILL.md` | Skill frontmatter and 7-step Procedure (point-at-files; ≤400 words) |
| `operations.md` | Orchestration mechanics: state paths, hashing, concurrency, extraction, parsing, debate loop, pushback rubric, convergence test, failure handling, continuation reader, cross-cutting catalog |
| `output-template.md` | Synthesis format, status semantics, evidence shapes, truncation, special-case templates, frontmatter schema, compaction tiers, hand-off variants |
| `experts/<domain>.md` | 13 curated personas |
| `experts/_freeform-template.md` | Freeform fallback with `{SPECIALTY}` substitution |
| `experts/README.md` | Catalog index |
| `install.sh` | Deployment script (copy/symlink, --force, iCloud guard, writability probe) |
| `tests/claude-code/` | Deterministic bash + `claude -p` + grep tests |
| `tests/scenarios/` | Manual QA scenarios (loop behavior, convergence pathologies, state persistence, extraction, edge cases) |
| `tests/test-sections/` | Input fixtures (well-formed, flawed-with-known-issues, ambiguous, tangled) |
| `tests/runbook.md` | How to run deterministic tests and walk manual scenarios |
| `CONTRIBUTING.md` | Persona / specialty authoring guide and cap-tuning notes |
| `KNOWN-ISSUES.md` | v0.1 test-harness gaps deferred to v0.2 |
| `LICENSE` | MIT |

## Uninstall

```sh
rm -rf ~/.claude/skills/sme-review
```

## License

MIT — see [LICENSE](LICENSE).
