---
name: sme-review
description: Use when the user asks for a staff, SME, or domain-expert review of a design section, architecture proposal, system prompt, or plan currently in conversation — pre-implementation design, not committed code.
---

# SME Review

Performs a domain-expert review of a design section the LLM most recently presented. Dispatches an expert subagent (curated or freeform), the main agent pushes back across multiple rounds, and the loop converges on validated findings + a revised section.

## When to invoke
- User asks for an expert/staff/SME critique of in-conversation design content.
- A design section has just been presented and the user wants rigorous adversarial review before adopting it.

## When NOT to invoke
- User wants code review of committed work → use `requesting-code-review`.
- User wants to develop a design from scratch → use `brainstorming`.
- User asks an open-ended question without an articulated design → refuse and prompt to articulate.

## Procedure
1. Extract section — see [operations.md](operations.md).
2. Recognize specialty — see [operations.md](operations.md).
3. Resolve state path — see [operations.md](operations.md).
4. Check cache hit on section-content-hash — see [operations.md](operations.md).
5. Load persona — see `experts/<domain>.md` (curated) or [experts/_freeform-template.md](experts/_freeform-template.md) (freeform).
6. Run debate loop, writing state file + transcripts sidecar at end of every round — see [operations.md](operations.md).
7. Render output with Transcripts line in preamble — see [output-template.md](output-template.md).

## Secondary modes

- **`show transcripts`** — natural-language asks like *"show me the transcripts"* / *"show me the debate"* dump the verbatim per-round transcripts file from the most recent (or named) review. No new debate loop, no state write. See [operations.md](operations.md) → "Transcripts sidecar".
- **`list specialties`** — natural-language asks like *"list specialties"* / *"what specialties are available"* / *"what experts can you bring"* return the curated catalog (13 domains × their specialties) plus a note on the freeform fallback. No section required. See [operations.md](operations.md) → "List specialties".
