# Scenario: Multi-Round Converged

**Setup:** Paste the contents of `tests/test-sections/well-formed-backend.md` as an assistant turn in a fresh Claude Code conversation. No prior state files exist for this section under `~/.claude/sme-reviews/`.

**Invocation:** `Get a backend expert review of that section.`

**Expected behavior:**
- The orchestrator emits a one-line preview before proceeding (first 80 chars of the section).
- The output header shows `Rounds: 2, 3, or 4 of 6 — converged` (round count is within the soft cap of 4).
- The `#### Findings` block contains at least one finding with severity Medium or High. A well-engineered but non-trivial section like `well-formed-backend.md` should produce real findings (e.g., missing index on `order_line_items.order_id` cardinality analysis, outbox poller 500ms drain interval at high throughput, Redis fallback path under load).
- Every finding has `Status: validated` or `Status: refined` (no `disputed` status if convergence was reached).
- The `#### Validated assumptions` block contains at least 3 entries with valid `verified by:` evidence shapes.
- The output ends with `Revised section ready. Adopt as the new version?` (no disputed findings, so this variant of the hand-off line is used).
- A state file is written with `convergence-status: converged` and `round-count` between 2 and 4.

**Anti-patterns (must NOT happen):**
- Round count of 1 — the trivial path fired on a non-trivial section. This suggests the main agent is not applying the pushback rubric to a section that has real engineering content worth challenging.
- Round count of 5 or 6 — the soft cap or hard ceiling was hit on a well-formed section. This indicates over-aggressive pushback that does not converge. Investigate whether the expert is manufacturing severity-inflation findings or the main agent is refusing to accept reasonable responses.
- Any finding with severity Critical on this section — the section is well-formed and does not contain critical flaws. A Critical finding here would be a false positive.
- `convergence-status: hard-ceiling` or `convergence-status: unresolved-at-soft-cap` in the state file.
- The `#### Disputed findings` block contains entries — no finding should be unresolved on a well-formed section.

**Tuning signals:** Log round-count per invocation. If >20% of runs on this fixture hit round 4 without converging, the soft cap may need to be raised to 5. Track which rubric items are driving the extra rounds (reasoning-rigor challenges vs. severity-calibration challenges).
