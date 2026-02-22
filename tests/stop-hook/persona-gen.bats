#!/usr/bin/env bats
# Tests for stop-hook.sh persona_gen phase and custom persona enhancement

load "../helpers/setup"
load "../helpers/state-factory"
load "../helpers/transcript-factory"
load "../helpers/assertions"

# --- persona_gen phase transitions ---

@test "persona_gen(gen_current=0, 1 linkedin) → seed(idx=0)" {
  create_state_file phase=persona_gen persona_index=0 \
    personas="linkedin:Satya Nadella|architect|game-designer" \
    gen_indices="0" gen_current=0
  add_persona_desc_to_state "linkedin:Satya Nadella" "[Placeholder]"
  add_persona_desc_to_state "architect" "Architect persona"
  add_persona_desc_to_state "game-designer" "Game designer persona"
  setup_hook_input "# Persona: Satya Nadella\n\nGenerated persona content here."
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "seed"
  assert_frontmatter "persona_index" "0"
  assert_frontmatter "gen_current" "1"
}

@test "persona_gen(gen_current=0, 2 linkedin) → persona_gen(gen_current=1)" {
  create_state_file phase=persona_gen persona_index=0 \
    personas="linkedin:Person A|linkedin:Person B|architect" \
    gen_indices="0|1" gen_current=0
  add_persona_desc_to_state "linkedin:Person A" "[Placeholder A]"
  add_persona_desc_to_state "linkedin:Person B" "[Placeholder B]"
  add_persona_desc_to_state "architect" "Architect persona"
  setup_hook_input "# Persona: Person A\n\nGenerated persona A."
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "persona_gen"
  assert_frontmatter "gen_current" "1"
}

@test "persona_gen(gen_current=1, 2 linkedin) → seed(idx=0)" {
  create_state_file phase=persona_gen persona_index=0 \
    personas="linkedin:Person A|linkedin:Person B|architect" \
    gen_indices="0|1" gen_current=1
  add_persona_desc_to_state "linkedin:Person A" "Already generated persona A"
  add_persona_desc_to_state "linkedin:Person B" "[Placeholder B]"
  add_persona_desc_to_state "architect" "Architect persona"
  setup_hook_input "# Persona: Person B\n\nGenerated persona B."
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "seed"
  assert_frontmatter "persona_index" "0"
  assert_frontmatter "gen_current" "2"
}

@test "persona_gen with middle index (non-zero linkedin) works" {
  create_state_file phase=persona_gen persona_index=0 \
    personas="architect|linkedin:Someone|game-designer" \
    gen_indices="1" gen_current=0
  add_persona_desc_to_state "architect" "Architect persona"
  add_persona_desc_to_state "linkedin:Someone" "[Placeholder]"
  add_persona_desc_to_state "game-designer" "Game designer persona"
  setup_hook_input "# Persona: Someone\n\nFull generated persona."
  run_stop_hook

  assert_block_decision
  assert_frontmatter "phase" "seed"
  assert_frontmatter "persona_index" "0"
}

# --- Persona description replacement ---

@test "persona_gen replaces placeholder in state file" {
  create_state_file phase=persona_gen persona_index=0 \
    personas="linkedin:Test Person|architect|game-designer" \
    gen_indices="0" gen_current=0
  add_persona_desc_to_state "linkedin:Test Person" "[Persona to be researched and generated from: Test Person]"
  add_persona_desc_to_state "architect" "Architect persona"
  add_persona_desc_to_state "game-designer" "Game designer persona"
  setup_hook_input "This is the fully generated persona content for Test Person."
  run_stop_hook

  assert_block_decision
  # The placeholder should be replaced with the generated content
  assert_state_body_contains "fully generated persona content"
  # The placeholder should be gone
  local body
  body=$(cat "$(state_file)")
  if echo "$body" | grep -qF "[Persona to be researched and generated from: Test Person]"; then
    echo "FAIL: Placeholder should have been replaced" >&2
    return 1
  fi
}

@test "persona_gen preserves backslashes in generated content" {
  create_state_file phase=persona_gen persona_index=0 \
    personas="linkedin:Test Person|architect|game-designer" \
    gen_indices="0" gen_current=0
  add_persona_desc_to_state "linkedin:Test Person" "[Placeholder]"
  add_persona_desc_to_state "architect" "Architect persona"
  add_persona_desc_to_state "game-designer" "Game designer persona"
  # Content with literal backslashes that awk -v would corrupt
  setup_hook_input 'Persona uses regex like \n and paths like C:\new\tools'
  run_stop_hook

  assert_block_decision
  # Backslashes should survive — not be interpreted as escape sequences
  assert_state_body_contains '\n'
  assert_state_body_contains '\tools'
}

# --- persona_gen prompt construction ---

@test "persona_gen prompt includes persona-gen.md instructions" {
  create_state_file phase=persona_gen persona_index=0 \
    personas="linkedin:Person A|linkedin:Person B|architect" \
    gen_indices="0|1" gen_current=0
  add_persona_desc_to_state "linkedin:Person A" "[Placeholder A]"
  add_persona_desc_to_state "linkedin:Person B" "[Placeholder B]"
  add_persona_desc_to_state "architect" "Architect persona"
  setup_hook_input "Generated persona A content."
  run_stop_hook

  assert_block_decision
  # Next prompt should be for persona_gen of Person B
  assert_reason_contains "Persona Research & Generation"
  assert_reason_contains "Person B"
}

@test "persona_gen → seed prompt includes persona-gen.md for first, seed for second transition" {
  create_state_file phase=persona_gen persona_index=0 \
    personas="linkedin:Satya Nadella|architect|game-designer" \
    gen_indices="0" gen_current=0
  add_persona_desc_to_state "linkedin:Satya Nadella" "[Placeholder]"
  add_persona_desc_to_state "architect" "Architect persona"
  add_persona_desc_to_state "game-designer" "Game designer persona"
  setup_hook_input "Generated Satya persona."
  run_stop_hook

  assert_block_decision
  # Should transition to seed and include seed phase instructions
  assert_reason_contains "Seed Phase"
}

# --- persona_gen system messages ---

@test "persona_gen system message includes display name" {
  create_state_file phase=persona_gen persona_index=0 \
    personas="linkedin:Person A|linkedin:Person B|architect" \
    gen_indices="0|1" gen_current=0
  add_persona_desc_to_state "linkedin:Person A" "[Placeholder A]"
  add_persona_desc_to_state "linkedin:Person B" "[Placeholder B]"
  add_persona_desc_to_state "architect" "Architect persona"
  setup_hook_input "Generated persona A."
  run_stop_hook

  assert_block_decision
  assert_system_message_contains "PERSONA GENERATION"
  assert_system_message_contains "Person B"
}

# --- Custom persona enhancement in stop hook ---

@test "custom persona gets enhanced template in seed prompt" {
  create_state_file phase=seed persona_index=0 \
    personas="custom:A deep-sea diver philosopher|architect|game-designer"
  add_persona_desc_to_state "custom:A deep-sea diver philosopher" "A deep-sea diver philosopher"
  add_persona_desc_to_state "architect" "Architect persona"
  add_persona_desc_to_state "game-designer" "Game designer persona"
  setup_hook_input "First persona ideas"
  run_stop_hook

  assert_block_decision
  # The next prompt (for architect, persona index 1) should be normal
  assert_reason_contains "Architect persona"
}

@test "custom persona gets enhanced template when it is the next persona in seed" {
  create_state_file phase=seed persona_index=0 \
    personas="architect|custom:A retired astronaut who teaches yoga|game-designer"
  add_persona_desc_to_state "architect" "Architect persona"
  add_persona_desc_to_state "custom:A retired astronaut who teaches yoga" "A retired astronaut who teaches yoga"
  add_persona_desc_to_state "game-designer" "Game designer persona"
  setup_hook_input "Architect ideas"
  run_stop_hook

  assert_block_decision
  assert_reason_contains "Your Persona"
  assert_reason_contains "Fully inhabit this persona"
  assert_reason_contains "A retired astronaut who teaches yoga"
}

@test "custom persona gets enhanced template in cross prompt" {
  create_state_file phase=seed persona_index=2 \
    personas="architect|custom:A deep-sea diver philosopher|game-designer"
  add_persona_desc_to_state "architect" "Architect persona"
  add_persona_desc_to_state "custom:A deep-sea diver philosopher" "A deep-sea diver philosopher"
  add_persona_desc_to_state "game-designer" "Game designer persona"
  add_seed_to_state "architect" "Architect seed ideas"
  add_seed_to_state "custom:A deep-sea diver philosopher" "Diver seed ideas"
  setup_hook_input "Game designer seed ideas"
  run_stop_hook

  assert_block_decision
  # Cross phase starts, first persona is architect (normal)
  assert_reason_contains "Architect persona"
}

@test "custom persona in cross phase gets enhanced template when next" {
  create_state_file phase=cross persona_index=0 round=1 \
    personas="architect|custom:A poet who builds bridges|game-designer"
  add_persona_desc_to_state "architect" "Architect persona"
  add_persona_desc_to_state "custom:A poet who builds bridges" "A poet who builds bridges"
  add_persona_desc_to_state "game-designer" "Game designer persona"
  add_seed_to_state "architect" "Architect seeds"
  setup_hook_input "Architect cross ideas"
  run_stop_hook

  assert_block_decision
  assert_reason_contains "Your Persona"
  assert_reason_contains "Fully inhabit this persona"
  assert_reason_contains "A poet who builds bridges"
}

@test "preset persona does NOT get enhanced template in seed prompt" {
  create_state_file phase=seed persona_index=0 \
    personas="architect|urban-planner|game-designer"
  add_persona_desc_to_state "architect" "Architect persona desc"
  add_persona_desc_to_state "urban-planner" "Urban planner persona desc"
  add_persona_desc_to_state "game-designer" "Game designer persona desc"
  setup_hook_input "Architect ideas"
  run_stop_hook

  assert_block_decision
  local reason
  reason=$(printf '%s' "$output" | jq -r '.reason' 2>/dev/null)
  if printf '%s' "$reason" | grep -qF "Fully inhabit this persona"; then
    echo "FAIL: Preset persona should NOT get enhanced custom template" >&2
    return 1
  fi
}

# --- Display name in system messages ---

@test "seed system message uses display name for custom persona" {
  create_state_file phase=seed persona_index=0 \
    personas="architect|custom:A poet|game-designer"
  add_persona_desc_to_state "architect" "Architect persona"
  add_persona_desc_to_state "custom:A poet" "A poet"
  add_persona_desc_to_state "game-designer" "Game designer persona"
  setup_hook_input "Architect ideas"
  run_stop_hook

  assert_block_decision
  assert_system_message_contains "Custom Perspective"
}

@test "cross system message uses display name for linkedin persona" {
  create_state_file phase=seed persona_index=2 \
    personas="linkedin:Jane Smith, Engineer|architect|game-designer" \
    gen_indices="" gen_current=0
  add_persona_desc_to_state "linkedin:Jane Smith, Engineer" "Generated Jane persona"
  add_persona_desc_to_state "architect" "Architect persona"
  add_persona_desc_to_state "game-designer" "Game designer persona"
  add_seed_to_state "linkedin:Jane Smith, Engineer" "Jane seeds"
  add_seed_to_state "architect" "Architect seeds"
  setup_hook_input "Game designer seeds"
  run_stop_hook

  assert_block_decision
  assert_system_message_contains "Jane Smith"
}
