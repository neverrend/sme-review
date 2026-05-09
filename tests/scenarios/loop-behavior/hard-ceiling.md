# Scenario: Hard-Ceiling Termination

**Setup:** Paste the contents of `tests/test-sections/tangled-no-converge.md` as an assistant turn in a fresh Claude Code conversation. No prior state files exist for this section. The section deliberately contains four genuinely contestable design choices: eventual consistency vs. strong consistency for stock reservation, build vs. buy for replenishment forecasting, 12-microservice vs. monolith-first split, and write-through vs. write-behind cache strategy.

**Invocation:** `Get a distributed-systems expert review of that section.`

**Expected behavior:**
- The orchestrator emits a one-line preview before proceeding.
- The output header shows `Rounds: 6 of 6 — hard-ceiling`. The round count is exactly 6 (the hard ceiling), not fewer.
- The output contains a `#### Disputed findings` block with at least one entry. Each disputed entry shows both the expert position and the reviewer position, and ends with `User adjudication needed.`
- The hand-off line reads `Revised section ready (excludes <N> disputed findings). Adjudicate disputes, or adopt as-is?`
- The state file has `convergence-status: hard-ceiling` and `round-count: 6`.
- The synthesis preamble explicitly says something like `6 rounds (hard ceiling). <M> findings unresolved.` matching the spec template for the hard-ceiling case.

**Anti-patterns (must NOT happen):**
- The output header shows fewer than 6 rounds — the skill converged on a section designed to produce unresolvable disagreement. This would be a false convergence: the main agent accepted challenged findings without sufficient pushback, or the expert capitulated without defending contestable positions.
- The `#### Disputed findings` block is absent or empty when round count is 6 — if the hard ceiling was hit, at least one finding should be unresolved; an empty disputed block at round 6 means the state tracking is incorrect.
- The skill produces a `convergence-status: converged` state file at round 6 — converged and hard-ceiling are mutually exclusive.
- The revised section silently incorporates recommendations from disputed findings without marking them as excluded.

**Tuning signals:** Note which specific design choices in the section produced disputed findings. If all four produce disputes, the section is well-calibrated for this test. If zero produce disputes (hard ceiling hit but no disputed findings), investigate whether the convergence-status write and disputed-tracking logic are correctly coupled.
