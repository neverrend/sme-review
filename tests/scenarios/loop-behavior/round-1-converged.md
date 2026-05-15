# Scenario: Round-1 Converged

**Setup:** Paste the contents of `tests/test-sections/well-formed-trivial-no-findings.md` as an assistant turn in a fresh Claude Code conversation. No prior state files exist for this section under `~/.claude/sme-reviews/`.

**Invocation:** `Get a backend expert review of that section.`

**Expected behavior:**
- The orchestrator emits a one-line preview before proceeding: `Reviewing: "String Lowercasing Function..."` (or equivalent first-80-chars preview of the section heading and opening).
- The output header reads `Reviewed as backend expert` with `Rounds: 1 of 6 — converged`.
- The output contains a `#### Validated assumptions` block with at least 3 entries, each with a `verified by:` line that follows one of the 5 valid evidence shapes (file path with line range, executable check, calculation with numbers, threat scenario with concrete attacker and consequence, or external citation with link).
- There is no `#### Findings` block (or the block is explicitly empty / absent), because the round-1 zero-challenge path terminated without substantive findings.
- The hand-off line reads `No substantive changes. Continue?`
- A state file is written at `~/.claude/sme-reviews/string-lowercasing-function/backend/<specialty>.md` (or `backend.md` if no specialty was named) with `convergence-status: converged` and `round-count: 1`. A transcripts sidecar is written at the sibling path `<specialty>.transcripts.md`.

**Anti-patterns (must NOT happen):**
- The skill runs more than 1 round (round count in the output header is > 1). This would mean the round-1 zero-challenge path did not fire, suggesting the expert found spurious issues in a trivially correct section.
- The output shows a `[Critical]`, `[High]`, `[Medium]`, or `[Minor]` finding block with substantive content. False positives from a correct section undermine trust in the skill.
- The `#### Validated assumptions` block contains fewer than 3 entries, or any entry has `verified by: domain expertise` or another hand-wave instead of one of the 5 valid evidence shapes.
- The output header says `Unusually thin review` — this warning should NOT appear unless the ≥3-validated-assumption requirement genuinely could not be met. A well-formed trivial section should satisfy it.
- No state file is written (stateless run without an error or user choice).

**Tuning signals:** Log round-count per invocation. If this fixture ever produces round-count > 1 in repeated runs, the convergence test or the anti-bias instruction may be too aggressive on obviously-correct content — investigate whether the main agent is manufacturing challenges.
