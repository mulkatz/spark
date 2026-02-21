#!/usr/bin/env bats
# Integration tests: end-to-end ideation cycles

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

# Helper to run setup in isolated dir
run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

@test "full cycle: setup → seed×3 → cross×3 → synthesize → result" {
  # 1. Setup
  run_setup --personas "theater-director,urban-planner,architect" "How to innovate?"
  assert_success
  assert_state_exists

  # 2. Seed persona 1 (theater-director)
  setup_hook_input "Theater seed ideas: dramatic tension in innovation"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "seed"
  assert_frontmatter "persona_index" "1"

  # 3. Seed persona 2 (urban-planner)
  setup_hook_input "Urban seed ideas: infrastructure of creativity"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "seed"
  assert_frontmatter "persona_index" "2"

  # 4. Seed persona 3 (architect) → transitions to cross
  setup_hook_input "Architect seed ideas: constraints as enablers"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "cross"
  assert_frontmatter "persona_index" "0"
  assert_frontmatter "round" "1"

  # 5. Cross persona 1
  setup_hook_input "Theater cross: combining urban flows with dramatic arcs"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "cross"
  assert_frontmatter "persona_index" "1"

  # 6. Cross persona 2
  setup_hook_input "Urban cross: architect constraints applied to city spaces"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "cross"
  assert_frontmatter "persona_index" "2"

  # 7. Cross persona 3 → transitions to synthesize
  setup_hook_input "Architect cross: theater tension meets urban planning"
  run_stop_hook
  assert_block_decision
  assert_frontmatter "phase" "synthesize"

  # 8. Synthesize → terminal, result file created
  local result_path
  result_path=$(get_frontmatter "output" "$(state_file)")
  setup_hook_input "Final synthesis: three key themes emerged..."
  run_stop_hook
  assert_success
  assert_state_cleaned
  assert_output --partial "Spark session complete"
  [[ -f "$result_path" ]]
  grep -qF "three key themes emerged" "$result_path"
}

@test "2-round session has extra cross-pollination cycle" {
  run_setup --personas "theater-director,urban-planner,architect" --rounds 2 "Topic"
  assert_success

  # Seed ×3
  setup_hook_input "Seed 1" && run_stop_hook
  setup_hook_input "Seed 2" && run_stop_hook
  setup_hook_input "Seed 3" && run_stop_hook

  # Cross round 1 ×3
  assert_frontmatter "phase" "cross"
  assert_frontmatter "round" "1"
  setup_hook_input "Cross R1P1" && run_stop_hook
  setup_hook_input "Cross R1P2" && run_stop_hook
  setup_hook_input "Cross R1P3" && run_stop_hook

  # Should start cross round 2
  assert_frontmatter "phase" "cross"
  assert_frontmatter "round" "2"
  assert_frontmatter "persona_index" "0"

  # Cross round 2 ×3
  setup_hook_input "Cross R2P1" && run_stop_hook
  setup_hook_input "Cross R2P2" && run_stop_hook
  setup_hook_input "Cross R2P3" && run_stop_hook

  # Should transition to synthesize
  assert_frontmatter "phase" "synthesize"
}

@test "interactive session pauses before synthesis" {
  run_setup --personas "theater-director,urban-planner,architect" --interactive "Topic"
  assert_success

  # Seed ×3
  setup_hook_input "Seed 1" && run_stop_hook
  setup_hook_input "Seed 2" && run_stop_hook
  setup_hook_input "Seed 3" && run_stop_hook

  # Cross ×3
  setup_hook_input "Cross 1" && run_stop_hook
  setup_hook_input "Cross 2" && run_stop_hook
  setup_hook_input "Cross 3" && run_stop_hook

  # Should be at interactive-checkpoint, not synthesize
  assert_frontmatter "phase" "interactive-checkpoint"
  assert_reason_contains "Interactive Checkpoint"

  # User steers → synthesis
  setup_hook_input "Summary <spark-steering>none</spark-steering>"
  run_stop_hook
  assert_frontmatter "phase" "synthesize"
}

@test "auto-persona session selects and runs" {
  run_setup "Test topic with auto personas"
  assert_success

  local personas
  personas=$(get_frontmatter "personas" "$(state_file)")
  local count
  count=$(echo "$personas" | tr '|' '\n' | wc -l | tr -d ' ')
  [[ "$count" -eq 3 ]]
}

@test "session with focus includes focus in prompts" {
  run_setup --personas "theater-director,urban-planner,architect" --focus "sustainability" "Green innovation"
  assert_success
  assert_output --partial "sustainability"

  setup_hook_input "Seed ideas"
  run_stop_hook
  assert_reason_contains "sustainability"
}

@test "session with context includes context" {
  echo "Architecture docs here" > "$TEST_DIR/arch.md"
  run_setup --personas "theater-director,urban-planner,architect" --context "$TEST_DIR/arch.md" "Topic"
  assert_success
  assert_output --partial "Architecture docs here"
}
