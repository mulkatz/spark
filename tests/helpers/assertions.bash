#!/usr/bin/env bash
# Custom assertions for Spark tests

# Assert a frontmatter field has the expected value
# Usage: assert_frontmatter "field" "expected_value" ["/path/to/file"]
assert_frontmatter() {
  local field="$1"
  local expected="$2"
  local file="${3:-$(state_file)}"

  local actual
  actual=$(get_frontmatter "$field" "$file")

  if [[ "$actual" != "$expected" ]]; then
    echo "Frontmatter assertion failed for '$field':" >&2
    echo "  expected: '$expected'" >&2
    echo "  actual:   '$actual'" >&2
    return 1
  fi
}

# Assert the stop hook output is a valid block decision JSON
# Usage: assert_block_decision
assert_block_decision() {
  assert_success
  local decision
  decision=$(printf '%s' "$output" | jq -r '.decision' 2>/dev/null)
  if [[ "$decision" != "block" ]]; then
    echo "Expected block decision, got: $output" >&2
    return 1
  fi
}

# Assert the stop hook output contains a specific string in the reason field
# Usage: assert_reason_contains "expected substring"
assert_reason_contains() {
  local expected="$1"
  local reason
  reason=$(printf '%s' "$output" | jq -r '.reason' 2>/dev/null)
  if ! printf '%s' "$reason" | grep -qF "$expected"; then
    echo "Expected reason to contain: '$expected'" >&2
    echo "Actual reason: '$reason'" >&2
    return 1
  fi
}

# Assert the stop hook output contains a specific system message
# Usage: assert_system_message_contains "expected substring"
assert_system_message_contains() {
  local expected="$1"
  local msg
  msg=$(printf '%s' "$output" | jq -r '.systemMessage' 2>/dev/null)
  if ! printf '%s' "$msg" | grep -qF "$expected"; then
    echo "Expected systemMessage to contain: '$expected'" >&2
    echo "Actual systemMessage: '$msg'" >&2
    return 1
  fi
}

# Assert state file exists
assert_state_exists() {
  local file
  file=$(state_file)
  if [[ ! -f "$file" ]]; then
    echo "Expected state file to exist: $file" >&2
    return 1
  fi
}

# Assert state file does NOT exist (cleaned up)
assert_state_cleaned() {
  local file
  file=$(state_file)
  if [[ -f "$file" ]]; then
    echo "Expected state file to be cleaned up: $file" >&2
    return 1
  fi
}

# Assert result file exists
assert_result_exists() {
  local file
  file=$(result_file)
  if [[ ! -f "$file" ]]; then
    echo "Expected result file to exist: $file" >&2
    return 1
  fi
}

# Assert result file contains expected text
assert_result_contains() {
  local expected="$1"
  local file
  file=$(result_file)
  if ! grep -qF "$expected" "$file"; then
    echo "Expected result file to contain: '$expected'" >&2
    return 1
  fi
}

# Assert state file body contains expected text
assert_state_body_contains() {
  local expected="$1"
  local file
  file=$(state_file)
  local body
  body=$(awk '/^---$/{i++; next} i>=2' "$file")
  if ! printf '%s' "$body" | grep -qF "$expected"; then
    echo "Expected state body to contain: '$expected'" >&2
    echo "Actual body: '$body'" >&2
    return 1
  fi
}

# Assert stderr contains expected text
assert_stderr_contains() {
  local expected="$1"
  if ! printf '%s' "$stderr" | grep -qF "$expected" 2>/dev/null; then
    if ! printf '%s' "$output" | grep -qF "$expected" 2>/dev/null; then
      echo "Expected stderr to contain: '$expected'" >&2
      return 1
    fi
  fi
}
