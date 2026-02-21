#!/usr/bin/env bats
# Tests for setup-spark.sh validation logic

load "../helpers/setup"

# Helper to run setup in isolated dir
run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

@test "missing topic produces error" {
  run_setup
  assert_failure
  assert_output --partial "No topic provided"
}

@test "invalid rounds (0) produces error" {
  run_setup --rounds 0 "Test topic"
  assert_failure
  assert_output --partial "--rounds must be between 1 and 3"
}

@test "invalid rounds (4) produces error" {
  run_setup --rounds 4 "Test topic"
  assert_failure
  assert_output --partial "--rounds must be between 1 and 3"
}

@test "invalid rounds (non-numeric) produces error" {
  run_setup --rounds abc "Test topic"
  assert_failure
  assert_output --partial "--rounds must be a positive integer"
}

@test "invalid persona name produces error" {
  run_setup --personas "nonexistent-persona" "Test topic"
  assert_failure
  assert_output --partial "Unknown persona"
}

@test "empty custom persona description produces error" {
  run_setup --personas "custom:" "Test topic"
  assert_failure
  assert_output --partial "custom persona requires a description"
}

@test "missing context path produces error" {
  run_setup --context "/nonexistent/path" "Test topic"
  assert_failure
  assert_output --partial "Context path not found"
}

@test "missing --rounds value produces error" {
  run_setup --rounds
  assert_failure
  assert_output --partial "--rounds requires a number"
}

@test "missing --personas value produces error" {
  run_setup --personas
  assert_failure
  assert_output --partial "--personas requires a value"
}

@test "missing --focus value produces error" {
  run_setup --focus
  assert_failure
  assert_output --partial "--focus requires a value"
}

@test "missing --context value produces error" {
  run_setup --context
  assert_failure
  assert_output --partial "--context requires a path"
}

@test "missing --output value produces error" {
  run_setup --output
  assert_failure
  assert_output --partial "--output requires a file path"
}

@test "active session produces error" {
  mkdir -p "$TEST_DIR/.claude"
  touch "$TEST_DIR/.claude/spark-state.local.md"

  run_setup "Test topic"
  assert_failure
  assert_output --partial "already active"
}

@test "persona with pipe character produces error" {
  run_setup --personas "bad|name" "Test topic"
  assert_failure
  assert_output --partial "cannot contain '|'"
}

load "../helpers/assertions"
