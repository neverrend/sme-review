#!/usr/bin/env bash
# Verify output template structure (heading hierarchy, severity labels, frontmatter, hand-off).

source "$(dirname "$0")/test-helpers.sh"

echo "=== Output format structure ==="

# Use a known-flawed section so the loop produces real findings.
R=$(claude_invoke "Section: 'OAuth with no refresh tokens, no rate limiting, no logging'. Do a security SME review.")

assert_contains "### SME Review:" "$R" "format: H3 heading present"
assert_not_contains "^# SME Review" "$R" "format: no H1 (heading demoted to H3)"

assert_contains "Reviewed as" "$R" "format: preamble line"
assert_contains "Rounds:" "$R" "format: rounds line"

# At least one severity tier should appear for a known-flawed section.
assert_count_gte "\[Critical\]\|\[High\]\|\[Medium\]\|\[Minor\]" "$R" 1 "format: ≥1 severity-labeled finding"

assert_contains "verified by:" "$R" "format: validated assumptions block uses 'verified by:'"

# Hand-off line present (one of the three variants).
assert_count_gte "Adopt as the new version\|Adjudicate disputes\|No substantive changes" "$R" 1 "format: hand-off line variant present"

summarize
