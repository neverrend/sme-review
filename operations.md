# Operations

This file collects the orchestration mechanics referenced from `SKILL.md`. Each H2 section is a self-contained subsystem the orchestrator follows when running the skill.

## State path resolution

The skill writes per-(section, domain, specialty) state files. Resolution follows this order:

```text
project_markers = [.git, package.json, pyproject.toml, go.mod, Cargo.toml,
                   Gemfile, composer.json, pom.xml, build.gradle, Makefile, .claude/]

function is_project_local(cwd):
    if cwd == "/" or cwd == $HOME or cwd is under $TMPDIR: return false
    if any project_marker exists in cwd or ancestors up to $HOME: return true
    if .claude/ exists in cwd: return true
    return false

function can_write(path):
    create+delete <path>/.write-probe-<random>
    return success

function resolve_state_path(cwd):
    primary   = cwd_state if is_project_local(cwd) else home_state
    if can_write(primary): return primary
    secondary = home_state if primary == cwd_state else None
    if secondary and can_write(secondary): return secondary, fallback=true
    return null, abort=true
```

`cwd_state` is `<cwd>/.claude/sme-reviews/<section-slug>/<domain>/<specialty-slug>.md`.
`home_state` is `~/.claude/sme-reviews/<section-slug>/<domain>/<specialty-slug>.md`.

When `fallback=true`, surface in output preamble: `_Project state dir not writable; falling back to ~/.claude/sme-reviews._`

When `abort=true`, surface to user: `State persistence unavailable in both project and home dirs. Continue without persistence (cross-invocation continuity disabled), or abort?` Wait for explicit user choice.

## Section content hashing

Compute `section-content-hash` (used for cache-hit detection) by:

1. Trim trailing whitespace per line.
2. Collapse runs of blank lines to a single blank line.
3. Strip trailing whitespace inside code-block fences.
4. Headings: keep case (semantic).
5. SHA-256 of the result.

Reproducible. Bytewise hash of the *normalized* form so editor-driven whitespace drift doesn't trigger spurious cache misses.

## Concurrency control

For each `(section-slug, domain, specialty-slug)`, acquire a lockfile before running the loop:

- Lockfile path: `<state-dir>/<section-slug>/<domain>/.<specialty-slug>.lock`
- Acquisition: `O_CREAT | O_EXCL` open. Atomic — one writer wins.
- Stale sweep: a lockfile older than 30 minutes is treated as abandoned and removed before re-attempting acquisition.
- If lock held by another live invocation: refuse with `Another SME review on this specialty is in progress; retry in a moment, or override with 'force re-review'.`
- Lockfile content: PID + start timestamp (for diagnostics; not used for liveness).
- Release on terminal write of state file (success or abort).

State writes are atomic: write to `<dir>/.<specialty-slug>.md.tmp.<random>` in the same directory, then `rename(2)` to the target. Same-FS by construction; no cross-mount issues.

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

### Universal rules block

Constant across all expert dispatches:

- **Severity calibration:** Critical / High / Medium / Minor. Critical only if design is unimplementable or unsafe; High if significant rework; Medium if real concern with known fix; Minor if a nit. Not everything is Critical.
- **Reasoning rigor:** every finding must include domain-specific reasoning per the persona's "what rigorous reasoning looks like" rubric. `verified by:` must follow one of the 5 evidence shapes (see output-template.md).
- **Pushback handling (rounds 2+):** concede valid challenges; defend with evidence where right; distinguish "I was wrong" from "you misread me"; never re-raise a conceded issue.
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

## Pushback rubric

The 4-item rubric the main agent applies to each expert response:

1. **Reasoning rigor** — Are assumptions explicitly stated and validated? Are findings backed by domain-specific reasoning per the persona's "what rigorous reasoning looks like"? Are recommendations concrete enough to action (per the 5 evidence shapes)?
2. **Missed/scope balance** — What relevant angles were missed given the section's content? Did the expert wander out of their domain+specialty lens?
3. **Severity calibration** — Are findings calibrated by impact, or is everything Critical?
4. **Pushback handling** (rounds 2+) — Did the expert concede valid challenges, defend with evidence, distinguish "I was wrong" from "you misread me"?

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
- **State write failure:** try `<cwd>/.claude/sme-reviews/...` first; auto-fallback to `~/.claude/sme-reviews/...`; abort with user choice if both fail.
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
