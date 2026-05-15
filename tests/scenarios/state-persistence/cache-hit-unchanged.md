# Scenario: Cache Hit — Section Unchanged

**Setup:** In a fresh Claude Code conversation:
1. Paste the contents of `tests/test-sections/well-formed-backend.md` as an assistant turn.
2. Run the invocation below and let it complete. A state file is now written at `~/.claude/sme-reviews/order-ingestion-service/backend/backend.md` (or the equivalent specialty slug if one was named). Note the `timestamp` value from the state file's YAML frontmatter and the `section-content-hash`.
3. Without modifying the section text, run the same invocation again in the same conversation (paste the same section text again, same user prompt).

**Invocation:** `Get a backend expert review of that section.` (run this twice, with the same section text pasted before each invocation)

**Expected behavior:**
- The second invocation returns the cache-hit banner exactly: `_No re-review needed — section unchanged since prior review at <timestamp>. Showing prior findings. To force a fresh review, say 'force re-review' or invoke with --force._`
- The banner's `<timestamp>` matches the timestamp in the state file from the first run.
- The output after the banner is the full prior review verbatim — the same findings, the same validated assumptions, the same revised section.
- No new debate loop rounds are run on the second invocation.
- The state file's `round-count` and `convergence-status` are unchanged after the second invocation (no new write).

**Anti-patterns (must NOT happen):**
- The second invocation runs the full debate loop again without checking the cache — this is a false cache miss. The section content hash must be computed and compared against the stored hash before running the loop.
- The second invocation returns the cache-hit banner but shows different findings from the first run — the banner claims cache hit but the output is regenerated. The output must be verbatim from the state file.
- The cache-hit banner does not include the `force re-review` or `--force` discoverability prompt — the spec requires the banner to always include this guidance.
- The second invocation fails silently with no output and no banner.

**Tuning signals:** Log whether the `section-content-hash` comparison succeeds or fails on each invocation. If the second invocation is a cache miss when the section is genuinely unchanged, the normalization function (trailing whitespace, blank line collapse, fence stripping) may be producing a different hash for identical content — inspect whether the paste introduced whitespace differences.
