#!/usr/bin/env bats
# Tests for setup-spark.sh persona auto-selection

load "../helpers/setup"
load "../helpers/assertions"

# Helper to run setup in isolated dir
run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

@test "auto-select picks exactly 3 personas" {
  run_setup "Test topic"
  assert_success

  local personas
  personas=$(get_frontmatter "personas" "$(state_file)")
  # Count pipe-separated values
  local count
  count=$(echo "$personas" | tr '|' '\n' | wc -l | tr -d ' ')
  [[ "$count" -eq 3 ]]
}

@test "auto-selected personas are from available pool" {
  run_setup "Test topic"
  assert_success

  local personas
  personas=$(get_frontmatter "personas" "$(state_file)")

  IFS='|' read -ra selected <<< "$personas"
  for p in "${selected[@]}"; do
    [[ -f "$PLUGIN_ROOT/prompts/personas/${p}.md" ]]
  done
}

@test "explicit personas are used instead of auto-selection" {
  run_setup --personas "jazz-musician,scifi-author,game-designer" "Test topic"
  assert_success

  assert_frontmatter "personas" "jazz-musician|scifi-author|game-designer" "$(state_file)"
}

@test "custom persona is stored correctly" {
  run_setup --personas "custom:A retired astronaut who teaches yoga" "Test topic"
  assert_success

  local personas
  personas=$(get_frontmatter "personas" "$(state_file)")
  [[ "$personas" == *"custom:A retired astronaut who teaches yoga"* ]]
}

@test "mixed preset and custom personas work" {
  run_setup --personas "theater-director,custom:A deep-sea diver philosopher" "Test topic"
  assert_success

  local personas
  personas=$(get_frontmatter "personas" "$(state_file)")
  [[ "$personas" == *"theater-director"* ]]
  [[ "$personas" == *"custom:A deep-sea diver philosopher"* ]]
}
