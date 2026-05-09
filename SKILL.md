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
3. Resolve state path & acquire lockfile — see [operations.md](operations.md).
4. Check cache hit on section-content-hash — see [operations.md](operations.md).
5. Load persona — see `experts/<domain>.md` (curated) or [experts/_freeform-template.md](experts/_freeform-template.md) (freeform).
6. Run debate loop — see [operations.md](operations.md).
7. Render output — see [output-template.md](output-template.md).
