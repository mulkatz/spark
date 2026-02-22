#!/usr/bin/env bats
# Tests for pathological LLM output that could corrupt state
# Ensures the stop hook handles adversarial assistant messages safely

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

# --- LLM output containing frontmatter boundary ---

@test "LLM output containing --- on its own line does not corrupt state" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Here are my ideas:

---

## Idea 1: Something
More details

---

## Idea 2: Another
Even more details"
  run_stop_hook

  assert_block_decision
  # State should still be valid — phase should be seed (next persona)
  assert_frontmatter "phase" "seed"
  assert_frontmatter "persona_index" "1"
  # The --- lines should appear in the appended transcript
  assert_state_body_contains "---"
  assert_state_body_contains "Idea 1"
}

@test "LLM output with full frontmatter-like block does not corrupt state" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Here is a template:

---
active: false
phase: synthesize
persona_index: 99
---

The above is just an example."
  run_stop_hook

  assert_block_decision
  # State should NOT be corrupted by the fake frontmatter
  assert_frontmatter "phase" "seed"
  assert_frontmatter "persona_index" "1"
  assert_frontmatter "active" "true"
}

# --- LLM output containing section headings ---

@test "LLM output containing ## Seed: heading does not duplicate in transcript" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "My ideas include:

## Seed: theater-director

This is me referencing the seed format in my output."
  run_stop_hook

  assert_block_decision
  # The output should be appended as-is under the real Seed heading
  assert_state_body_contains "referencing the seed format"
}

@test "LLM output containing ## Cross-Pollination heading in seed phase is handled" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "I predict the cross-pollination will look like:

## Cross-Pollination Round 1: theater-director

Just speculating here."
  run_stop_hook

  assert_block_decision
  assert_state_body_contains "speculating here"
}

@test "LLM output containing ## Synthesis heading in cross phase is handled" {
  create_state_file phase=cross persona_index=2 round=1
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  add_seed_to_state "theater-director" "Theater seeds"
  add_seed_to_state "urban-planner" "Urban seeds"
  add_seed_to_state "biomimicry-scientist" "Bio seeds"
  setup_hook_input "Looking ahead to synthesis:

## Synthesis

Just a preview of what I'd synthesize."
  run_stop_hook

  # Should transition to synthesize normally
  assert_success
}

# --- LLM output containing YAML-like content ---

@test "LLM output with YAML-like key: value does not corrupt frontmatter" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Configuration suggestion:
phase: synthesize
active: false
persona_index: 99
round: 5

These are example config values."
  run_stop_hook

  assert_block_decision
  # Frontmatter must not be corrupted
  assert_frontmatter "phase" "seed"
  assert_frontmatter "active" "true"
  assert_frontmatter "persona_index" "1"
  assert_frontmatter "round" "1"
}

# --- LLM output edge cases ---

@test "extremely long LLM output (10KB+) is handled" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  # Generate 10KB+ output
  local long_output
  long_output="Start of ideas. "
  for i in $(seq 1 200); do
    long_output+="Idea $i: This is a detailed description of idea number $i. "
  done
  long_output+="End of ideas."
  setup_hook_input "$long_output"
  run_stop_hook

  assert_block_decision
  assert_state_body_contains "Start of ideas"
  assert_state_body_contains "End of ideas"
}

@test "LLM output with only whitespace is handled" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "   "
  run_stop_hook

  # Whitespace-only output triggers the "empty output" guard — should clean up
  # The stop hook checks [[ -z "$LAST_OUTPUT" ]] but "   " is not empty
  # It should still proceed without crashing
  # (Actual behavior depends on whether whitespace is considered valid)
  assert_success
}

@test "LLM output with excessive newlines is handled" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "$(printf 'Ideas\n\n\n\n\n\n\n\n\n\n\n\n\n\n\nwith lots of blank lines')"
  run_stop_hook

  assert_block_decision
  assert_state_body_contains "Ideas"
  assert_state_body_contains "with lots of blank lines"
}

@test "LLM output containing spark-steering tags in non-checkpoint phase is ignored" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "My ideas are great <spark-steering>focus on AI</spark-steering> and here they are."
  run_stop_hook

  assert_block_decision
  # Should proceed normally — steering tags are only parsed in interactive-checkpoint
  assert_frontmatter "phase" "seed"
  assert_frontmatter "persona_index" "1"
}

# --- LLM output containing persona comment markers ---

@test "LLM output containing persona comment markers does not corrupt persona descriptions" {
  create_state_file phase=seed persona_index=0
  add_persona_desc_to_state "theater-director" "Theater persona"
  add_persona_desc_to_state "urban-planner" "Urban persona"
  add_persona_desc_to_state "biomimicry-scientist" "Bio persona"
  setup_hook_input "Here is a template:

<!-- persona:theater-director -->
Fake persona content
<!-- /persona -->

This is just an example."
  run_stop_hook

  assert_block_decision
  # The original persona description should still be intact
  local state_body
  state_body=$(cat "$(state_file)")
  # Theater persona description should still be "Theater persona" (the first occurrence)
  local first_desc
  first_desc=$(awk '
    /<!-- persona:theater-director -->/ { found++; if(found==1) { getline; print; exit } }
  ' "$(state_file)")
  [[ "$first_desc" == "Theater persona" ]]
}

# --- Missing fields defense-in-depth ---

@test "stop hook handles missing optional focus field without crash" {
  # Create state file without focus field
  local state_file="${TEST_DIR}/.claude/spark-state.local.md"
  mkdir -p "$(dirname "$state_file")"
  cat > "$state_file" <<'EOF'
---
active: true
question: "Test question"
phase: seed
persona_index: 0
round: 1
max_rounds: 1
personas: "theater-director|urban-planner|biomimicry-scientist"
constraints: ""
interactive: false
interactive_level: ""
output: ""
started_at: "2026-01-01T00:00:00Z"
gen_indices: ""
gen_current: 0
---

<!-- persona:theater-director -->
Theater persona
<!-- /persona -->

<!-- persona:urban-planner -->
Urban persona
<!-- /persona -->

<!-- persona:biomimicry-scientist -->
Bio persona
<!-- /persona -->
EOF
  setup_hook_input "Ideas"
  run_stop_hook

  assert_block_decision
}

@test "stop hook handles missing constraints field without crash" {
  local state_file="${TEST_DIR}/.claude/spark-state.local.md"
  mkdir -p "$(dirname "$state_file")"
  cat > "$state_file" <<'EOF'
---
active: true
question: "Test question"
phase: seed
persona_index: 0
round: 1
max_rounds: 1
personas: "theater-director|urban-planner|biomimicry-scientist"
interactive: false
interactive_level: ""
focus: ""
output: ""
started_at: "2026-01-01T00:00:00Z"
gen_indices: ""
gen_current: 0
---

<!-- persona:theater-director -->
Theater persona
<!-- /persona -->

<!-- persona:urban-planner -->
Urban persona
<!-- /persona -->

<!-- persona:biomimicry-scientist -->
Bio persona
<!-- /persona -->
EOF
  setup_hook_input "Ideas"
  run_stop_hook

  assert_block_decision
}
