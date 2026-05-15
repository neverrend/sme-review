# Output template

Final synthesis format the orchestrator renders to the user at terminal state. Heading hierarchy is H3/H4 max (H1 would visually shout in conversation).

## Standard template

```markdown
### SME Review: <section-title>

> **Reviewed as** <domain> expert specializing in <specialty>.
> **Rounds:** <N> of <max> — <converged | soft-cap-exceeded | hard-ceiling>
> **Status:** All findings resolved | <M> findings unresolved — see Disputed below
> **Model:** <model-id used for the expert subagent>
> **Transcripts:** ~/.claude/sme-reviews/<section-slug>/<domain>/<specialty-slug>.transcripts.md

#### Validated assumptions
- <assumption> — verified by: <one of the 5 evidence shapes below>

#### Findings
[Severity-ordered: Critical → High → Medium → Minor. Withdrawn findings excluded from this block.]

**[Critical] <finding-title>**
- Issue: <concrete description>
- Reasoning: <domain-specific rigor per persona's "what rigorous reasoning looks like">
- Recommendation: <specific, actionable change>
- Status: validated | refined

**[High] <finding-title>**
…

**[Medium] <finding-title>**  (showing 5 of 12 Medium)
…

[If Medium > 10 OR Minor > 10, emit before the Medium/Minor list:]
> ⚠️ Volume signal: <N> Medium, <M> Minor — consider whether this section needs structural rework rather than line-edits.

#### Disputed findings
[Only present when convergence wasn't reached on a finding. Both positions surfaced.]

**<finding-title>**
- Issue: <description>
- Expert position: <stance + reasoning>
- Reviewer position: <stance + reasoning>
- User adjudication needed.

#### Considered and resolved
[Withdrawn findings as one-liners.]
- <finding-title> — withdrawn round <N>: <one-sentence reason>

#### Meta-recommendations
[Cross-cutting observations only. Process improvements, scope changes, follow-up specialties recommended. Empty section omitted.]
- <observation>

#### Revised section
> [Full revised section text incorporating non-disputed recommendations. Ready to drop in.]
```

## Status field semantics

- **validated** — agreed by both expert and reviewer, no significant pushback was needed.
- **refined** — survived pushback but sharpened (severity adjusted, scope tightened, recommendation made more specific).
- **disputed** — unresolved disagreement; surfaces under "Disputed findings."
- **withdrawn** — conceded during the loop; surfaces in "Considered and resolved" tail (one-liner).

## `verified by:` evidence shapes (constrained)

Each validated assumption must include `verified by:` with content matching one of the 5 shapes:

1. **File path with line range** — e.g., `src/auth/handler.ts:42-67`.
2. **Executable check** — command + expected output. `pg_isready -h db -p 5432` → `accepting connections`.
3. **Calculation** — with the actual numbers. `5000 req/s × 200ms latency = 1000 in-flight`.
4. **Threat scenario** — concrete attacker + concrete consequence. `Attacker with read access to logs reads session token, replays for 24h until expiry → full account takeover`.
5. **External citation** — with link. `RFC 7519 §4.1.7`, `https://owasp.org/...`.

`"domain expertise"`, `"based on experience"`, and similar hand-waves are explicitly invalid. Pushback rubric item 1 (reasoning rigor) enforces this — invalid evidence triggers pushback.

## Truncation policy

Apply when the output would otherwise be excessively long:

1. Validated assumptions: keep all (cheap, load-bearing for trust).
2. Critical findings: keep all.
3. High findings: keep all.
4. Medium findings: keep first 10 (was 5); always show count `(showing 10 of 14 Medium)`.
5. Minor findings: keep first 5; always show count.
6. Disputed findings: keep all (user adjudication required).
7. Considered and resolved: keep all (one-liners are cheap).
8. Volume-signal banner: emit if Medium > 10 OR Minor > 10. Banner phrasing:
   > ⚠️ Volume signal: <N> Medium, <M> Minor — consider whether this section needs structural rework rather than line-edits.
9. Revised section: keep verbatim.
10. Meta-recommendations: keep all that reference Critical/High; truncate to first 10.

## Special-case templates

### Round-1 converged (no pushback warranted)

Triggered when the main agent's rubric pass on round 1 produces zero substantive challenges. Requires **at least 3 validated assumptions** with valid `verified by` shapes — otherwise fall back to standard template with `Unusually thin review — consider invoking a different specialty or the freeform path with a more focused expertise string.` warning.

```markdown
### SME Review: <section-title>

> **Reviewed as** <domain> expert specializing in <specialty>.
> **Convergence:** 1 round (no substantive challenges).
> **Model:** <model-id>
> **Transcripts:** ~/.claude/sme-reviews/<section-slug>/<domain>/<specialty-slug>.transcripts.md

#### Verdict
No substantive issues found. The section is well-supported per a <domain> + <specialty> review.

#### Validated assumptions
- <≥3 entries, each with valid `verified by:` shape>

#### Notes
[Optional minor observations that didn't rise to "finding" level. Skip if none.]
- <note>
```

### Hard ceiling at round 6 (unresolved)

Triggered when the loop hits the hard ceiling without converging. Standard template, but the convergence line reads:

```markdown
> **Rounds:** 6 of 6 — hard-ceiling
> **Status:** <M> findings unresolved — see Disputed below
```

Disputed-findings block is required and must surface both positions for user adjudication.

## State file frontmatter (per-round write)

State files at `<state-dir>/<section-slug>/<domain>/<specialty-slug>.md` get the same body content as the rendered output, with this YAML frontmatter prepended (kebab-case throughout):

```yaml
---
schema-version: 1
domain: <domain>
specialty: <specialty>
section-slug: <section-slug>
section-heading: <full original heading>
section-content-hash: <sha256 of normalized section text>
acknowledged-specialties: [<list, for multi-specialty invocations>]
round-count: <N>
convergence-status: incomplete | converged | unresolved-at-soft-cap | hard-ceiling
prior-specialties: [<domain>/<specialty>, ...]
finding-counts: {validated: 3, refined: 2, disputed: 1, withdrawn: 4}
timestamp: <ISO-8601>
---
```

`convergence-status: incomplete` is the default on each per-round write; flips to a terminal state on the final write.

## Compaction for cross-invocation continuation (tiered)

When a subsequent invocation reads prior state files for the same section, each file is compacted before injection into the new expert's "prior-review context" block. Compaction tier depends on the prior file's `finding-counts`:

- **Standard prior review:** 3-5 bullets — 1-2 validated assumptions, 1-2 top critical/high findings (with status), 1 bullet for disputed (if any).
- **Heavy review** (`finding-counts.validated + finding-counts.refined > 3 Critical` OR `> 5 High`): up to 10 bullets — all Critical findings listed (one line each), High count surfaced.
- **Disputed findings:** every disputed finding gets its own bullet, no cap.

### Incomplete-state handling

State files with `convergence-status: incomplete` are **skipped** from compaction (they may be from a concurrent in-progress invocation or a cancelled run; their findings aren't authoritative). Skipped priors are surfaced once to the orchestrator as a footnote:

> _<N> incomplete prior reviews skipped (<list>); see <state-dir> for details._

Full state files remain on disk for human reference regardless of compaction.

## Hand-off line (post-skill)

The main agent appends one closing line after the rendered output, conditioned on terminal state:

- **No disputed findings:** `Revised section ready. Adopt as the new version?`
- **Disputed findings present:** `Revised section ready (excludes <N> disputed findings). Adjudicate disputes, or adopt as-is?`
- **Round-1 converged:** `No substantive changes. Continue?`

No menu, no multiple-choice. Two options max.

## Rendering rules

- H3/H4 max in conversation rendering (no H1).
- Severity scale: Critical / High / Medium / **Minor** (4-tier).
- Severity labels formatted as `**[Critical] <title>**` (bold + bracketed).
- The opening blockquote (`> **Reviewed as** ...`) is the preamble metadata block; it carries Reviewed-as, Rounds, Status, Model, and Transcripts lines and nothing else. The Transcripts line is always emitted (so the user can audit the debate); the Model line is always emitted (so model-tier drift attribution is possible per `KNOWN-ISSUES.md` item 3).
- Disputed and Considered-and-resolved sections omitted entirely if empty.
- Meta-recommendations section omitted entirely if empty.
