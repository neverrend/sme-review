# Scenario: Restated Findings (Anti-Oscillation Guard)

**Setup:** Paste the contents of `tests/test-sections/well-formed-backend.md` as an assistant turn. No prior state files. This scenario tests the anti-oscillation guard defined in `operations.md` § "Convergence test" (condition 2): if a finding that was explicitly withdrawn in round N-1 reappears in round N (in any form, including renaming or rephrasing), the guard marks drift and prevents convergence regardless of the fixed-point test passing.

This pathology requires the expert to withdraw a finding in one round and then re-raise it in the next. The guard must detect this even if the finding is renamed (e.g., "Missing idempotency on Redis fallback" in round 1, withdrawn in round 2, reappears as "Redis fallback path lacks idempotency guarantee" in round 3).

**Invocation:** `Get a backend expert review of that section.`

**Expected behavior:**
- If the expert raises a finding in round N-1, explicitly withdraws it in round N-1's response (e.g., "I concede — the outbox pattern already addresses this"), and then raises it again (in any phrasing) in round N, the round-N convergence check does NOT declare convergence, even if the fixed-point test would otherwise pass.
- The output or debug log shows `drift: withdrawn finding reappeared` (or equivalent signal) as the reason the anti-oscillation guard blocked convergence on that round.
- The skill continues to the next round after detecting drift, rather than terminating incorrectly as converged.

**Anti-patterns (must NOT happen):**
- The skill declares `converged` at round N when a withdrawn finding reappeared in round N — this is the primary failure the guard exists to prevent. A "converged" result that includes a previously-withdrawn finding presented as newly-validated is a false positive.
- The anti-oscillation guard fires on a finding that was refined (severity adjusted, scope narrowed) rather than withdrawn — refinement is not withdrawal. The guard should only block on findings with explicit withdrawal status in round N-1 that reappear in round N.
- The guard fires spuriously on a finding that happens to share keywords with a withdrawn finding but is substantively different in scope.

**Tuning signals:** Log each finding's lifecycle status per round (validated, refined, withdrawn, disputed) to build a per-finding history. If the guard never fires across 10 runs on this fixture, either the expert model reliably avoids re-raising withdrawn findings (desired behavior) or the guard is not being evaluated at all. To stress-test the guard, observe whether any finding is raised, withdrawn, and re-raised within the loop on real runs.
