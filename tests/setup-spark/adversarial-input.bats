#!/usr/bin/env bats
# Tests for special character handling in all user input paths
# Ensures YAML roundtrip, prompt output, and state integrity

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

# Helper to run setup in isolated dir
run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

# --- Topic (question) with special characters ---

@test "topic with double quotes survives YAML roundtrip" {
  run_setup --personas "theater-director,urban-planner,architect" 'How do we handle "quotes" properly?'
  assert_success
  assert_frontmatter "question" 'How do we handle "quotes" properly?' "$(state_file)"
}

@test "topic with backslashes survives YAML roundtrip" {
  run_setup --personas "theater-director,urban-planner,architect" 'Windows paths like C:\Users\test'
  assert_success
  assert_frontmatter "question" 'Windows paths like C:\Users\test' "$(state_file)"
}

@test "topic with backslash-n survives YAML roundtrip (not interpreted as newline)" {
  run_setup --personas "theater-director,urban-planner,architect" 'Regex like \n and \t patterns'
  assert_success
  assert_frontmatter "question" 'Regex like \n and \t patterns' "$(state_file)"
}

@test "topic with single quotes is stored correctly" {
  run_setup --personas "theater-director,urban-planner,architect" "What's the best approach?"
  assert_success
  assert_frontmatter "question" "What's the best approach?" "$(state_file)"
}

@test "topic with dollar signs is stored correctly" {
  run_setup --personas "theater-director,urban-planner,architect" 'Cost is $100 per unit'
  assert_success
  assert_frontmatter "question" 'Cost is $100 per unit' "$(state_file)"
}

@test "topic with backticks is stored correctly" {
  run_setup --personas "theater-director,urban-planner,architect" 'Use `code` blocks for clarity'
  assert_success
  assert_frontmatter "question" 'Use `code` blocks for clarity' "$(state_file)"
}

@test "topic appears in initial prompt output" {
  run_setup --personas "theater-director,urban-planner,architect" 'Topic with "quotes" and C:\path'
  assert_success
  [[ "$output" == *'"quotes"'* ]]
  [[ "$output" == *'C:\path'* ]]
}

# --- Focus with special characters ---

@test "focus with double quotes survives YAML roundtrip" {
  run_setup --personas "theater-director,urban-planner,architect" --focus 'The "best" approach' "Test topic"
  assert_success
  assert_frontmatter "focus" 'The "best" approach' "$(state_file)"
}

@test "focus with backslashes survives YAML roundtrip" {
  run_setup --personas "theater-director,urban-planner,architect" --focus 'Paths like C:\Users' "Test topic"
  assert_success
  assert_frontmatter "focus" 'Paths like C:\Users' "$(state_file)"
}

@test "focus appears in prompt output" {
  run_setup --personas "theater-director,urban-planner,architect" --focus 'The "best" C:\approach' "Test topic"
  assert_success
  [[ "$output" == *'The "best" C:\approach'* ]]
}

# --- Custom persona with special characters ---

@test "custom persona with backslashes is stored correctly" {
  run_setup --personas 'custom:A developer who loves C:\Windows\System32,architect,game-designer' "Test topic"
  assert_success
  assert_state_body_contains 'C:\Windows\System32'
}

@test "custom persona with double quotes is stored correctly" {
  run_setup --personas 'custom:A person who says "hello world",architect,game-designer' "Test topic"
  assert_success
  assert_state_body_contains 'says "hello world"'
}

@test "custom persona with dollar signs is stored correctly" {
  run_setup --personas 'custom:A banker who deals with $1M+ accounts,architect,game-designer' "Test topic"
  assert_success
  assert_state_body_contains '$1M+'
}

@test "custom persona with backticks is stored correctly" {
  run_setup --personas 'custom:A coder who writes `bash` scripts,architect,game-designer' "Test topic"
  assert_success
  assert_state_body_contains '`bash`'
}

@test "custom persona description appears in initial prompt" {
  run_setup --personas 'custom:A person with "quotes" and $dollars,architect,game-designer' "Test topic"
  assert_success
  [[ "$output" == *'"quotes"'* ]]
  [[ "$output" == *'$dollars'* ]]
}

@test "custom persona with backslashes appears in stop hook prompt" {
  # Set persona_index=0 so after seed(0), next is seed(1) which is the custom persona
  create_state_file phase=seed persona_index=0 \
    personas='architect|custom:A dev who uses C:\tools|game-designer'
  add_persona_desc_to_state "architect" "Architect persona"
  add_persona_desc_to_state 'custom:A dev who uses C:\tools' 'A dev who uses C:\tools'
  add_persona_desc_to_state "game-designer" "Game designer persona"
  setup_hook_input "Architect ideas"
  run_stop_hook

  assert_block_decision
  # The next prompt (for custom persona at index 1) should contain the backslash description
  assert_reason_contains 'C:\tools'
}

# --- Persona names roundtrip through pipe-separated YAML ---

@test "custom persona name with quotes survives personas YAML roundtrip" {
  run_setup --personas 'custom:The "great" thinker,architect,game-designer' "Test topic"
  assert_success
  local personas
  personas=$(get_frontmatter "personas" "$(state_file)")
  [[ "$personas" == *'custom:The "great" thinker'* ]]
}

@test "custom persona name with backslash survives personas YAML roundtrip" {
  run_setup --personas 'custom:A C:\developer,architect,game-designer' "Test topic"
  assert_success
  local personas
  personas=$(get_frontmatter "personas" "$(state_file)")
  [[ "$personas" == *'custom:A C:\developer'* ]]
}

# --- Stop hook reads back special chars correctly ---

@test "stop hook reads topic with special chars from state file" {
  create_state_file phase=seed persona_index=0 \
    question='How do "quotes" and C:\paths work?'
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Ideas about quotes and paths"
  run_stop_hook

  assert_block_decision
  # Topic should appear unescaped in the prompt
  assert_reason_contains '"quotes"'
  assert_reason_contains 'C:\paths'
}

@test "stop hook reads focus with special chars from state file" {
  create_state_file phase=seed persona_index=0 \
    focus='The "big" C:\picture'
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Ideas"
  run_stop_hook

  assert_block_decision
  assert_reason_contains '"big"'
  assert_reason_contains 'C:\picture'
}

# --- Validation edge cases ---

@test "persona with pipe character is rejected" {
  run_setup --personas "custom:Has|pipe,architect,game-designer" "Test topic"
  assert_failure
  [[ "$output" == *"cannot contain '|'"* ]]
}

@test "persona with HTML comment markers is rejected" {
  run_setup --personas "custom:Has <!-- comment -->,architect,game-designer" "Test topic"
  assert_failure
  [[ "$output" == *"cannot contain HTML comment markers"* ]]
}

@test "persona specification with newline character is rejected" {
  run_setup --personas "$(printf 'custom:Has\nnewline,architect,game-designer')" "Test topic"
  assert_failure
  [[ "$output" == *"cannot contain newline"* ]]
}

# --- Output in synthesize phase with special chars ---

@test "synthesis report preserves special chars in topic" {
  local result_path="${TEST_DIR}/report.md"
  create_state_file phase=synthesize persona_index=0 \
    output="$result_path" question='Topic with "quotes" and C:\path'
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Final synthesis"
  run_stop_hook

  assert_success
  [[ -f "$result_path" ]]
  grep -qF '"quotes"' "$result_path"
  grep -qF 'C:\path' "$result_path"
}

# --- Very long input ---

@test "very long topic (500+ chars) is handled without crash" {
  local long_topic
  long_topic=$(printf 'A%.0s' {1..500})
  run_setup --personas "theater-director,urban-planner,architect" "$long_topic"
  assert_success
  assert_state_exists
}

@test "very long custom persona description is handled" {
  local long_desc
  long_desc="custom:$(printf 'B%.0s' {1..500})"
  run_setup --personas "${long_desc},architect,game-designer" "Test topic"
  assert_success
  assert_state_exists
}
