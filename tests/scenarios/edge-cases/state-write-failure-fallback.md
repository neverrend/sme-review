# Scenario: Both State Paths Unwritable — User Choice Required

**Setup:** Make both the project-local state directory and the home state directory unwritable:
```sh
TESTDIR=$(mktemp -d /tmp/sme-review-nowrite-test-XXXXXX)
mkdir -p "$TESTDIR/.git"
touch "$TESTDIR/.git/HEAD"
chmod -R a-w "$TESTDIR"   # cwd not writable

# Block the home fallback by making ~/.claude/ not writable
# WARNING: restore permissions immediately after the test.
chmod a-w ~/.claude
cd "$TESTDIR"
# Start Claude Code from this cwd
```
Paste the contents of `tests/test-sections/well-formed-backend.md` as an assistant turn.

**Invocation:** `Get a backend expert review of that section.`

**Expected behavior:**
- The orchestrator calls `resolve_state_path(cwd)`: both `can_write(primary)` and `can_write(home_state)` return false (`resolve_state_path` returns `null, abort=true`).
- The orchestrator surfaces a choice to the user: `State persistence unavailable in both project and home dirs. Continue without persistence (cross-invocation continuity disabled), or abort?`
- The orchestrator waits for explicit user input before proceeding.
- If the user responds `continue` or equivalent, the review runs without writing any state file. The output preamble notes that persistence is disabled.
- If the user responds `abort`, the review does not run and the skill exits cleanly.
- In neither case does the skill silently degrade — it must always present the choice.

**Cleanup:** `chmod u+w ~/.claude && chmod -R u+w "$TESTDIR" && rm -rf "$TESTDIR"`

**Anti-patterns (must NOT happen):**
- The skill silently runs the review without persisting state and without informing the user — silent degradation prevents users from knowing that cross-invocation continuity is disabled.
- The skill crashes with an unhandled permissions error rather than catching the write failure and surfacing the user choice.
- The skill writes state to a third location not specified in the spec (e.g., `/tmp/`) without user consent — the two approved locations are `<cwd>/.claude/sme-reviews/` and `~/.claude/sme-reviews/` only.
- The skill aborts without offering the `continue without persistence` option — the user should be able to get a review even if state cannot be saved.

**Tuning signals:** n/a — this is a deterministic guard test. The user-choice prompt either appears or it doesn't. Verify the exact wording matches the spec.
