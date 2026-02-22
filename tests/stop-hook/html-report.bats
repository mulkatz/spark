#!/usr/bin/env bats
# Tests for stop-hook.sh HTML report generation via generate-report.mjs

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

# Skip all HTML tests if bun is not available
setup() {
  if ! command -v bun >/dev/null 2>&1; then
    skip "bun not available"
  fi
  setup_test_dir
}

@test "html output contains valid DOCTYPE" {
  local result_path="${TEST_DIR}/report.html"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Final synthesis output"
  run_stop_hook

  assert_success
  [[ -f "$result_path" ]]
  grep -q '<!DOCTYPE html>' "$result_path"
}

@test "html output contains report title" {
  local result_path="${TEST_DIR}/report.html"
  create_state_file phase=synthesize persona_index=0 output="$result_path" question="How to innovate faster?"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Synthesis content"
  run_stop_hook

  assert_success
  grep -q 'How to innovate faster?' "$result_path"
  grep -q 'SPARK REPORT' "$result_path"
}

@test "html output contains persona names" {
  local result_path="${TEST_DIR}/report.html"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "Theater seeds"
  add_seed_to_state "urban-planner" "Urban seeds"
  add_seed_to_state "biomimicry-scientist" "Bio seeds"
  setup_hook_input "Synthesis"
  run_stop_hook

  assert_success
  grep -q 'theater-director' "$result_path"
  grep -q 'urban-planner' "$result_path"
  grep -q 'biomimicry-scientist' "$result_path"
}

@test "md output bypasses HTML conversion" {
  local result_path="${TEST_DIR}/report.md"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Plain markdown synthesis"
  run_stop_hook

  assert_success
  [[ -f "$result_path" ]]
  # Should NOT contain HTML DOCTYPE
  ! grep -q '<!DOCTYPE html>' "$result_path"
  # Should contain raw markdown
  grep -q 'Spark Report' "$result_path"
}

@test "html output contains synthesis content" {
  local result_path="${TEST_DIR}/report.html"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "The three key themes that emerged are convergent innovation"
  run_stop_hook

  assert_success
  grep -q 'convergent innovation' "$result_path"
}

@test "html output contains session record when present" {
  local result_path="${TEST_DIR}/report.html"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "UNIQUE_SEED_CONTENT_HTML"
  setup_hook_input "Synthesis"
  run_stop_hook

  assert_success
  grep -q 'Session Record' "$result_path"
  grep -q 'UNIQUE_SEED_CONTENT_HTML' "$result_path"
}

@test "html output wraps synthesis in callout styling" {
  local result_path="${TEST_DIR}/report.html"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Key themes from ideation"
  run_stop_hook

  assert_success
  grep -q 'synthesis-callout' "$result_path"
  grep -q 'synthesis-section' "$result_path"
}

@test "html output applies persona colors to seed sections" {
  local result_path="${TEST_DIR}/report.html"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "### Ideas from theater\n\nTheater ideas"
  add_seed_to_state "urban-planner" "### Urban concepts\n\nUrban ideas"
  setup_hook_input "Synthesis"
  run_stop_hook

  assert_success
  # Should have persona-section divs with color classes
  grep -q 'persona-section' "$result_path"
  # Should have persona color CSS generated
  grep -q 'persona-teal' "$result_path"
}

@test "html output strips custom: and linkedin: prefixes from headings" {
  local result_path="${TEST_DIR}/report.html"
  create_state_file phase=synthesize persona_index=0 output="$result_path" \
    personas="custom:A deep-sea diver|linkedin:Jane Smith, Engineer|game-designer"
  add_persona_desc_to_state "custom:A deep-sea diver" "A deep-sea diver"
  add_persona_desc_to_state "linkedin:Jane Smith, Engineer" "Jane persona"
  add_persona_desc_to_state "game-designer" "Game designer persona"
  add_seed_to_state "custom:A deep-sea diver" "## Seed: custom:A deep-sea diver\n\nDiver seeds"
  add_seed_to_state "linkedin:Jane Smith, Engineer" "## Seed: linkedin:Jane Smith, Engineer\n\nJane seeds"
  add_seed_to_state "game-designer" "## Seed: game-designer\n\nGame seeds"
  setup_hook_input "Synthesis"
  run_stop_hook

  assert_success
  # H2 headings should show cleaned names, not raw prefixes
  grep -q 'Custom Perspective' "$result_path"
  grep -q 'Jane Smith' "$result_path"
  # Raw prefixes should NOT appear in heading text
  ! grep -q '>Seed: custom:' "$result_path"
  ! grep -q '>Seed: linkedin:' "$result_path"
}

@test "html output contains Spark branding" {
  local result_path="${TEST_DIR}/report.html"
  create_state_file phase=synthesize persona_index=0 output="$result_path"
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Synthesis"
  run_stop_hook

  assert_success
  grep -q 'Generated by Spark' "$result_path"
  grep -q 'SPARK' "$result_path"
  # Should NOT contain Anvil branding
  ! grep -q 'ANVIL' "$result_path"
  ! grep -q 'Generated by Anvil' "$result_path"
}
