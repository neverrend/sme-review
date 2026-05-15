# Operations

This file collects the orchestration mechanics referenced from `SKILL.md`. Each H2 section is a self-contained subsystem the orchestrator follows when running the skill.

## State path resolution

State files are written under `~/.claude/sme-reviews/<section-slug>/<domain>/<specialty-slug>.md`. Single fixed path; no project-local discovery, no fallback, no write probe.

Writes follow **last-write-wins** semantics. Concurrent invocations on the same `(section-slug, domain, specialty-slug)` may clobber each other — acceptable for the single-user scope of v0.1. Cross-invocation continuity across different `(domain, specialty)` pairs on the same section still works via the continuation reader (see below); collisions only occur when the user fires the *same* triple twice in parallel.

If the directory cannot be created or the write fails, surface to user: `State persistence unavailable at ~/.claude/sme-reviews. Continue without persistence (cross-invocation continuity disabled), or abort?` Wait for explicit user choice.

## Section content hashing

Compute `section-content-hash` (used for cache-hit detection) by:

1. Trim trailing whitespace per line.
2. Collapse runs of blank lines to a single blank line.
3. Strip trailing whitespace inside code-block fences.
4. Headings: keep case (semantic).
5. SHA-256 of the result.

Reproducible. Bytewise hash of the *normalized* form so editor-driven whitespace drift doesn't trigger spurious cache misses.

## Section extraction

The skill operates on a section the LLM most recently presented in conversation. The orchestrator extracts that section before dispatching the expert.

### Recent-context window

Scan back through assistant turns until either:
- (a) A clearly-formatted design section is found (H2/H3 heading or demarcated block), OR
- (b) A user message that resets context (topic change, unrelated question) is hit.

Cap at 5 assistant turns. Explicit pointer in user invocation ("review the auth section above") takes precedence over this heuristic.

### Always-emit preview

Before proceeding with any review, emit a one-line preview:

> _Reviewing: "<first 80 chars of extracted section>..."_

User acknowledges with continuation, redirects with a quoted excerpt or pointer.

### Ambiguous case

If multiple candidate sections exist in window, OR the section was inline-revised, OR it spans multiple turns — single confirmation:

> _Reviewing this as the target section: "<first 80 chars>...". Confirm or point at a different one._

No multiple-choice menu. Confirms-by-default on positive acknowledgment.

### No section in recent context

If no design section is found within the window:

> _No design section to review in recent context. Articulate the design as a section first, or rephrase the question as a design proposal I can extract._

No silent fallback to reviewing the question itself.

### Section slug

The `section-slug` (used in state paths) is derived from the extracted section's heading text:
- Take the heading text (or first ~80 chars if no heading).
- Lowercase, replace whitespace and non-`[a-z0-9-]` with single hyphen.
- Trim leading/trailing hyphens.
- Cap at 60 chars.

Same slug across invocations on the same section enables cross-invocation continuation.

## Specialty parsing & recognition

The orchestrator parses the user's invocation into `(domain, specialty)`.

### Curated catalog

The 13 curated domains (one persona file each, at `experts/<slug>.md`):
`backend`, `api-design`, `frontend`, `prompting`, `agent-systems`, `security`, `data-modeling`, `infrastructure`, `distributed-systems`, `reliability`, `performance`, `testing`, `skill-design`.

### Parsing rules

- **Both named** ("network security expert") → `(security, network)`.
- **Domain only** ("security review") → `(security, null)` — load general persona.
- **Specialty only** ("review for SQL injection") → if specialty exactly matches one curated specialty slug across exactly one curated domain, use that pair. Otherwise → freeform path with the specialty as lens.
- **Multiple specialties named** → single confirmation: `Detected multiple specialty candidates: '<first>' and '<second>'. Run '<first>' first and offer '<second>' after, or pick one?`
- **Neither named** ("review this") → ask once: `Which expert should I bring? (e.g., 'backend', 'security network', 'frontend'…)`

### Specialty sanitizer

Before any state-path or substitution use, sanitize the specialty string:

1. Lowercase.
2. Replace whitespace and non-`[a-z0-9-]` with single hyphen.
3. Strip `/`, `..`, leading dots, backticks, newlines, template-breaking chars.
4. Collapse runs of hyphens.
5. Trim leading/trailing hyphens.
6. Cap at 40 chars.
7. Reject (with helpful error) if sanitization removes >20% of original string.

### Recognition check

Before dispatching the expert with a freeform-path persona (uncurated specialty), the main agent answers a single yes/no:

> *Is `<specialty>` a recognized professional/technical specialty or a plausible composition of recognized terms?*

- **No** → refuse: `I couldn't interpret '<specialty>' as a recognized expertise. Try a curated specialty or rephrase.`
- **Yes** → proceed.

Plus: the freeform dispatch prompt instructs the subagent: `If you do not have substantive expertise in {SPECIALTY} as a real field, your FIRST response must be exactly the token UNKNOWN_SPECIALTY and nothing else.` The orchestrator checks for that token before running the rest of the loop.

## Debate loop

The skill runs an internal expert ↔ main-agent pushback loop.

### Caps

- **Soft cap: 4** rounds (baseline; can be adjusted by debug-log observation).
- **Hard ceiling: 6** rounds (absolute terminate).

### Per-round flow

```text
Round N:
  1. Orchestrator dispatches expert subagent with:
     - Universal rules block (see below)
     - Persona body (curated/specialty/freeform — loaded from experts/<domain>.md or _freeform-template.md)
     - Section to review (verbatim — paste, don't reference)
     - Prior-review context (compacted summaries from earlier invocations on this section)
     - Pushback context (rounds 2+: main agent's challenges from N-1, verbatim)
     - Output contract pointer (output-template.md)
  2. Subagent returns structured response.
  3. Main agent reads response, applies pushback rubric (see Pushback rubric below).
  4. Convergence check (see Convergence test). If converged → write final state → exit.
  5. If N > soft cap (4) and not converged → heightened-scrutiny mode for next round (next pushback must be the strongest available).
  6. If N >= hard ceiling (6) → terminate, mark "unresolved disagreement," write state.
  7. Else N++; goto 1.
```

State file written **at end of every round**, not end of loop. `convergence-status` defaults to `incomplete`; flips on the final write.

A **transcripts sidecar** is written alongside the state file at end of every round (see Transcripts sidecar below). The state file holds the synthesized output; the sidecar holds verbatim per-round expert response and main-agent pushback so the user can audit whether the debate was substantive.

### Round-2+ dispatch construction

When constructing the dispatch prompt for round N≥2, the prior round's outputs MUST be embedded verbatim, not summarized:

- **Round N-1 expert response:** paste in full, no compression. Includes the full Validated assumptions block (each assumption verbatim, including its `verified by:` clause) and the full Findings block (Issue / Reasoning / Recommendation per finding, verbatim).
- **Round N-1 pushback:** paste in full, no compression.

Abbreviated or summarized prior-round content in the dispatch prompt causes false-`kept` labels in the subagent's output (the subagent quotes back the orchestrator's summary, not the true prior text — discovered in Batch 1 R04 telemetry where R2 VAs were labeled `kept` against a compressed R2-dispatch summary, not the verbatim R1 text). The verbatim requirement applies only to the immediately-preceding round (N-1); rounds N-2 and earlier remain 5-bullet compactions per "Retention between rounds" below.

#### Pre-dispatch checklist (orchestrator, R2+ rounds)

Before invoking the subagent for any round N≥2, the orchestrator MUST output a verifiable checklist as plain text in the conversation:

```
R<N> dispatch checklist:
[ ] R<N-1> expert response embedded verbatim (Validated assumptions: full text per entry; Findings: full Issue/Reasoning/Recommendation per finding)
[ ] R<N-1> pushback embedded verbatim
[ ] No "[see prior]", "[full text preserved]", or summary placeholders in the dispatch prompt
[ ] R<N-1> finding titles enumerated for cross-check by the expert: <comma-separated list>
[ ] Withdrawn-block requirement included in R2+ output contract (any R<N-1> finding not in R<N> consolidated list must appear in Withdrawn with a one-sentence reason)
```

Each checkbox must be ticked (`[x]`) before the subagent invocation, with the dispatched-prompt text following. This is a structural enforcement mechanism, not an internalized norm — a checklist the orchestrator outputs is auditable against the dispatched prompt; a discipline reminder in the universal rules block is not.

**Why this is structural:** Batch 2 telemetry (B2-R01, R03, R05, R07) showed that the verbatim-paste rule above, while well-stated, did not survive context pressure across multiple runs and multi-round runs. The rule is fundamentally a "compare your text to the prior text" rule and cannot work if the prior text isn't in the dispatch. The checklist makes the omission visible at dispatch time rather than at convergence-assessment time.

**The cost:** ~10-15 tokens of orchestrator output per R2+ dispatch. The benefit: bullet-tracking discipline becomes verifiable from the conversation transcript without reading the dispatched-prompt body.

### Round-1 dispatch construction

Include the "especially watches for" list for the persona's specialty verbatim in the dispatch prompt. Add a specific instruction: *"Cross-check against the 'especially watches for' list before submitting. For each item, either (a) cover it with a finding, or (b) note explicitly in your reasoning that the design doesn't require it (validate-by-absence). Do not silently skip a watches-for item."* This was load-bearing in Batch 1 — multiple runs surfaced missed angles caught only via R2 pushback against the persona's own list (rubric item 2 + persona cross-check). Front-loading the cross-check into R1 reduces round count.

### Universal rules block

Constant across all expert dispatches:

- **Severity calibration:** Critical / High / Medium / Minor. Critical only if design is unimplementable or unsafe; High if significant rework; Medium if real concern with known fix; Minor if a nit. Not everything is Critical.
- **Reasoning rigor:** every finding must include domain-specific reasoning per the persona's "what rigorous reasoning looks like" rubric. `verified by:` must follow one of the 5 evidence shapes (see output-template.md).
- **Pushback handling (rounds 2+):** concede valid challenges; defend with evidence where right; distinguish "I was wrong" from "you misread me"; never re-raise a conceded issue.
- **Bullet-tracking discipline (rounds 2+):** when producing a consolidated final list, each `kept` item MUST be character-identical to the prior draft's bullet text. Any of the following → label `refined`, NOT `kept`: a paraphrase, an added cross-reference, an appended `Note:`, a status-tag change, a tightened recommendation clause, or any added/removed word. Do NOT use placeholders like `[Full text preserved from Round 1]` — re-emit the verbatim text or use a different label. A `kept` label on non-character-identical content is the documented drift this discipline targets, and rubric item 5 will catch it. If a bullet's substance is unchanged but you're tempted to tighten its wording, the label is `refined` — the substance survival is what matters, not the label name.
- **Scope discipline:** stay in your domain + specialty lens; out-of-scope wandering is itself a pushback target.
- **Anti-flattery:** no "great design overall" preambles. Get to the issues.

### Anti-bias instruction (main agent)

When applying the pushback rubric: treat the section as if a peer wrote it. The main agent's job is to challenge the expert's review, not defend the section. If the expert is right, push back becomes "I agree, no challenge"; if the expert is wrong, articulate why specifically.

### Anti-sycophancy active force

If the expert withdrew or refined every round-N-1 finding without defending any, the next pushback MUST be:

> Pick your strongest remaining finding and defend it as if I'm wrong. If you cannot defend any finding, your round-1 review was over-confident — say so explicitly.

### Retention between rounds

- Round N-1 expert response: verbatim.
- Round N-1 pushback: verbatim.
- Rounds ≤ N-2: compact both expert response and pushback to 5-bullet summaries, unconditionally, at the moment round N starts.

### Round-1 zero-challenge

If main agent's rubric pass on round 1 produces zero substantive challenges, terminate as `converged in 1 round`. Output template requires ≥3 validated assumptions with valid `verified by` shapes — otherwise fall back to standard template with `Unusually thin review` warning.

### Degenerate review

Abort as `Review degenerate; consider invoking a different specialty or the freeform path with a more focused expertise string.` if round-1 subagent output has fewer than 3 findings OR all findings have severity Minor.

## Transcripts sidecar

The state file holds the rendered output. The transcripts sidecar holds the raw debate so the user can verify the loop wasn't two instances of Claude nodding at each other.

### Path

`~/.claude/sme-reviews/<section-slug>/<domain>/<specialty-slug>.transcripts.md`

Sibling to the state file. Same slug derivation, different suffix.

### Write timing

Append-only, written at the end of every round alongside the state file. Never truncated, never compacted. Cheap on disk; the audit value depends on raw fidelity.

### Format

```markdown
# Transcripts — <section-heading>

> Domain: <domain> · Specialty: <specialty> · Started: <ISO-8601>

## Round 1

### Expert response (verbatim)

<full subagent output, no compaction>

### Main-agent pushback (verbatim)

<full pushback message, no compaction>

## Round 2

### Expert response (verbatim)
...
```

Each round appended as a new H2 block. Round-1 zero-challenge runs still get a Round 1 block with the expert response and a `(no pushback — round-1 zero-challenge)` placeholder under pushback. Degenerate-review aborts still get a Round 1 expert block plus an `(aborted: degenerate)` line.

### Footer surface

The rendered output emits a `> **Transcripts:** <path>` line in the preamble blockquote so the user can open the file (see `output-template.md` rendering rules).

### `show transcripts` re-invocation

The orchestrator recognizes natural-language asks for the transcripts:

- `show transcripts`
- `show me the transcripts`
- `show me the debate`
- `show me the rounds`
- `show transcripts for <section-hint>`

Resolution:

1. If the invocation names a section hint, match against existing transcripts files under `~/.claude/sme-reviews/` by section-slug substring.
2. Else, default to the most recent SME review in this Claude Code session (the orchestrator tracks the last `(section, domain, specialty)` it ran).
3. If multiple matches and no hint, list candidates: `Multiple recent reviews — pick one: <list with paths>.`
4. If no match: `No SME review transcripts found. Run a review first.`

On match, dump the transcripts file inline (or, if very long, the user-facing message says `Transcripts at <path> — N rounds, ~M lines. Show inline (paste full file) or open externally?`).

This is a no-section command; it does not run the debate loop and does not write state.

## List specialties

A no-section command. The orchestrator recognizes:

- `list specialties`
- `what specialties are available`
- `what experts can you bring`
- `show me the specialties`
- `which experts do you have`

On match, build the catalog dynamically (avoids drift between this file and the persona files):

1. List the 13 curated domain slugs (see Curated catalog above).
2. For each domain, read `experts/<domain>.md` and extract every `### <specialty-slug>` heading under the `## Specialties` section.
3. Render as a grouped list, one domain per H4, specialties as bullets.
4. Append a short note: `Plus a freeform fallback for specialties not in the catalog (e.g., "SOC analyst", "compiler frontend") — the orchestrator runs a recognition gate before dispatching freeform.`

Render format:

```markdown
#### Available SME experts

**backend** — request-path, postgres-perf, kafka-streaming, batch-etl, idempotency-and-retries, caching-tiers, background-jobs
**api-design** — versioning, idempotency, ...
[...all 13...]

_Freeform fallback available for specialties not in the catalog. Invoke as e.g. "Get a SOC analyst review of this." — recognition gate refuses unrecognized expertise rather than confabulating._
```

This is a no-section command; it does not run the debate loop and does not write state. If the user follows up with a section + specialty, the standard procedure runs against that input.

## Pushback rubric

The 5-item rubric the main agent applies to each expert response:

1. **Reasoning rigor** — Are assumptions explicitly stated and validated? Are findings backed by domain-specific reasoning per the persona's "what rigorous reasoning looks like"? Are recommendations concrete enough to action (per the 5 evidence shapes)?
2. **Missed/scope balance** — What relevant angles were missed given the section's content? Did the expert wander out of their domain+specialty lens?
3. **Severity calibration** — Are findings calibrated by impact? Apply the probe: for any **Critical**, the design must be unimplementable or actively unsafe under realistic conditions — not "wrong about an edge case" or "missing a defense in depth." For any **High**, the consequence should materialize today under the design's stated conditions, not require a triggering event (CVE, market change, future feature, hypothetical adversary) that has not occurred. Contingency-driven defects often calibrate to Medium. Probe shape to issue in pushback: *"the consequence requires <event X>; the design works without it today; is severity reflecting blast radius today or blast radius under hypothetical future events?"* This probe was load-bearing in Batch 1 telemetry — surfaced 4 of 7 calibration corrections.
4. **Pushback handling** (rounds 2+) — Did the expert concede valid challenges, defend with evidence, distinguish "I was wrong" from "you misread me"?
5. **Bullet-tracking against draft** (rounds 2+, when expert produces a consolidated final list) — Does every item marked `kept` actually appear in the original draft text? Spot-check by quoting back. A `kept` label on a fabricated bullet is a silent regression — fail the round and require correction.

The pushback message itself: a structured challenge list that names each rubric concern, the specific finding it applies to, and what would address it.

## Convergence test

Two conditions, both required:

### 1. Fixed-point test

Main agent scores: *"Would re-applying the pushback rubric to the current expert response produce meaningful new content vs. restate prior?"* If the answer is "restate prior" — i.e., the next pushback would be a paraphrase of the previous — converged.

This is a content-stability test, not a rubric-exhaustion test. The rubric items 2 (missed angles) and 4 (pushback handling) are inherently generative; using "any rubric item produces a challenge" as the convergence test would never converge.

### 2. Anti-oscillation guard

Track the last 3 rounds. If a finding withdrawn in round N-1 reappears (in any form) in round N, mark as drift → no convergence regardless of fixed-point.

Both conditions must hold to declare converged.

## Failure handling

- **Subagent unreachable (transient — rate limit, 5xx, network):** retry up to 2 times with backoff (5s, 15s). Total wall-clock cap 30s.
- **Subagent error (deterministic — schema validation, persistent auth):** no retry; surface actual error: `SME review failed: <reason>. Retry, or rephrase the invocation.`
- **Malformed output:** defined as missing required output-contract field (per output-template.md), non-parseable structure, or refusal-to-respond. One corrective retry that includes (a) what was missing/wrong, (b) the format spec re-stated. Second failure → abort with error.
- **Valid refusal** ("I cannot review, outside my domain"): not malformed. Treat as orchestrator-level routing failure (the recognition step should have caught it); surface to user with explanation. Do not retry.
- **State write failure:** surface to user with the path that failed; offer continue-without-persistence vs abort. No automatic fallback.
- **Main agent's pushback formulation returns empty when findings demand it:** treat as round-1 zero-challenge (terminate as converged with ≥3 validated assumptions; otherwise abort as Review degenerate).

## Continuation reader (cross-invocation)

Before dispatching the expert, the orchestrator looks for prior reviews on the same section.

### Detection

List `<state-dir>/<section-slug>/**/*.md` recursively. Each match is a potential prior review.

### Cache hit on same (domain, specialty)

If a state file matches the current `(domain, specialty)`:

- Compare normalized current section text against `section-content-hash` in the file's frontmatter.
- **Unchanged:** return existing review verbatim with banner: `_No re-review needed — section unchanged since prior review at <timestamp>. Showing prior findings. To force a fresh review, say 'force re-review' or invoke with --force._`
- **Changed:** run loop with prior findings injected as a "did the revision address these?" block in the expert's prompt (this is a stronger signal than the standard prior-review-context block).

### Force re-review

The orchestrator recognizes either `force re-review` (natural language) or `--force` (token) as override of cache hit.

### Compaction for prior-review context

When compacting a prior review file (different domain/specialty) for injection into the new expert's prompt:

- **Standard prior review:** 3-5 bullets — 1-2 assumptions, 1-2 top critical/high findings, 1 disputed.
- **Heavy review** (>3 Critical OR >5 High in `finding-counts`): up to 10 bullets; all Critical findings listed (one line each); High count surfaced.
- **Disputed findings:** every disputed finding gets its own bullet, no cap.

### Incomplete-state handling

State files with `convergence-status: incomplete` are skipped from compaction (they may be from a concurrent in-progress invocation or a cancelled run; their findings aren't authoritative). Skipped priors are surfaced once to the orchestrator as a footnote: `_<N> incomplete prior reviews skipped (<list>); see <state-dir> for details._`

## Cross-cutting concerns catalog

Some concerns legitimately appear under multiple specialties. Persona files duplicate these bullets in the relevant specialties; this catalog documents the policy so contributors can audit drift.

| Concern | Curated specialties that claim it |
|---|---|
| TLS / transport security | security/network, security/web-app, security/cryptography |
| Rate limiting | security/web-app, api-design, reliability, infrastructure/networking |
| Idempotency keys | backend/idempotency-and-retries, api-design, reliability |
| Schema migrations | data-modeling, backend/request-path, reliability |
| Observability hooks | reliability, infrastructure, distributed-systems |
| Auth boundaries | security/web-app, security/identity-and-access, api-design |
| Instruction conflict / boundary | prompting/prompt-design, skill-design/superpowers-skill-design |
| Description-vs-behavior drift | prompting/prompt-versioning, skill-design/skill-evolution |
| Prompt-injection surfaces | security/web-app, prompting, agent-systems, skill-design/skill-supply-chain-and-injection |

Cross-references between persona files are forbidden (per `anthropic-best-practices.md` lines 354-381 — multi-level references load unreliably). Duplicate the bullet; document the duplication here.
