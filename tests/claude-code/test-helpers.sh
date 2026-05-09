#!/usr/bin/env bash
# Test helpers for sme-review claude-code tests.
# Source from each test script:  source "$(dirname "$0")/test-helpers.sh"

set -uo pipefail  # NOT -e; assertions handle their own failure flow.

PASS_COUNT=0
FAIL_COUNT=0

assert_contains() {
  local needle="$1"
  local haystack="$2"
  local label="${3:-assert_contains}"
  if echo "$haystack" | grep -q -- "$needle"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "  [PASS] $label: contains '$needle'"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  [FAIL] $label: missing '$needle'"
    echo "    haystack (first 500 chars): ${haystack:0:500}"
  fi
}

assert_not_contains() {
  local needle="$1"
  local haystack="$2"
  local label="${3:-assert_not_contains}"
  if echo "$haystack" | grep -q -- "$needle"; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  [FAIL] $label: unexpectedly contains '$needle'"
  else
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "  [PASS] $label: does not contain '$needle'"
  fi
}

assert_count_gte() {
  local needle="$1"
  local haystack="$2"
  local min="$3"
  local label="${4:-assert_count_gte}"
  local actual
  actual=$(echo "$haystack" | grep -c -- "$needle" || true)
  if [ "$actual" -ge "$min" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "  [PASS] $label: $actual >= $min occurrences of '$needle'"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  [FAIL] $label: only $actual < $min occurrences of '$needle'"
  fi
}

summarize() {
  echo
  echo "==== Summary ===="
  echo "Pass: $PASS_COUNT"
  echo "Fail: $FAIL_COUNT"
  if [ "$FAIL_COUNT" -gt 0 ]; then exit 1; else exit 0; fi
}

claude_invoke() {
  # Invoke claude with a given prompt; return stdout.
  # Args: $1 = prompt
  local prompt="$1"
  claude -p "$prompt" 2>/dev/null
}
