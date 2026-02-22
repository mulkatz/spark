#!/usr/bin/env bats
# Tests for setup-spark.sh LinkedIn persona support

load "../helpers/setup"
load "../helpers/assertions"

# Helper to run setup in isolated dir
run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

# --- Validation ---

@test "empty linkedin persona produces error" {
  run_setup --personas "linkedin:" "Test topic"
  assert_failure
  assert_output --partial "linkedin persona requires a URL or name"
}

@test "linkedin persona with URL is accepted" {
  run_setup --personas "linkedin:https://linkedin.com/in/jane-doe" "Test topic"
  assert_success
}

@test "linkedin persona with name+title is accepted" {
  run_setup --personas "linkedin:Jane Smith, VP Engineering at Google" "Test topic"
  assert_success
}

# --- State file structure ---

@test "linkedin persona sets phase to persona_gen" {
  run_setup --personas "linkedin:Satya Nadella, CEO Microsoft" "Test topic"
  assert_success

  assert_frontmatter "phase" "persona_gen" "$(state_file)"
}

@test "linkedin persona populates gen_indices" {
  run_setup --personas "linkedin:Someone Famous" "Test topic"
  assert_success

  local gen_indices
  gen_indices=$(get_frontmatter "gen_indices" "$(state_file)")
  [[ "$gen_indices" == "0" ]]
}

@test "linkedin persona stores placeholder description" {
  run_setup --personas "linkedin:Ada Lovelace, Mathematician" "Test topic"
  assert_success

  local body
  body=$(cat "$(state_file)")
  echo "$body" | grep -qF "[Persona to be researched and generated from: Ada Lovelace, Mathematician]"
}

@test "mixed preset and linkedin personas compute correct gen_indices" {
  run_setup --personas "architect,linkedin:Someone,game-designer" "Test topic"
  assert_success

  assert_frontmatter "gen_indices" "1" "$(state_file)"
}

@test "multiple linkedin personas compute correct gen_indices" {
  run_setup --personas "linkedin:Person A,linkedin:Person B,architect" "Test topic"
  assert_success

  assert_frontmatter "gen_indices" "0|1" "$(state_file)"
}

@test "preset-only personas have empty gen_indices" {
  run_setup --personas "architect,game-designer,jazz-musician" "Test topic"
  assert_success

  assert_frontmatter "gen_indices" "" "$(state_file)"
  assert_frontmatter "phase" "seed" "$(state_file)"
}

# --- Initial prompt output ---

@test "linkedin persona outputs persona_gen prompt" {
  run_setup --personas "linkedin:Satya Nadella" "Test topic"
  assert_success

  assert_output --partial "Persona Research & Generation"
  assert_output --partial "Person to Research"
  assert_output --partial "Satya Nadella"
}

@test "linkedin persona banner shows PERSONA GENERATION phase" {
  run_setup --personas "linkedin:Satya Nadella" "Test topic"
  assert_success

  assert_output --partial "PERSONA GENERATION"
}

# --- Display names ---

@test "banner shows cleaned display name for linkedin URL persona" {
  run_setup --personas "linkedin:https://linkedin.com/in/jane-doe" "Test topic"
  assert_success

  assert_output --partial "Jane Doe"
}

@test "banner shows cleaned display name for linkedin name persona" {
  run_setup --personas "linkedin:Jane Smith, VP Engineering at Google" "Test topic"
  assert_success

  assert_output --partial "Jane Smith"
}

# --- Custom persona enhancement ---

@test "custom persona gets enhanced template in initial output" {
  run_setup --personas "custom:A retired astronaut who teaches yoga" "Test topic"
  assert_success

  assert_output --partial "Your Persona"
  assert_output --partial "Fully inhabit this persona"
  assert_output --partial "A retired astronaut who teaches yoga"
}

@test "preset persona does NOT get enhanced template in initial output" {
  run_setup --personas "architect" "Test topic"
  assert_success

  local out="$output"
  if echo "$out" | grep -qF "Fully inhabit this persona"; then
    echo "FAIL: Preset persona should not get enhanced custom template" >&2
    return 1
  fi
}
