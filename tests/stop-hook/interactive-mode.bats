#!/usr/bin/env bats
# Tests for stop-hook.sh interactive mode

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

@test "interactive checkpoint shows cluster summary instructions" {
  create_state_file phase=cross persona_index=2 round=1 max_rounds=1 interactive=true interactive_level=checkpoint
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Last cross output"
  run_stop_hook

  assert_block_decision
  assert_reason_contains "Interactive Checkpoint"
  assert_reason_contains "Theme clusters"
  assert_system_message_contains "INTERACTIVE CHECKPOINT"
}

@test "interactive checkpoint includes session transcript" {
  create_state_file phase=cross persona_index=2 round=1 max_rounds=1 interactive=true interactive_level=checkpoint
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "UNIQUE_SEED_IN_CHECKPOINT"
  setup_hook_input "Last cross output"
  run_stop_hook

  assert_block_decision
  assert_reason_contains "UNIQUE_SEED_IN_CHECKPOINT"
}

@test "non-interactive session skips checkpoint" {
  create_state_file phase=cross persona_index=2 round=1 max_rounds=1 interactive=false
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Last cross output"
  run_stop_hook

  assert_block_decision
  # Should go straight to synthesize, not interactive-checkpoint
  assert_frontmatter "phase" "synthesize"
}

@test "full interactive pauses between cross rounds" {
  create_state_file phase=cross persona_index=2 round=1 max_rounds=2 interactive=true interactive_level=full
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Cross output"
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "interactive-checkpoint"
}

@test "full interactive checkpoint between rounds continues to next round" {
  create_state_file phase=interactive-checkpoint persona_index=0 round=1 max_rounds=2 interactive=true interactive_level=full
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Summary <spark-steering>none</spark-steering>"
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "cross"
  assert_frontmatter "round" "2"
}
