# Scenario: Severity Inflation Pushback

**Setup:** Paste the contents of `tests/test-sections/well-formed-backend.md` as an assistant turn. No prior state files. This scenario verifies that pushback rubric item 3 (severity calibration — "not everything is Critical") fires when the expert over-inflates severity labels. The section is well-formed and does not contain Critical-severity flaws; if the expert returns multiple Critical findings, the main agent must challenge severity calibration in the next round.

**Invocation:** `Get a backend expert review of that section.`

**Expected behavior:**
- If round-1 output contains two or more `[Critical]` findings on the `well-formed-backend.md` section (which has no critical flaws), the round-2 pushback issued by the main agent explicitly challenges severity calibration, naming the specific findings whose severity appears overstated and citing the universal rule: Critical is reserved for designs that are unimplementable or unsafe.
- The round-2 (or later) expert response either (a) downgrades inflated findings from Critical to High or Medium with reasoning, or (b) defends the Critical rating with a concrete threat scenario (attacker + vector + consequence). Both outcomes are acceptable.
- The final output severity distribution on this section should contain zero or one Critical findings (the outbox pattern has no critical flaws; the Redis failover path has no critical flaws; the Postgres schema has no critical flaws).

**Anti-patterns (must NOT happen):**
- The main agent accepts multiple Critical findings on this section without any severity-calibration pushback. Unchallenged severity inflation would cause users to treat every finding as urgent regardless of actual impact.
- The main agent challenges severity on every single finding regardless of whether severity is inflated — this is over-correction. Severity calibration pushback should be finding-specific, not a blanket "you're inflating everything" accusation.
- A finding is downgraded from Critical to Minor in a single round without the intermediate High or Medium step — the rubric challenges severity calibration, not severity accuracy to the nearest tier.

**Tuning signals:** Log severity distribution (count per tier) per round. If Critical count decreases from round 1 to round 2 after a severity-calibration challenge, the guard is working. If Critical count stays unchanged across rounds, either the challenge was not issued or the expert is correctly defending the Critical rating with a concrete threat scenario — read the round-2 output to distinguish.
