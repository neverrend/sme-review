# Scenario: No Section in Context — Refusal

**Setup:** Start a fresh Claude Code conversation. Do NOT paste any design section. The conversation context contains only the user's invocation message below. There are no prior assistant turns, and no design sections within the last 5 assistant turns (since there are none).

**Invocation:** `Get a backend expert review of my design.`

**Expected behavior:**
- The orchestrator scans back through assistant turns (up to 5) and finds no clearly-formatted design section (no H2/H3 heading, no demarcated design block).
- The orchestrator refuses with the exact message: `_No design section to review in recent context. Articulate the design as a section first, or rephrase the question as a design proposal I can extract._`
- No debate loop runs. No state file is written. No preview is emitted.
- The refusal message is the complete response — the orchestrator does not attempt to review the question itself ("my design") as if it were a design section.

**Anti-patterns (must NOT happen):**
- The orchestrator silently falls back to treating the user's question as a design section and runs a review of the text `"my design"` — this is the silent-fallback behavior the spec explicitly prohibits.
- The orchestrator asks a clarifying question like `"Which design would you like me to review?"` instead of refusing — while asking for clarification is helpful in principle, the spec mandates the specific refusal message ("Articulate the design as a section first") to prevent open-ended chatting without a concrete design to review.
- The orchestrator proceeds with a degenerate review of the empty context and produces an `Unusually thin review` output — this would confuse the user about what was actually reviewed.
- The orchestrator emits the ambiguous-case confirmation prompt when no section is present — the ambiguous-case path requires at least two candidate sections, not zero.

**Tuning signals:** n/a — this is a deterministic guard test. The refusal message either appears verbatim or it does not. If the orchestrator produces any review output when no section is present, the extraction guard is not firing.
