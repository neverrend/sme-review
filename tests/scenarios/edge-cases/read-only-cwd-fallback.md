# Scenario: Read-Only CWD — State Path Falls Back to Home Dir

**Setup:** In a terminal, create a temporary project directory, make it read-only, then start Claude Code from within it:
```sh
TESTDIR=$(mktemp -d /tmp/sme-review-ro-test-XXXXXX)
mkdir -p "$TESTDIR/.git"   # makes it project-local per is_project_local()
touch "$TESTDIR/.git/HEAD"
chmod -R a-w "$TESTDIR"    # remove all write permissions
cd "$TESTDIR"
# Start Claude Code from this read-only cwd
```
Paste the contents of `tests/test-sections/well-formed-backend.md` as an assistant turn. Confirm `~/.claude/sme-reviews/` is writable (or does not exist but `~/.claude/` is writable).

**Invocation:** `Get a backend expert review of that section.`

**Expected behavior:**
- The orchestrator calls `resolve_state_path(cwd)`: the write-probe at `<cwd>/.claude/sme-reviews/.write-probe-<random>` fails because cwd is not writable. `can_write(primary)` returns false.
- The orchestrator falls back to `home_state` (`~/.claude/sme-reviews/...`). `can_write(home_state)` returns true.
- The output preamble includes the fallback notice: `_Project state dir not writable; falling back to ~/.claude/sme-reviews._`
- The full review runs normally and completes.
- The state file is written to `~/.claude/sme-reviews/order-ingestion-service/backend/backend.md` (not in the cwd).

**Cleanup:** `chmod -R u+w "$TESTDIR" && rm -rf "$TESTDIR"`. Also remove `~/.claude/sme-reviews/order-ingestion-service/` if you want a clean state for subsequent tests.

**Anti-patterns (must NOT happen):**
- The orchestrator fails with a permissions error without attempting the fallback — the fallback to home dir must be attempted before surfacing any error to the user.
- The orchestrator uses `os.access()` or equivalent instead of the write-probe pattern (`create+delete a probe file`). `os.access()` can be fooled by ACLs; only the write-probe pattern is reliable.
- The fallback notice is absent from the output preamble — users must be informed that state is being persisted in a non-project location.
- The state file is written to the cwd anyway, silently creating `.claude/` inside the read-only directory, which would fail at the OS level and is not the expected behavior.

**Tuning signals:** Log which state path was resolved (`primary` or `fallback`) per invocation. If the primary path is unexpectedly unwritable in normal usage, the write-probe pattern may be too aggressive in triggering the fallback.
