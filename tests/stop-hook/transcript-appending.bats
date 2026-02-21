#!/usr/bin/env bats
# Tests for stop-hook.sh transcript appending

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

@test "seed output is appended with correct heading" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "My theater ideas are amazing"
  run_stop_hook

  assert_block_decision
  assert_state_body_contains "## Seed: theater-director"
  assert_state_body_contains "My theater ideas are amazing"
}

@test "cross output is appended with round and persona heading" {
  create_state_file phase=cross persona_index=1 round=1
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Cross-pollinated urban ideas"
  run_stop_hook

  assert_block_decision
  assert_state_body_contains "## Cross-Pollination Round 1: urban-planner"
  assert_state_body_contains "Cross-pollinated urban ideas"
}

@test "interactive-checkpoint output is NOT appended to transcript" {
  create_state_file phase=interactive-checkpoint persona_index=0 round=1 max_rounds=1 interactive=true interactive_level=checkpoint
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "CHECKPOINT_META_OUTPUT <spark-steering>none</spark-steering>"
  run_stop_hook

  assert_block_decision
  local body
  body=$(awk '/^---$/{i++; next} i>=2' "$(state_file)")
  if printf '%s' "$body" | grep -qF "CHECKPOINT_META_OUTPUT"; then
    echo "FAIL: Interactive checkpoint output should NOT be in transcript" >&2
    return 1
  fi
}

@test "multiple seed outputs create separate headings" {
  # Simulate: persona 0 already seeded, now persona 1 seeds
  create_state_file phase=seed persona_index=1
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "Theater ideas"
  setup_hook_input "Urban planning ideas"
  run_stop_hook

  assert_block_decision
  assert_state_body_contains "## Seed: theater-director"
  assert_state_body_contains "## Seed: urban-planner"
}
