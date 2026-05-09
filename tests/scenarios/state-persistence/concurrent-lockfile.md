# Scenario: Concurrent Lockfile — Second Invocation Refused

**Setup:** In a fresh Claude Code conversation with cwd set to a project directory (containing `.git` or `package.json`):
1. Paste the contents of `tests/test-sections/well-formed-backend.md` as an assistant turn.
2. Determine the expected lockfile path for this section: `<cwd>/.claude/sme-reviews/order-ingestion-service/backend/.backend.lock` (substitute the correct section slug and specialty slug).
3. Manually create the lockfile at that path before running the invocation:
   ```sh
   mkdir -p "<cwd>/.claude/sme-reviews/order-ingestion-service/backend"
   echo "pid=99999 started=$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "<cwd>/.claude/sme-reviews/order-ingestion-service/backend/.backend.lock"
   ```
   The PID `99999` is chosen to be non-existent on any normal system. The timestamp must be within the last 30 minutes (use `date` to generate a recent timestamp) so the stale-lock sweep does not remove it.
4. Run the invocation below.

**Invocation:** `Get a backend expert review of that section.`

**Expected behavior:**
- The orchestrator detects the lockfile at the expected path before attempting `O_CREAT|O_EXCL` acquisition.
- The orchestrator refuses with the exact message: `Another SME review on this specialty is in progress; retry in a moment, or override with 'force re-review'.`
- No debate loop rounds are run.
- No state file is written or overwritten.
- The existing lockfile is left untouched (the stale-sweep must not remove it because the timestamp is recent, i.e., within 30 minutes).

**Cleanup:** After verifying the refusal, remove the manually-created lockfile: `rm "<cwd>/.claude/sme-reviews/order-ingestion-service/backend/.backend.lock"`. Then run the invocation again to confirm it succeeds normally.

**Anti-patterns (must NOT happen):**
- The skill proceeds with the debate loop despite the lockfile being present — the lock acquisition did not use `O_CREAT|O_EXCL` semantics, or the lockfile check was skipped. This is a lost-update hazard: two concurrent invocations could both write to the state file, corrupting it.
- The skill removes the lockfile (treating it as stale) when the lockfile's timestamp is recent (within 30 minutes) — the stale-sweep threshold must be 30 minutes, not a shorter interval.
- The refusal message does not include the `force re-review` discoverability prompt — users must know how to override the lock.
- The skill returns a generic error message rather than the specific lockfile-collision message.

**Tuning signals:** n/a — this is a deterministic guard test. Either the refusal fires with the correct message or it doesn't.
