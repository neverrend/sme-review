# Scenario: Transient Subagent Error — Retry with Backoff

**Setup:** Paste the contents of `tests/test-sections/well-formed-backend.md` as an assistant turn. This scenario tests the transient-failure retry path defined in `operations.md` § "Failure handling": on a rate-limit, 5xx, or network error, retry up to 2 times with backoff (5s, 15s), with a total wall-clock cap of 30s.

Simulating a transient subagent error requires either: (a) triggering a real API rate limit by invoking the skill while another heavy operation is in flight, or (b) if the skill exposes a debug hook for injecting failures, using that. In the absence of a debug hook, this scenario is exercised opportunistically when a real transient error occurs, and manually verified by reading the retry log output.

**Invocation:** `Get a backend expert review of that section.`

**Expected behavior:**
- If a transient error (HTTP 429, 503, or network timeout) occurs on the first subagent dispatch attempt:
  - The orchestrator logs (to stderr or debug output) `Transient error on attempt 1: <error>. Retrying in 5s.`
  - The orchestrator waits 5 seconds and retries the subagent dispatch.
  - If the second attempt also fails: `Transient error on attempt 2: <error>. Retrying in 15s.`
  - The orchestrator waits 15 seconds and retries.
  - If the third attempt succeeds: the review proceeds normally.
  - If the third attempt also fails: the orchestrator surfaces the error to the user: `SME review failed: <reason>. Retry, or rephrase the invocation.` No further retries.
- The total time spent in retry waits does not exceed 30 seconds (5s + 15s + up to 10s for the third attempt = within the 30s cap).
- Deterministic errors (schema validation failure, persistent auth error) do NOT trigger retries — the skill surfaces the error immediately.

**Anti-patterns (must NOT happen):**
- The skill retries more than 2 times on a transient error — the retry cap is 2 retries (3 total attempts), not more.
- The skill uses a fixed 30-second sleep between retries rather than the 5s/15s exponential backoff — the backoff is explicit in the spec.
- The skill retries on a deterministic error (e.g., the subagent returns a malformed output with a missing required field) — deterministic errors must not be retried with the transient-retry policy.
- The skill exceeds 30 seconds of total wall-clock retry time — the cap must be enforced.
- The skill silently swallows the error after 3 failed attempts and returns an empty or partial output without informing the user.

**Tuning signals:** Log the error type (transient vs. deterministic) and retry count per invocation. If the skill is retrying on deterministic errors, the error-classification logic needs refinement. If the retry interval is not matching the 5s/15s spec, the backoff implementation is incorrect.
