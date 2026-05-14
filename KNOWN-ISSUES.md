# Known issues — v0.1

## Deterministic test harness gaps

The bash test scripts in `tests/claude-code/` exercise skill behavior via `claude -p` (headless), but two issues prevent the harness from running cleanly end-to-end:

### 1. Test fixtures use one-liner sections; skill correctly refuses them

The test scripts pass thin section descriptions like *"Section: 'Use Postgres for orders'"* into the invocation. The skill correctly classifies these as un-articulated and refuses per its "no design section in recent context" path. The tests expected `"Reviewed as"` in the output, but the skill (correctly) did not dispatch a review.

**Fix (v0.2):** rewrite tests to inline real design content from `tests/test-sections/*.md`:

```sh
SECTION=$(cat "$(dirname "$0")/../test-sections/well-formed-backend.md")
POS1=$(claude_invoke "Here's a design section:

$SECTION

Get a backend expert review of it.")
```

### 2. Headless `claude -p` cannot grant permissions to read skill reference files

When the skill's main agent attempts to read `operations.md`, `output-template.md`, or `experts/<domain>.md` from `~/.claude/skills/sme-review/`, headless mode surfaces permission prompts that cannot be approved non-interactively, blocking the loop.

**Fix (v0.2):** test harness needs to invoke `claude -p` with a permission flag that pre-grants reads to the skill directory. Investigate `--permission-mode acceptEdits`, `--allowed-tools Read`, or whichever mechanism Claude Code exposes for this. May also be solvable by running tests in a Claude Code wrapper that inherits the user's permission state.

## 3. Expert subagents on Sonnet/Haiku hallucinate "kept" bullets in round-2+ consolidated lists

When an expert subagent is asked to produce a consolidated final bullet list (round 2 of pushback, after the main agent surfaces volume-cap or restructuring challenges), Sonnet- and Haiku-backed experts can label fabricated bullets as **"kept"** from the original draft — silently regressing on prior commitments.

**Documented incident:** 2026-05-13, skill-design persona Batch-3 review (agent-systems expert, sonnet model). Round 2 final list included bullets like "Implicit version coupling between caller skill and callee skill" and "Error propagation policy unspecified" tagged as **kept**, but neither was in the original draft. The expert also silently dropped termination, cost ceilings, and cycles from Specialty 1 despite committing to deliver those in their Batch-2 review. The orchestrator (main agent) caught this during reconciliation, but only because of explicit cross-checking against the prior commitments — the pushback rubric did not flag it.

**Mitigations applied in v0.2:**
- Added bullet-tracking rule to Universal rules block (`operations.md` → Universal rules): "each kept item MUST be quoted from the original draft; do not fabricate."
- Added rubric item 5 to the Pushback rubric: "Bullet-tracking against draft" — main agent spot-checks `kept` labels by quoting back.
- Added model requirement to Universal rules block: experts MUST run on Opus or the most capable model available.

**Open question (v0.3):** does the spot-check rubric item suffice, or should there be a structural diff between the draft and the expert's "kept" claims? Hard to automate inside a markdown debate loop.

## What this means for v0.1

- The **skill itself works** in interactive Claude Code sessions where the user can approve permission prompts. Verified: persona dispatch routes correctly (`Reviewed as backend expert specializing in postgres-perf` observed from headless harness for one test that bypassed the permission issue).
- The **deterministic test harness does not currently produce a clean pass result.** Manual QA scenarios (`tests/scenarios/`) are the v0.1 verification path.
- The **manual integration smoketest** (Task 37 Steps 3-5 in the implementation plan) is the canonical end-to-end verification for v0.1.

## Validation status at v0.1 ship

Verified:

- ✅ Personal-skills loader auto-discovers `~/.claude/skills/sme-review/` (Task 1 smoketest passed: `LOADER_OK_<token>`).
- ✅ install.sh (copy mode default, --force, idempotent symlink check, iCloud guard, writability probe).
- ✅ Skill core files (SKILL.md, operations.md 11 sections, output-template.md).
- ✅ 13 curated personas + freeform template + experts/README.md.
- ✅ User-facing README, contributor CONTRIBUTING.md.
- ✅ 5 test-section fixtures, 19 manual scenarios, runbook.

Pending (defer to v0.2):

- ⏳ Deterministic test harness running cleanly end-to-end (issues 1 and 2 above).
- ⏳ Manual integration smoketest (Task 37 Steps 3-5) — user-side, in interactive session.
