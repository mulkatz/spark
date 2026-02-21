#!/usr/bin/env bats
# Tests for stop-hook.sh prompt construction

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

@test "seed prompt includes persona description" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "You are Kaspar Lindström, an experimental theater director."
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "First persona ideas"
  run_stop_hook

  assert_block_decision
  # Next prompt should be for persona index 1 (urban-planner)
  assert_reason_contains "urban-planner"
  assert_reason_contains "Urban persona"
}

@test "seed prompt includes phase instructions" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "First persona ideas"
  run_stop_hook

  assert_block_decision
  assert_reason_contains "Seed Phase"
  assert_reason_contains "independently"
}

@test "seed prompt does NOT include transcript (anti-convergence)" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "UNIQUE_SEED_CONTENT_12345"
  run_stop_hook

  assert_block_decision
  local reason
  reason=$(printf '%s' "$output" | jq -r '.reason' 2>/dev/null)
  # The next seed prompt should NOT contain the previous persona's output
  if printf '%s' "$reason" | grep -qF "UNIQUE_SEED_CONTENT_12345"; then
    echo "FAIL: Seed prompt should NOT include transcript (anti-convergence)" >&2
    return 1
  fi
}

@test "cross prompt includes transcript" {
  create_state_file phase=seed persona_index=2
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "Theater ideas here"
  add_seed_to_state "urban-planner" "Urban ideas here"
  setup_hook_input "Bio ideas here"
  run_stop_hook

  assert_block_decision
  # Cross prompt should include the seed transcript
  assert_reason_contains "Theater ideas here"
  assert_reason_contains "Urban ideas here"
}

@test "cross prompt includes cross-pollinate instructions" {
  create_state_file phase=seed persona_index=2
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "Theater ideas"
  add_seed_to_state "urban-planner" "Urban ideas"
  setup_hook_input "Bio ideas"
  run_stop_hook

  assert_block_decision
  assert_reason_contains "Cross-Pollination"
  assert_reason_contains "SCAMPER"
}

@test "synthesize prompt includes transcript" {
  create_state_file phase=cross persona_index=2 round=1 max_rounds=1
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "Theater seed ideas"
  add_cross_to_state 1 "theater-director" "Theater cross ideas"
  add_cross_to_state 1 "urban-planner" "Urban cross ideas"
  setup_hook_input "Bio cross ideas"
  run_stop_hook

  assert_block_decision
  assert_reason_contains "Theater seed ideas"
}

@test "synthesize prompt includes synthesis instructions" {
  create_state_file phase=cross persona_index=2 round=1 max_rounds=1
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Bio cross ideas"
  run_stop_hook

  assert_block_decision
  assert_reason_contains "Synthesis Phase"
  assert_reason_contains "Rank honestly"
}

@test "focus lens is included in seed prompt" {
  create_state_file phase=seed persona_index=0 focus="business model"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "First persona ideas"
  run_stop_hook

  assert_block_decision
  assert_reason_contains "business model"
  assert_reason_contains "Focus Lens"
}

@test "focus lens is included in cross prompt" {
  create_state_file phase=seed persona_index=2 focus="user experience"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "Ideas"
  add_seed_to_state "urban-planner" "Ideas"
  setup_hook_input "Ideas"
  run_stop_hook

  assert_block_decision
  assert_reason_contains "user experience"
}

@test "topic is included in all prompts" {
  create_state_file phase=seed persona_index=0 question="How to make APIs fun?"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Ideas"
  run_stop_hook

  assert_block_decision
  assert_reason_contains "How to make APIs fun?"
}
