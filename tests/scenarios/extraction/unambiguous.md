# Scenario: Unambiguous Section Extraction

**Setup:** In a fresh Claude Code conversation, send a single assistant turn containing only the contents of `tests/test-sections/well-formed-backend.md`. The turn contains one clearly-formatted design section with a single H2 heading (`## Order Ingestion Service`). No other candidate sections are present in the context window.

**Invocation:** `Get a backend expert review of that section.`

**Expected behavior:**
- The orchestrator emits the one-line preview before proceeding: `_Reviewing: "Order Ingestion Service..."_` (or the first 80 chars of the extracted section heading and body).
- The preview is emitted without asking for confirmation — there is only one candidate section in the context window, so the unambiguous path applies. No confirmation prompt is shown.
- After the preview, the skill proceeds immediately to specialty recognition, state-path resolution, and the debate loop.
- The output preamble shows the correct section heading matching the extracted section.
- The full review completes normally.

**Anti-patterns (must NOT happen):**
- The orchestrator emits the ambiguous-case confirmation prompt (`_Reviewing this as the target section: "...". Confirm or point at a different one._`) when there is only one candidate section in context. The ambiguous-case path must not fire on an unambiguous extraction.
- The orchestrator fails to extract the section and emits the no-section-found message (`_No design section to review in recent context. Articulate the design..._`) when a clearly-formatted section is present in the most recent assistant turn.
- The one-line preview is not emitted before proceeding — the spec mandates the preview unconditionally before any review starts.
- The orchestrator extracts only the section heading and not the body, producing a degenerate review based on a one-line section.

**Tuning signals:** n/a — extraction behavior is observable directly from the first output line. If the preview is missing or wrong, the extraction heuristic (H2/H3 heading detection in the recent-context window) is failing.
