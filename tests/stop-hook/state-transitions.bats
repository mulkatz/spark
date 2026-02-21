#!/usr/bin/env bats
# Tests for stop-hook.sh state machine transitions

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

@test "seed(idx=0) → seed(idx=1)" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Seed ideas from persona 1"
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "seed"
  assert_frontmatter "persona_index" "1"
}

@test "seed(idx=1) → seed(idx=2)" {
  create_state_file phase=seed persona_index=1
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "First persona seeds"
  setup_hook_input "Seed ideas from persona 2"
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "seed"
  assert_frontmatter "persona_index" "2"
}

@test "seed(idx=last) → cross(idx=0, round=1)" {
  create_state_file phase=seed persona_index=2
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "First persona seeds"
  add_seed_to_state "urban-planner" "Second persona seeds"
  setup_hook_input "Seed ideas from persona 3"
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "cross"
  assert_frontmatter "persona_index" "0"
  assert_frontmatter "round" "1"
}

@test "cross(idx=0) → cross(idx=1)" {
  create_state_file phase=cross persona_index=0 round=1
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Cross-pollinated ideas from persona 1"
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "cross"
  assert_frontmatter "persona_index" "1"
}

@test "cross(idx=last, round < max) → cross(idx=0, round+1)" {
  create_state_file phase=cross persona_index=2 round=1 max_rounds=2
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Cross-pollinated ideas from persona 3"
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "cross"
  assert_frontmatter "persona_index" "0"
  assert_frontmatter "round" "2"
}

@test "cross(idx=last, round=max, non-interactive) → synthesize" {
  create_state_file phase=cross persona_index=2 round=1 max_rounds=1
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Cross-pollinated ideas from persona 3"
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "synthesize"
}

@test "cross(idx=last, round=max, interactive) → interactive-checkpoint" {
  create_state_file phase=cross persona_index=2 round=1 max_rounds=1 interactive=true interactive_level=checkpoint
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Cross-pollinated ideas from persona 3"
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "interactive-checkpoint"
}

@test "interactive-checkpoint → synthesize" {
  create_state_file phase=interactive-checkpoint persona_index=0 round=1 max_rounds=1 interactive=true interactive_level=checkpoint
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Summary output <spark-steering>none</spark-steering>"
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "synthesize"
}
