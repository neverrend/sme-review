# Scenario: Cache Miss — Section Content Changed

**Setup:** In a fresh Claude Code conversation:
1. Paste the contents of `tests/test-sections/well-formed-backend.md` as an assistant turn.
2. Run the first invocation below and let it complete. Note the finding titles in the output.
3. Modify the section text — add one sentence to the "Failure modes considered" subsection: `"Additionally, if the Kafka broker is unreachable, the outbox poller writes a circuit-open flag to Redis and pauses draining for 60 seconds."` This changes the section-content-hash.
4. Paste the modified section as a new assistant turn and run the second invocation.

**Invocation:** Two sequential invocations — first on the original section, then on the modified section (see below).

**Invocation (first run):** `Get a backend expert review of that section.`

**Invocation (second run, after modification):** `Get a backend expert review of that section.`

**Expected behavior:**
- The second invocation does NOT return a cache-hit banner; it runs the full debate loop because the section-content-hash has changed.
- The expert subagent's prompt on the second run includes a "did the revision address these?" block that injects the prior findings from the first run. This block is visible as context shaping the expert's response (the expert may comment on whether the Kafka circuit-breaker addition addresses any prior finding).
- The final output of the second run is a new review, not a verbatim copy of the first.
- The new state file overwrites the old one (or is written atomically via `rename(2)`), with a new `section-content-hash` matching the modified section and a new `timestamp`.

**Anti-patterns (must NOT happen):**
- The second invocation returns a cache-hit banner despite the section being modified — this is a false cache hit caused by incorrect hash computation or hash comparison. The section content genuinely changed; a cache hit here means prior findings would be shown that do not reflect the current design.
- The second invocation runs the full loop but does NOT inject prior findings as a "did the revision address these?" block — the prior-findings injection is the key differentiator between a cold-start review and a re-review of a changed section. Without it, the expert treats the modified section as if it has no prior review history.
- The new state file is appended to rather than atomically replaced, resulting in duplicate YAML frontmatter blocks.

**Tuning signals:** Log whether prior findings were injected (look for the "did the revision address these?" block in the expert dispatch prompt). If not injected, the continuation-reader detection step may be failing to find the state file (check path resolution logic).
