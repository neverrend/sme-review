#!/usr/bin/env bash
# Verify (domain, specialty) parsing routes to the right persona file.

source "$(dirname "$0")/test-helpers.sh"

echo "=== Persona dispatch ==="

R1=$(claude_invoke "Section: 'Use Postgres for orders'. Get a backend expert review.")
assert_contains "Reviewed as backend expert" "$R1" "dispatch: backend, no specialty → general persona"

R2=$(claude_invoke "Section: 'Use Postgres for orders'. Get a Postgres-perf backend review.")
assert_contains "Reviewed as backend expert specializing in postgres-perf" "$R2" "dispatch: backend + postgres-perf specialty"

R3=$(claude_invoke "Section: 'TLS 1.3 with mutual auth'. Get a network security expert.")
assert_contains "Reviewed as security expert specializing in network" "$R3" "dispatch: security + network specialty"

R4=$(claude_invoke "Section: 'OAuth with refresh tokens'. Do a SOC analyst review.")
assert_not_contains "UNKNOWN_SPECIALTY" "$R4" "dispatch: SOC analyst → freeform path, recognized"
assert_contains "specializing in soc-analyst" "$R4" "dispatch: freeform substitutes specialty slug"

summarize
