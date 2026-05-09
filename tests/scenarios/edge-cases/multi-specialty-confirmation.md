# Scenario: Multi-Specialty Confirmation — No Auto-Run-Both

**Setup:** Paste the contents of `tests/test-sections/well-formed-backend.md` as an assistant turn in a fresh Claude Code conversation. No prior state files.

**Invocation:** `Review this section for network security and web-app security concerns.`

**Expected behavior:**
- The orchestrator detects two specialty candidates: `network` and `web-app` (both are curated specialties under the `security` domain).
- The orchestrator emits a single confirmation prompt: `Detected multiple specialty candidates: 'network' and 'web-app'. Run 'network' first and offer 'web-app' after, or pick one?`
- The orchestrator does NOT auto-run both specialties sequentially without user confirmation.
- The orchestrator waits for the user's response before running any review.
- If the user responds `run network first and offer web-app after`, the orchestrator runs the `security/network` review to completion, then asks `Run the web-app security review next?` before starting the second review.
- If the user responds `just run web-app`, the orchestrator runs only the `security/web-app` review without running `security/network`.

**Anti-patterns (must NOT happen):**
- The orchestrator immediately runs both `security/network` and `security/web-app` reviews sequentially without asking for confirmation — auto-running both is explicitly prohibited. The user must confirm the order or choose one.
- The orchestrator emits two separate confirmation prompts (one for each specialty) rather than a single combined prompt.
- The orchestrator picks one specialty silently and ignores the other — it must surface the detection of multiple candidates.
- The orchestrator refuses to proceed at all and says `I couldn't interpret 'network security and web-app security concerns' as a recognized expertise` — both `network` and `web-app` are curated specialties and must be recognized; the issue is multiple candidates, not unrecognized specialties.

**Tuning signals:** Log whether the multi-specialty detection fired and which specialties were identified. If the orchestrator parses `network security and web-app security concerns` as a single unrecognized specialty rather than two curated specialties, the parsing logic needs to be more aggressive about splitting on conjunctions when both halves match curated specialty slugs.
