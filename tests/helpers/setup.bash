#!/usr/bin/env bash
# Common test setup for all Spark bats tests

# Load bats helpers
TEST_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"
load "${TEST_LIB_DIR}/bats-support/load"
load "${TEST_LIB_DIR}/bats-assert/load"

# Project root (the spark plugin repo)
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Scripts under test
SETUP_SCRIPT="${PLUGIN_ROOT}/scripts/setup-spark.sh"
STOP_HOOK="${PLUGIN_ROOT}/hooks/stop-hook.sh"

# Create isolated test directory (each test gets its own)
setup_test_dir() {
  TEST_DIR="$(mktemp -d "${BATS_TEST_TMPDIR}/spark-test.XXXXXX")"
  mkdir -p "${TEST_DIR}/.claude"
}

# Teardown — cleanup is automatic via BATS_TEST_TMPDIR
teardown_test_dir() {
  if [[ -n "${TEST_DIR:-}" ]] && [[ -d "$TEST_DIR" ]]; then
    rm -rf "$TEST_DIR"
  fi
}

# Standard setup/teardown hooks
setup() {
  setup_test_dir
}

teardown() {
  teardown_test_dir
}

# Helper: read a frontmatter field from a state file
# Usage: get_frontmatter "field_name" "/path/to/state.md"
get_frontmatter() {
  local field="$1"
  local file="$2"
  awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$file" \
    | { grep "^${field}:" || true; } \
    | sed "s/^${field}: *//" \
    | sed 's/^"\(.*\)"$/\1/' \
    | awk '{
        gsub(/\\\\/, "\x01")
        gsub(/\\"/, "\"")
        gsub(/\\n/, "\n")
        gsub(/\\t/, "\t")
        gsub(/\\r/, "\r")
        gsub(/\x01/, "\\")
        printf "%s", $0
      }' \
    | tr -d '\r'
}

# Helper: get the state file path for a test dir
state_file() {
  echo "${TEST_DIR}/.claude/spark-state.local.md"
}

# Helper: get the result file path for a test dir
result_file() {
  echo "${TEST_DIR}/.claude/spark-result.local.md"
}
