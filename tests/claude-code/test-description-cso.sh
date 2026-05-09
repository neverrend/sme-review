#!/usr/bin/env bash
# Verify the sme-review skill's description triggers correctly.
# Requires: skill installed at ~/.claude/skills/sme-review

source "$(dirname "$0")/test-helpers.sh"

echo "=== Positive cases (skill SHOULD load) ==="

POS1=$(claude_invoke "Earlier I outlined this design section: 'Use Postgres for orders'. Get a backend expert review of it.")
assert_contains "Reviewed as" "$POS1" "positive: backend expert request loads skill"

POS2=$(claude_invoke "Here's my proposed auth design: 'OAuth with refresh tokens'. Have a security SME critique it.")
assert_contains "Reviewed as" "$POS2" "positive: security SME critique loads skill"

POS3=$(claude_invoke "I drafted this k8s topology. Get a staff-level review of it.")
assert_contains "Reviewed as" "$POS3" "positive: staff-level review on k8s topology loads skill"

echo "=== Negative cases (skill should NOT load) ==="

NEG1=$(claude_invoke "Review my code changes in this PR.")
assert_not_contains "Reviewed as" "$NEG1" "negative: PR code review does not load sme-review"

NEG2=$(claude_invoke "Help me think through what to build.")
assert_not_contains "Reviewed as" "$NEG2" "negative: brainstorming request does not load sme-review"

NEG3=$(claude_invoke "Look for security bugs in this implementation.")
assert_not_contains "Reviewed as" "$NEG3" "negative: post-implementation review does not load sme-review"

summarize
