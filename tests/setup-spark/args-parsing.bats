#!/usr/bin/env bats
# Tests for setup-spark.sh argument parsing

load "../helpers/setup"

# Helper to run setup in isolated dir
run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

@test "defaults: 1 round, auto-selected personas, non-interactive" {
  run_setup "Test topic"
  assert_success

  local sf
  sf=$(state_file)
  assert_frontmatter "max_rounds" "1" "$sf"
  assert_frontmatter "interactive" "false" "$sf"
  assert_frontmatter "phase" "seed" "$sf"
  assert_frontmatter "persona_index" "0" "$sf"
}

@test "explicit --rounds value is stored" {
  run_setup --rounds 2 "Test topic"
  assert_success

  assert_frontmatter "max_rounds" "2" "$(state_file)"
}

@test "explicit --personas value is stored" {
  run_setup --personas "theater-director,urban-planner,architect" "Test topic"
  assert_success

  assert_frontmatter "personas" "theater-director|urban-planner|architect" "$(state_file)"
}

@test "multi-word topic is captured" {
  run_setup "How can we make remote work more creative?"
  assert_success

  assert_frontmatter "question" "How can we make remote work more creative?" "$(state_file)"
}

@test "--interactive flag sets interactive true and level checkpoint" {
  run_setup --interactive "Test topic"
  assert_success

  assert_frontmatter "interactive" "true" "$(state_file)"
  assert_frontmatter "interactive_level" "checkpoint" "$(state_file)"
}

@test "--interactive=full sets interactive true and level full" {
  run_setup --interactive=full "Test topic"
  assert_success

  assert_frontmatter "interactive" "true" "$(state_file)"
  assert_frontmatter "interactive_level" "full" "$(state_file)"
}

@test "--focus value is stored" {
  run_setup --focus "business model" "Test topic"
  assert_success

  assert_frontmatter "focus" "business model" "$(state_file)"
}

@test "--output value is stored" {
  run_setup --output "/tmp/test-output.html" "Test topic"
  assert_success

  assert_frontmatter "output" "/tmp/test-output.html" "$(state_file)"
}

@test "combined flags work together" {
  run_setup --personas "theater-director,architect,game-designer" --rounds 2 --interactive --focus "user experience" "Big topic here"
  assert_success

  local sf
  sf=$(state_file)
  assert_frontmatter "question" "Big topic here" "$sf"
  assert_frontmatter "personas" "theater-director|architect|game-designer" "$sf"
  assert_frontmatter "max_rounds" "2" "$sf"
  assert_frontmatter "interactive" "true" "$sf"
  assert_frontmatter "focus" "user experience" "$sf"
}

load "../helpers/assertions"
