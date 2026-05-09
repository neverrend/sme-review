# Scenario: Infinite Disagreement Cycle (Reviewer vs. Expert)

**Setup:** Paste the contents of `tests/test-sections/tangled-no-converge.md` as an assistant turn. No prior state files. This scenario differs from `loop-behavior/hard-ceiling.md` in focus: while that scenario tests that the hard ceiling fires at round 6 on a tangled section, this scenario tests the specific case where the main agent and the expert are locked in an unresolvable cycle on a single finding — the expert defends its position in every round, the main agent challenges it in every round, and neither side produces new reasoning beyond round 2. The cycle must be broken by the hard ceiling, not by one side capitulating.

**Invocation:** `Get a distributed-systems expert review of that section, focusing on the consistency model for stock reservation.`

**Expected behavior:**
- The skill runs all 6 rounds without converging.
- After round 4 (when the soft cap is exceeded), heightened-scrutiny mode activates: the round-5 pushback must be the strongest available challenge on the contested finding, not a repeat of earlier challenges.
- The `#### Disputed findings` block in the final output contains at least one entry with both `Expert position:` and `Reviewer position:` subsections, each with distinct substantive reasoning (not paraphrases of each other).
- The `#### Disputed findings` entry ends with `User adjudication needed.`
- The state file has `convergence-status: hard-ceiling`.
- The output convergence line reads `6 rounds (hard ceiling). <M> findings unresolved.`

**Anti-patterns (must NOT happen):**
- One side capitulates without new reasoning in round 5 or 6 — this would produce a `converged` result, but the convergence would be false because no new evidence was introduced; one side simply stopped responding. The hard ceiling should terminate before this happens, but if it doesn't, the final output must flag the unresolved disagreement.
- The expert's round-5 or round-6 position is identical (verbatim or near-verbatim) to its round-2 position with no new domain-specific evidence added — the heightened-scrutiny mode should have forced stronger challenges in rounds 5 and 6, prompting new reasoning from the expert. A verbatim repeat indicates the heightened-scrutiny mode did not fire.
- The `#### Disputed findings` block is absent in a hard-ceiling run — hard-ceiling by definition means at least one finding was not resolved; if no disputed findings are surfaced, the output template is not being applied correctly to the hard-ceiling case.

**Tuning signals:** Log the round-count at which the fixed-point test first returns "restate prior" (indicating the cycle began). If the cycle starts at round 2, the section is well-calibrated for this test. If the fixed-point test never returns "restate prior" and the hard ceiling is hit anyway, investigate whether the convergence test is being applied correctly.
