# Test runbook

## Deterministic tests (`claude-code/`)

```sh
cd "$(git rev-parse --show-toplevel)/sme-review/tests/claude-code"
for t in test-*.sh; do
  echo "=== $t ==="
  ./"$t"
done
```

Each script: plants a known-signal section, invokes the skill via `claude -p`, asserts on grep-able output. Pass/fail summary printed at end. Exit 0 on all-pass, 1 on any fail.

**Prerequisite:** skill must be installed (`./install.sh`) before running.

## Manual QA scenarios (`scenarios/`)

These are LLM-output non-deterministic. Walk through each one by hand:

1. **Loop behavior** (`scenarios/loop-behavior/`): verify normal convergence happens within soft cap.
2. **Convergence pathologies** (`scenarios/convergence-pathologies/`): verify the anti-sycophancy force, severity calibration, anti-oscillation guard, and hard-ceiling unresolved-disagreement output.
3. **State persistence** (`scenarios/state-persistence/`): verify cache-hit/miss, cross-specialty priors, force re-review.
4. **Extraction** (`scenarios/extraction/`): verify unambiguous / ambiguous-confirmation / no-section-refusal flows.
5. **Edge cases** (`scenarios/edge-cases/`): verify multi-specialty confirmation, state write failure user-choice, retry policy.

For each scenario: read Setup → run the Invocation → check Expected behaviors → confirm none of the Anti-patterns occurred. Note observations in a scratch log; promote real bugs to GitHub issues.

## Cap tuning

See `../CONTRIBUTING.md` → "Cap tuning."
