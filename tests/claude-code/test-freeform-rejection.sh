#!/usr/bin/env bash
# Verify the recognition gate refuses nonsense specialties.

source "$(dirname "$0")/test-helpers.sh"

echo "=== Freeform recognition gate ==="

R1=$(claude_invoke "Section: 'Use Postgres for orders'. Do a fnord review.")
assert_contains "couldn't interpret" "$R1" "rejection: fnord refused at orchestrator"
assert_not_contains "Reviewed as fnord expert" "$R1" "rejection: skill did not run with fnord persona"

R2=$(claude_invoke "Section: 'Use Postgres for orders'. Do a 'how the moon affects backends' review.")
assert_contains "couldn't interpret" "$R2" "rejection: nonsense specialty refused"

# Edge: a real but obscure specialty should be accepted (recognition check passes).
R3=$(claude_invoke "Section: 'Use Postgres for orders'. Get a SOC analyst review.")
assert_not_contains "couldn't interpret" "$R3" "acceptance: SOC analyst is recognized"

summarize
