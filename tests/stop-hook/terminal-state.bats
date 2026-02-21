#!/usr/bin/env bats
# Tests for stop-hook.sh terminal state (synthesis complete → result file)

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

@test "synthesize phase creates result file and cleans state" {
  local result_path="${TEST_DIR}/.claude/spark-result.local.md"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "Theater seeds"
  setup_hook_input "Final synthesis output here"
  run_stop_hook

  assert_success
  assert_state_cleaned
  [[ -f "$result_path" ]]
}

@test "result file contains synthesis output" {
  local result_path="${TEST_DIR}/.claude/spark-result.local.md"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "The synthesis reveals three key themes"
  run_stop_hook

  assert_success
  grep -qF "The synthesis reveals three key themes" "$result_path"
}

@test "result file contains report header with topic" {
  local result_path="${TEST_DIR}/.claude/spark-result.local.md"
  create_state_file phase=synthesize persona_index=0 output="$result_path" question="How to innovate faster?"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Synthesis content"
  run_stop_hook

  assert_success
  grep -qF "How to innovate faster?" "$result_path"
  grep -qF "Spark Report" "$result_path"
}

@test "result file contains persona names" {
  local result_path="${TEST_DIR}/.claude/spark-result.local.md"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Synthesis"
  run_stop_hook

  assert_success
  grep -qF "theater-director" "$result_path"
  grep -qF "urban-planner" "$result_path"
  grep -qF "biomimicry-scientist" "$result_path"
}

@test "custom output path is respected" {
  local custom_path="${TEST_DIR}/custom-output.md"
  create_state_file phase=synthesize persona_index=0 output="$custom_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Synthesis content"
  run_stop_hook

  assert_success
  [[ -f "$custom_path" ]]
}

@test "terminal state exits with 0" {
  local result_path="${TEST_DIR}/.claude/spark-result.local.md"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Synthesis"
  run_stop_hook

  assert_success
  assert_output --partial "Spark session complete"
}

@test "result includes session record when present" {
  local result_path="${TEST_DIR}/.claude/spark-result.local.md"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "UNIQUE_SEED_RECORD"
  setup_hook_input "Synthesis"
  run_stop_hook

  assert_success
  grep -qF "Session Record" "$result_path"
  grep -qF "UNIQUE_SEED_RECORD" "$result_path"
}
