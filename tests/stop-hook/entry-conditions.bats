#!/usr/bin/env bats
# Tests for stop-hook.sh entry conditions

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

@test "exits silently when no state file exists" {
  setup_hook_input "Some output"
  run_stop_hook
  assert_success
  assert_output ""
}

@test "exits silently when state is inactive" {
  create_state_file active=false
  setup_hook_input "Some output"
  run_stop_hook
  assert_success
  assert_state_cleaned
}

@test "exits silently with invalid phase" {
  create_state_file phase=bogus
  setup_hook_input "Some output"
  run_stop_hook
  assert_success
  assert_state_cleaned
}

@test "exits silently when transcript file is missing" {
  create_state_file
  HOOK_INPUT=$(jq -n '{"transcript_path": "/nonexistent/transcript.jsonl"}')
  run_stop_hook
  assert_success
  assert_state_cleaned
}

@test "exits silently when transcript has no assistant messages" {
  create_state_file
  local transcript_file="${BATS_TEST_TMPDIR}/transcript-${RANDOM}.jsonl"
  printf '{"role":"user","message":{"content":[{"type":"text","text":"hello"}]}}\n' > "$transcript_file"
  HOOK_INPUT=$(create_hook_input "$transcript_file")
  run_stop_hook
  assert_success
  assert_state_cleaned
}

@test "exits silently with corrupted persona_index" {
  create_state_file persona_index=abc
  setup_hook_input "Some output"
  run_stop_hook
  assert_success
  assert_state_cleaned
}

@test "exits silently with corrupted round" {
  create_state_file round=xyz
  setup_hook_input "Some output"
  run_stop_hook
  assert_success
  assert_state_cleaned
}
