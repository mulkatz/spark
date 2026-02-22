#!/usr/bin/env bash
# State file generator for Spark tests
#
# Usage:
#   create_state_file [KEY=VALUE ...]
#
# Creates a state file at $TEST_DIR/.claude/spark-state.local.md
# with the given frontmatter overrides. Defaults are provided for all fields.

create_state_file() {
  local active="true"
  local question="How can we make remote work more creative?"
  local phase="seed"
  local persona_index="0"
  local round="1"
  local max_rounds="1"
  local personas="theater-director|urban-planner|biomimicry-scientist"
  local interactive="false"
  local interactive_level=""
  local focus=""
  local context_source=""
  local output=""
  local constraints=""
  local started_at="2026-01-01T00:00:00Z"
  local gen_indices=""
  local gen_current="0"
  local body=""

  # Parse key=value arguments
  for arg in "$@"; do
    case "$arg" in
      active=*) active="${arg#active=}" ;;
      question=*) question="${arg#question=}" ;;
      phase=*) phase="${arg#phase=}" ;;
      persona_index=*) persona_index="${arg#persona_index=}" ;;
      round=*) round="${arg#round=}" ;;
      max_rounds=*) max_rounds="${arg#max_rounds=}" ;;
      personas=*) personas="${arg#personas=}" ;;
      interactive=*) interactive="${arg#interactive=}" ;;
      interactive_level=*) interactive_level="${arg#interactive_level=}" ;;
      focus=*) focus="${arg#focus=}" ;;
      context_source=*) context_source="${arg#context_source=}" ;;
      output=*) output="${arg#output=}" ;;
      constraints=*) constraints="${arg#constraints=}" ;;
      started_at=*) started_at="${arg#started_at=}" ;;
      gen_indices=*) gen_indices="${arg#gen_indices=}" ;;
      gen_current=*) gen_current="${arg#gen_current=}" ;;
      body=*) body="${arg#body=}" ;;
    esac
  done

  # Escape YAML double-quoted values (mirrors setup-spark.sh yaml_escape)
  _test_yaml_escape() {
    local s="$1"
    s="${s//\\/\\\\}"    # \ → \\  (must be first)
    s="${s//\"/\\\"}"    # " → \"
    s="${s//$'\n'/\\n}"  # newline → \n
    s="${s//$'\t'/\\t}"  # tab → \t
    s="${s//$'\r'/\\r}"  # CR → \r
    printf '%s' "$s"
  }

  local esc_question esc_focus esc_personas esc_constraints esc_context_source esc_output esc_gen_indices
  esc_question="\"$(_test_yaml_escape "$question")\""
  esc_focus=$(_test_yaml_escape "$focus")
  esc_personas=$(_test_yaml_escape "$personas")
  esc_constraints=$(_test_yaml_escape "$constraints")
  esc_context_source=$(_test_yaml_escape "$context_source")
  esc_output=$(_test_yaml_escape "$output")
  esc_gen_indices=$(_test_yaml_escape "$gen_indices")

  local state_file="${TEST_DIR}/.claude/spark-state.local.md"
  mkdir -p "$(dirname "$state_file")"

  cat > "$state_file" <<EOF
---
active: $active
question: $esc_question
phase: $phase
persona_index: $persona_index
round: $round
max_rounds: $max_rounds
personas: "$esc_personas"
constraints: "$esc_constraints"
interactive: $interactive
interactive_level: "$interactive_level"
focus: "$esc_focus"
context_source: "$esc_context_source"
output: "$esc_output"
started_at: "$started_at"
gen_indices: "$esc_gen_indices"
gen_current: $gen_current
---
EOF

  if [[ -n "$body" ]]; then
    printf '%s\n' "$body" >> "$state_file"
  fi

  echo "$state_file"
}

# Add persona description to an existing state file
# Usage: add_persona_desc_to_state "persona-name" "description"
add_persona_desc_to_state() {
  local name="$1"
  local desc="$2"
  local state_file="${TEST_DIR}/.claude/spark-state.local.md"
  printf '\n<!-- persona:%s -->\n%s\n<!-- /persona -->\n' "$name" "$desc" >> "$state_file"
}

# Add a seed transcript to an existing state file
# Usage: add_seed_to_state "persona-name" "seed content"
add_seed_to_state() {
  local persona_name="$1"
  local content="$2"
  local state_file="${TEST_DIR}/.claude/spark-state.local.md"
  printf '\n## Seed: %s\n\n%s\n' "$persona_name" "$content" >> "$state_file"
}

# Add a cross-pollination transcript to an existing state file
# Usage: add_cross_to_state round_num "persona-name" "cross content"
add_cross_to_state() {
  local round_num="$1"
  local persona_name="$2"
  local content="$3"
  local state_file="${TEST_DIR}/.claude/spark-state.local.md"
  printf '\n## Cross-Pollination Round %s: %s\n\n%s\n' "$round_num" "$persona_name" "$content" >> "$state_file"
}
