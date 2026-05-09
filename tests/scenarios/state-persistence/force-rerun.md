# Scenario: Force Re-Review Overrides Cache Hit

**Setup:** In a fresh Claude Code conversation:
1. Paste the contents of `tests/test-sections/well-formed-backend.md` as an assistant turn.
2. Run the first invocation and let it complete. A state file now exists. The section is unchanged.
3. Without modifying the section, run the second invocation using the `force re-review` natural-language trigger.
4. Without modifying the section, run a third invocation using the `--force` token trigger.

**Invocation:** Three sequential invocations on the same unchanged section (see below).

**Invocation (first run):** `Get a backend expert review of that section.`

**Invocation (second run):** `Get a backend expert review of that section. Force re-review.`

**Invocation (third run):** `Get a backend expert review of that section --force`

**Expected behavior:**
- The second invocation does NOT return the cache-hit banner, despite the section being unchanged. The phrase `force re-review` in the user message overrides the cache check.
- The second invocation runs the full debate loop from round 1. A new review is produced (findings may vary from the first run due to non-determinism; this is expected).
- The new state file is written atomically, updating `section-content-hash` (same content, same hash), `round-count`, and `timestamp`.
- The third invocation similarly does NOT return the cache-hit banner. The `--force` token is recognized as equivalent to `force re-review`.
- Both the second and third invocations produce a review output with the standard structure (preamble, validated assumptions, findings, revised section, hand-off line) — no cache-hit banner appears anywhere in the output.
- The cache-hit banner from a non-forced run includes the text `To force a fresh review, say 'force re-review' or invoke with --force.` — verifying that users can discover this mechanism from a cached result.

**Anti-patterns (must NOT happen):**
- The second invocation returns the cache-hit banner despite the `force re-review` phrase being present in the user message — the force override is not recognized.
- The third invocation returns the cache-hit banner despite `--force` being present — the `--force` token is not recognized.
- The force-rerun produces output that appears to be the verbatim cached review rather than a fresh debate-loop run (e.g., the timestamp in the output header matches the first run's timestamp exactly).
- The `--force` token causes an error or is silently ignored, and a cache hit is returned.

**Tuning signals:** Log whether the force override token was recognized at the orchestrator level. If the cache-hit banner appears despite `force re-review` or `--force` being present, inspect the orchestrator's token-recognition logic.
