#!/usr/bin/env bats
# Tests for setup-spark.sh state file creation

load "../helpers/setup"
load "../helpers/assertions"

# Helper to run setup in isolated dir
run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

@test "state file is created at correct path" {
  run_setup --personas "theater-director,urban-planner,architect" "Test topic"
  assert_success
  assert_state_exists
}

@test "state file has all required frontmatter fields" {
  run_setup --personas "theater-director,urban-planner,architect" --rounds 2 --interactive --focus "testing" "My topic"
  assert_success

  local sf
  sf=$(state_file)
  assert_frontmatter "active" "true" "$sf"
  assert_frontmatter "question" "My topic" "$sf"
  assert_frontmatter "phase" "seed" "$sf"
  assert_frontmatter "persona_index" "0" "$sf"
  assert_frontmatter "round" "1" "$sf"
  assert_frontmatter "max_rounds" "2" "$sf"
  assert_frontmatter "personas" "theater-director|urban-planner|architect" "$sf"
  assert_frontmatter "interactive" "true" "$sf"
  assert_frontmatter "interactive_level" "checkpoint" "$sf"
  assert_frontmatter "focus" "testing" "$sf"
}

@test "persona descriptions are stored in state file body" {
  run_setup --personas "theater-director,urban-planner,architect" "Test topic"
  assert_success

  assert_state_body_contains "<!-- persona:theater-director -->"
  assert_state_body_contains "<!-- persona:urban-planner -->"
  assert_state_body_contains "<!-- persona:architect -->"
  assert_state_body_contains "<!-- /persona -->"
}

@test "custom persona descriptions are stored in state file body" {
  run_setup --personas "custom:A Buddhist monk who codes" "Test topic"
  assert_success

  assert_state_body_contains "<!-- persona:custom:A Buddhist monk who codes -->"
  assert_state_body_contains "A Buddhist monk who codes"
}

@test "started_at timestamp is set" {
  run_setup --personas "theater-director,urban-planner,architect" "Test topic"
  assert_success

  local started
  started=$(get_frontmatter "started_at" "$(state_file)")
  # Should match ISO 8601 format
  [[ "$started" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "default output path is generated" {
  run_setup --personas "theater-director,urban-planner,architect" "Test topic"
  assert_success

  local output_val
  output_val=$(get_frontmatter "output" "$(state_file)")
  [[ "$output_val" == *"spark-"* ]]
  [[ "$output_val" == *".html" ]]
}

@test "question with special characters is YAML-escaped" {
  run_setup --personas "theater-director,urban-planner,architect" 'How do we handle "quotes" and tabs?'
  assert_success

  assert_frontmatter "question" 'How do we handle "quotes" and tabs?' "$(state_file)"
}
