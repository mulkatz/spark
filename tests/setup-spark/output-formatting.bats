#!/usr/bin/env bats
# Tests for setup-spark.sh output formatting (banner + initial prompt)

load "../helpers/setup"
load "../helpers/assertions"

# Helper to run setup in isolated dir
run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

@test "banner shows topic" {
  run_setup --personas "theater-director,urban-planner,architect" "How to improve remote work?"
  assert_success
  assert_output --partial "How to improve remote work?"
}

@test "banner shows SPARK header" {
  run_setup --personas "theater-director,urban-planner,architect" "Test topic"
  assert_success
  assert_output --partial "SPARK"
}

@test "banner shows persona names" {
  run_setup --personas "theater-director,urban-planner,architect" "Test topic"
  assert_success
  assert_output --partial "theater-director"
  assert_output --partial "urban-planner"
  assert_output --partial "architect"
}

@test "banner shows round count" {
  run_setup --personas "theater-director,urban-planner,architect" --rounds 2 "Test topic"
  assert_success
  assert_output --partial "Rounds:"
  assert_output --partial "2"
}

@test "banner shows focus when set" {
  run_setup --personas "theater-director,urban-planner,architect" --focus "user experience" "Test topic"
  assert_success
  assert_output --partial "Focus:"
  assert_output --partial "user experience"
}

@test "banner shows interactive when enabled" {
  run_setup --personas "theater-director,urban-planner,architect" --interactive "Test topic"
  assert_success
  assert_output --partial "Interactive:"
  assert_output --partial "ENABLED"
}

@test "initial prompt contains seed phase instructions" {
  run_setup --personas "theater-director,urban-planner,architect" "Test topic"
  assert_success
  assert_output --partial "Seed Phase"
  assert_output --partial "independently"
}

@test "initial prompt contains first persona description" {
  run_setup --personas "theater-director,urban-planner,architect" "Test topic"
  assert_success
  assert_output --partial "theater-director"
  assert_output --partial "Persona: theater-director"
}

@test "initial prompt contains a constraint" {
  run_setup --personas "theater-director,urban-planner,architect" "Test topic"
  assert_success
  # The constraint replaces [INJECT_CONSTRAINT] — should not appear literally
  refute_output --partial "[INJECT_CONSTRAINT]"
  # Should contain "What if" (all constraints start with this)
  assert_output --partial "What if"
}

@test "initial prompt contains topic" {
  run_setup --personas "theater-director,urban-planner,architect" "How to make APIs fun?"
  assert_success
  assert_output --partial "How to make APIs fun?"
}

@test "phase flow diagram is shown" {
  run_setup --personas "theater-director,urban-planner,architect" "Test topic"
  assert_success
  assert_output --partial "Seed"
  assert_output --partial "Cross-Pollinate"
  assert_output --partial "Synthesize"
}
