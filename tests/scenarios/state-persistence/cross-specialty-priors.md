# Scenario: Cross-Specialty Priors Injection

**Setup:** In a fresh Claude Code conversation:
1. Paste the contents of `tests/test-sections/well-formed-backend.md` as an assistant turn.
2. Run the first invocation (security/network review). Let it complete. Verify a state file was written at `~/.claude/sme-reviews/order-ingestion-service/security/network.md`.
3. In the same conversation (same cwd, same section still in context), run the second invocation (security/web-app review).

**Invocation:** Two sequential invocations on the same section (see below).

**Invocation (first run):** `Get a network security expert review of that section.`

**Invocation (second run):** `Now get a web-app security expert review of the same section.`

**Expected behavior:**
- On the second invocation, the continuation reader lists the state files in `~/.claude/sme-reviews/order-ingestion-service/` recursively and finds `security/network.md` from the first run.
- The second expert's dispatch prompt includes a compacted prior-review context block summarizing the first review. The compacted block follows the standard-prior-review format: 3-5 bullets covering 1-2 validated assumptions, 1-2 top Critical/High findings, and 1 disputed finding (if any from the first run).
- The second expert's output mentions or responds to at least one concern raised in the first review — demonstrating that the prior-review context was actually read and used.
- The second state file is written at `security/web-app.md` (a separate file, not overwriting `network.md`).
- Both state files have the same `section-slug` (`order-ingestion-service`) and `section-content-hash` (section was not modified between runs).

**Anti-patterns (must NOT happen):**
- The second expert receives no prior-review context — the cross-invocation continuation reader failed to detect `security/network.md`. The second review would then duplicate findings that the first review already identified without referencing them.
- The second expert receives the full verbatim text of the first review rather than the compacted 3-5 bullet summary — the compaction step exists to avoid token budget exhaustion; injecting the full prior review violates the spec.
- The second state file overwrites the first (`network.md` is replaced by `web-app.md` content) — state files are per-(section, domain, specialty) and must be separate files.
- An incomplete-state prior review (from a cancelled or in-progress run) is included in the compacted priors. Incomplete state files must be skipped and surfaced as a footnote only.

**Tuning signals:** Log the compacted-prior content injected into the second expert's prompt. Verify bullet count is between 3 and 5 for a standard-weight prior review (not >3 Critical or >5 High in the first review's finding-counts).
