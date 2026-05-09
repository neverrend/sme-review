# Scenario: Ambiguous Extraction Requires Confirmation

**Setup:** In a fresh Claude Code conversation, send a single assistant turn containing the full contents of `tests/test-sections/ambiguous-extraction-fixture.md`. That file contains: (1) a primary design section (`## Notification Dispatch Service`) and (2) an inline footnote-style mini-design block beginning with `We should also consider a push-only fast path with these tradeoffs:...`. The inline block is a second candidate section because it presents a distinct design proposal with its own tradeoffs.

**Invocation:** `Get a backend expert review of that section.`

**Expected behavior:**
- The orchestrator detects multiple candidate sections in the most recent assistant turn: the primary `## Notification Dispatch Service` section and the inline `push-only fast path` mini-design block.
- The orchestrator emits the single ambiguous-case confirmation prompt (exactly one prompt, not a menu): `_Reviewing this as the target section: "Notification Dispatch Service..."_`. Confirm or point at a different one.`
- The orchestrator does NOT silently pick one candidate and proceed — it waits for the user to confirm or redirect.
- After the user responds with `yes` or `confirm` or equivalent positive acknowledgment, the orchestrator proceeds with the primary section and runs the full review.
- If the user redirects by pointing at the inline block (e.g., `"No, review the push-only fast path part"`), the orchestrator extracts the inline block as the new target and emits a new preview for that section.

**Anti-patterns (must NOT happen):**
- The orchestrator silently picks the primary section and proceeds without any confirmation — the silent-pick path is explicitly forbidden by the spec. The user must acknowledge which section is being reviewed.
- The orchestrator emits a multiple-choice menu listing both candidates — the spec mandates a single confirmation, not a menu. `Confirm or point at a different one.` is the required format.
- The orchestrator emits two confirmation prompts (one per candidate) instead of one — the prompt must be singular.
- The orchestrator misidentifies the inline block as the primary section and asks for confirmation to review the push-only fast path, ignoring the main section heading.

**Tuning signals:** Log which section was identified as the primary candidate. If the orchestrator consistently selects the inline block over the main H2 heading as the primary, the extraction heuristic is weighting inline text too heavily over heading-demarcated sections.
