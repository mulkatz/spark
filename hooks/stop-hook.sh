#!/bin/bash

# Spark Stop Hook — Multi-Persona Ideation Orchestrator
#
# State machine: seed(p1) → seed(p2) → seed(p3) →
#   cross(p1) → cross(p2) → cross(p3) →
#   [round 2: cross(p1) → cross(p2) → cross(p3)] →
#   [interactive-checkpoint if --interactive] →
#   synthesize → DONE
#
# Reads state from .claude/spark-state.local.md, extracts last assistant output,
# appends it to the transcript, determines the next phase, constructs
# a persona/phase-specific prompt, and returns JSON to block exit and inject the prompt.

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Check for required dependency
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: Spark requires 'jq'. Install with: brew install jq" >&2
  exit 0
fi

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Check if spark session is active
SPARK_STATE_FILE=".claude/spark-state.local.md"

if [[ ! -f "$SPARK_STATE_FILE" ]]; then
  exit 0
fi

# Parse YAML frontmatter (only lines between first and second ---)
FRONTMATTER=$(awk '/^---$/{c++; next} c==1{print} c>=2{exit}' "$SPARK_STATE_FILE")

# Helper: extract field from YAML frontmatter (pipefail-safe)
_fm() { printf '%s\n' "$FRONTMATTER" | { grep "^${1}:" || true; } | sed "s/^${1}: *//" | tr -d '\r'; }
# Helper: extract quoted field (strips surrounding double quotes, unescapes YAML escapes)
_fmq() {
  _fm "$1" | sed 's/^"\(.*\)"$/\1/' | awk '{
    gsub(/\\\\/, "\x01")
    gsub(/\\"/, "\"")
    gsub(/\\n/, "\n")
    gsub(/\\t/, "\t")
    gsub(/\\r/, "\r")
    gsub(/\x01/, "\\")
    printf "%s", $0
  }'
}

ACTIVE=$(_fm active)
QUESTION=$(_fmq question)
PHASE=$(_fm phase)
PERSONA_INDEX=$(_fm persona_index)
ROUND=$(_fm round)
MAX_ROUNDS=$(_fm max_rounds)
PERSONAS=$(_fmq personas)
CONSTRAINTS=$(_fmq constraints)
INTERACTIVE=$(_fm interactive)
INTERACTIVE_LEVEL=$(_fmq interactive_level)
FOCUS=$(_fmq focus)
OUTPUT=$(_fmq output)

# Parse constraints into array
CONSTRAINT_LIST=()
if [[ -n "$CONSTRAINTS" ]]; then
  IFS='|' read -ra CONSTRAINT_LIST <<< "$CONSTRAINTS"
fi

# Parse persona names into array
PERSONA_NAMES=()
if [[ -n "$PERSONAS" ]]; then
  IFS='|' read -ra PERSONA_NAMES <<< "$PERSONAS"
fi
PERSONA_COUNT=${#PERSONA_NAMES[@]}

# Validate state
if [[ "$ACTIVE" != "true" ]]; then
  rm -f "$SPARK_STATE_FILE"
  exit 0
fi

if [[ ! "$PERSONA_INDEX" =~ ^[0-9]+$ ]]; then
  echo "Warning: Spark state corrupted (invalid persona_index: '$PERSONA_INDEX'). Cleaning up." >&2
  rm -f "$SPARK_STATE_FILE"
  exit 0
fi

if [[ ! "$ROUND" =~ ^[0-9]+$ ]]; then
  echo "Warning: Spark state corrupted (invalid round: '$ROUND'). Cleaning up." >&2
  rm -f "$SPARK_STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ROUNDS" =~ ^[0-9]+$ ]]; then
  echo "Warning: Spark state corrupted (invalid max_rounds: '$MAX_ROUNDS'). Cleaning up." >&2
  rm -f "$SPARK_STATE_FILE"
  exit 0
fi

# Validate phase
case "$PHASE" in
  seed|cross|synthesize|interactive-checkpoint) ;;
  *)
    echo "Warning: Spark state corrupted (invalid phase: '$PHASE'). Cleaning up." >&2
    rm -f "$SPARK_STATE_FILE"
    exit 0
    ;;
esac

# Get transcript path from hook input
TRANSCRIPT_PATH=$(printf '%s' "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "Warning: Spark transcript not found. Cleaning up." >&2
  rm -f "$SPARK_STATE_FILE"
  exit 0
fi

# Extract last assistant message from transcript (JSONL format)
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "Warning: No assistant messages in transcript. Cleaning up." >&2
  rm -f "$SPARK_STATE_FILE"
  exit 0
fi

LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)

LAST_OUTPUT=$(printf '%s' "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>/dev/null || echo "")

if [[ -z "$LAST_OUTPUT" ]]; then
  echo "Warning: Empty assistant output. Cleaning up." >&2
  rm -f "$SPARK_STATE_FILE"
  exit 0
fi

# Save the original phase/index for transcript attribution
ORIGINAL_PHASE="$PHASE"
ORIGINAL_INDEX="$PERSONA_INDEX"
ORIGINAL_ROUND="$ROUND"

# --- Append output to state file ---
# Skip transcript append for interactive-checkpoint (meta-conversation, not ideation content)

if [[ "$ORIGINAL_PHASE" == "interactive-checkpoint" ]]; then
  : # Do not append interactive-checkpoint output to transcript
elif [[ "$ORIGINAL_PHASE" == "seed" ]]; then
  PERSONA_NAME="${PERSONA_NAMES[$ORIGINAL_INDEX]}"
  printf '\n## Seed: %s\n\n%s\n' "$PERSONA_NAME" "$LAST_OUTPUT" >> "$SPARK_STATE_FILE"
elif [[ "$ORIGINAL_PHASE" == "cross" ]]; then
  PERSONA_NAME="${PERSONA_NAMES[$ORIGINAL_INDEX]}"
  printf '\n## Cross-Pollination Round %s: %s\n\n%s\n' "$ORIGINAL_ROUND" "$PERSONA_NAME" "$LAST_OUTPUT" >> "$SPARK_STATE_FILE"
elif [[ "$ORIGINAL_PHASE" == "synthesize" ]]; then
  printf '\n## Synthesis\n\n%s\n' "$LAST_OUTPUT" >> "$SPARK_STATE_FILE"
fi

# --- State Machine Transitions ---

NEXT_PHASE=""
NEXT_INDEX="$PERSONA_INDEX"
NEXT_ROUND="$ROUND"
LAST_INDEX=$((PERSONA_COUNT - 1))

case "$PHASE" in
  seed)
    if [[ "$PERSONA_INDEX" -lt "$LAST_INDEX" ]]; then
      # More personas to seed
      NEXT_PHASE="seed"
      NEXT_INDEX=$((PERSONA_INDEX + 1))
    else
      # All personas seeded → start cross-pollination
      NEXT_PHASE="cross"
      NEXT_INDEX=0
      NEXT_ROUND=1
    fi
    ;;
  cross)
    if [[ "$PERSONA_INDEX" -lt "$LAST_INDEX" ]]; then
      # More personas in this round
      NEXT_PHASE="cross"
      NEXT_INDEX=$((PERSONA_INDEX + 1))
    elif [[ "$ROUND" -lt "$MAX_ROUNDS" ]]; then
      # More rounds of cross-pollination
      if [[ "$INTERACTIVE_LEVEL" == "full" ]]; then
        NEXT_PHASE="interactive-checkpoint"
        NEXT_INDEX=0
        NEXT_ROUND="$ROUND"
      else
        NEXT_PHASE="cross"
        NEXT_INDEX=0
        NEXT_ROUND=$((ROUND + 1))
      fi
    else
      # All rounds complete
      if [[ "$INTERACTIVE" == "true" ]]; then
        NEXT_PHASE="interactive-checkpoint"
        NEXT_INDEX=0
      else
        NEXT_PHASE="synthesize"
        NEXT_INDEX=0
      fi
    fi
    ;;
  interactive-checkpoint)
    # Extract steering from the last output
    STEERING=""
    if printf '%s' "$LAST_OUTPUT" | grep -q '<spark-steering>'; then
      STEERING=$(printf '%s' "$LAST_OUTPUT" | sed -n 's/.*<spark-steering>\([^<]*\)<\/spark-steering>.*/\1/p')
    fi

    if [[ "$INTERACTIVE_LEVEL" == "full" ]] && [[ "$ROUND" -lt "$MAX_ROUNDS" ]]; then
      # Full interactive: between cross rounds, continue to next round
      NEXT_PHASE="cross"
      NEXT_INDEX=0
      NEXT_ROUND=$((ROUND + 1))
    else
      # Checkpoint: before synthesis
      NEXT_PHASE="synthesize"
      NEXT_INDEX=0
    fi
    ;;
  synthesize)
    # Session complete — build report, write result, clean up

    RESULT_FILE="${OUTPUT:-.claude/spark-result.local.md}"
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Extract session record from state file body (Seed + Cross-Pollination sections)
    SESSION_RECORD=$(awk '/^## (Seed|Cross-Pollination)/{d=1} /^## Synthesis$/{exit} d{print}' "$SPARK_STATE_FILE")

    # Build full report
    build_full_report() {
      printf '# Spark Report: %s\n\n' "$QUESTION"

      local meta
      meta=$(printf '> **Personas**: %s | **Rounds**: %s | **Date**: %s' \
        "$(echo "$PERSONAS" | tr '|' ', ')" "$ROUND" "$TIMESTAMP")
      if [[ -n "$FOCUS" ]]; then
        meta=$(printf '%s\n> **Focus**: %s' "$meta" "$FOCUS")
      fi
      printf '%s\n' "$meta"

      printf '\n---\n\n'
      printf '%s\n' "$LAST_OUTPUT"

      if [[ -n "$SESSION_RECORD" ]]; then
        printf '\n---\n\n'
        printf '## Session Record\n\n'
        printf '%s\n' "$SESSION_RECORD"
      fi
    }

    # Ensure parent directory exists
    mkdir -p "$(dirname "$RESULT_FILE")"

    # Write result
    TEMP_RESULT="${RESULT_FILE}.tmp.$$"
    if [[ "$RESULT_FILE" == *.html ]]; then
      REPORT_SCRIPT="${PLUGIN_ROOT}/scripts/generate-report.mjs"
      if command -v bun >/dev/null 2>&1 && [[ -f "$REPORT_SCRIPT" ]]; then
        build_full_report | bun "$REPORT_SCRIPT" > "$TEMP_RESULT"
      else
        {
          printf '<!-- WARNING: HTML conversion unavailable (bun not found). Markdown output below. -->\n\n'
          build_full_report
        } > "$TEMP_RESULT"
      fi
    else
      build_full_report > "$TEMP_RESULT"
    fi
    mv "$TEMP_RESULT" "$RESULT_FILE"

    rm -f "$SPARK_STATE_FILE"
    echo "Spark session complete. Result saved to $RESULT_FILE"
    exit 0
    ;;
esac

# Update state file frontmatter
TEMP_FILE="${SPARK_STATE_FILE}.tmp.$$"
awk -v next_phase="$NEXT_PHASE" -v next_index="$NEXT_INDEX" -v next_round="$NEXT_ROUND" '
  /^---$/ { count++ }
  count <= 1 && /^phase: / { print "phase: " next_phase; next }
  count <= 1 && /^persona_index: / { print "persona_index: " next_index; next }
  count <= 1 && /^round: / { print "round: " next_round; next }
  { print }
' "$SPARK_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$SPARK_STATE_FILE"

# --- Construct Next Prompt ---

# Extract ideation transcript (only ## Seed / ## Cross-Pollination sections, excluding persona descriptions and context)
IDEATION_TRANSCRIPT=$(awk '/^## (Seed|Cross-Pollination)/{d=1} d{print}' "$SPARK_STATE_FILE")
# Full body (for interactive checkpoint which needs context too)
FULL_BODY=$(awk '/^---$/{i++; next} i>=2' "$SPARK_STATE_FILE")

# Get persona description from state file
get_persona_desc() {
  local name="$1"
  awk -v name="$name" '
    index($0, "<!-- persona:" name " -->") > 0 { found=1; next }
    /<!-- \/persona -->/ { if(found) exit }
    found { print }
  ' "$SPARK_STATE_FILE"
}

# Handle interactive-checkpoint prompt
if [[ "$NEXT_PHASE" == "interactive-checkpoint" ]]; then
  CHECKPOINT_PROMPT="# Cross-Pollination Complete — Interactive Checkpoint

Summarize the ideation session so far:
1. **Seed phase highlights** — What were the most distinctive ideas from each persona? (2-3 bullets per persona)
2. **Cross-pollination highlights** — What surprising combinations emerged? (3-5 bullets)
3. **Theme clusters** — Group the ideas into 2-4 clusters with the strongest idea in each

Then ask the user how they want to steer synthesis. Use the AskUserQuestion tool with these options:
- \"Continue to synthesis\" — proceed with the full idea set
- \"Focus synthesis\" — provide a specific direction or constraint for what to prioritize
- \"Add a constraint\" — inject a new constraint or perspective before synthesis

After receiving the user's response, output exactly one of these tags at the END of your response:
- If the user wants to continue: \`<spark-steering>none</spark-steering>\`
- If the user provides direction: \`<spark-steering>THEIR DIRECTION HERE</spark-steering>\`

## Session so far

$FULL_BODY"

  if [[ "$INTERACTIVE_LEVEL" == "full" ]] && [[ "$ROUND" -lt "$MAX_ROUNDS" ]]; then
    SYSTEM_MSG="Spark: INTERACTIVE CHECKPOINT — cross-pollination round $ROUND complete, awaiting user steering"
  else
    SYSTEM_MSG="Spark: INTERACTIVE CHECKPOINT — ideation complete, awaiting user steering"
  fi

  jq -n \
    --arg prompt "$CHECKPOINT_PROMPT" \
    --arg msg "$SYSTEM_MSG" \
    '{
      "decision": "block",
      "reason": $prompt,
      "systemMessage": $msg
    }'
  exit 0
fi

# If we just came from interactive-checkpoint with steering, inject it
STEERING_BLOCK=""
if [[ "$PHASE" == "interactive-checkpoint" ]] && [[ -n "${STEERING:-}" ]] && [[ "$STEERING" != "none" ]]; then
  STEERING_BLOCK="
## User Steering Directive

The user has directed the synthesis to focus on: **$STEERING**

Incorporate this directive into your synthesis. Prioritize ideas and connections related to this direction."
fi

# --- Build prompt for next phase ---

NEXT_PERSONA_NAME="${PERSONA_NAMES[$NEXT_INDEX]}"
NEXT_PERSONA_DESC=$(get_persona_desc "$NEXT_PERSONA_NAME")
if [[ -z "$NEXT_PERSONA_DESC" ]]; then
  NEXT_PERSONA_DESC="$NEXT_PERSONA_NAME"
fi

# Get constraint for a persona index (read from state file, selected at setup time with duplicate avoidance)
get_constraint_for_index() {
  local idx="$1"
  if [[ "$idx" -lt "${#CONSTRAINT_LIST[@]}" ]]; then
    echo "${CONSTRAINT_LIST[$idx]}"
  else
    echo "What if the obvious approach is completely wrong?"
  fi
}

if [[ "$NEXT_PHASE" == "seed" ]]; then
  # SEED: persona description + seed prompt (with constraint) + topic
  # CRITICAL: NO transcript! This enforces independent generation.
  SEED_PROMPT=$(cat "$PLUGIN_ROOT/prompts/phases/seed.md")
  CONSTRAINT=$(get_constraint_for_index "$NEXT_INDEX")
  SEED_PROMPT="${SEED_PROMPT//\[INJECT_CONSTRAINT\]/$CONSTRAINT}"

  FULL_PROMPT="# Persona: $NEXT_PERSONA_NAME

$NEXT_PERSONA_DESC

---

$SEED_PROMPT

$QUESTION"

  if [[ -n "$FOCUS" ]]; then
    FULL_PROMPT="$FULL_PROMPT

## Focus Lens: $FOCUS

Channel your ideation through this lens. How does your persona's perspective intersect with: **$FOCUS**?"
  fi

  FULL_PROMPT="$FULL_PROMPT

You are Persona $((NEXT_INDEX + 1)) of $PERSONA_COUNT. Generate your ideas independently — you have NOT seen what others think."

elif [[ "$NEXT_PHASE" == "cross" ]]; then
  # CROSS: persona description + cross-pollinate prompt + topic + FULL transcript
  CROSS_PROMPT=$(cat "$PLUGIN_ROOT/prompts/phases/cross-pollinate.md")

  FULL_PROMPT="# Persona: $NEXT_PERSONA_NAME

$NEXT_PERSONA_DESC

---

$CROSS_PROMPT

$QUESTION"

  if [[ -n "$FOCUS" ]]; then
    FULL_PROMPT="$FULL_PROMPT

## Focus Lens: $FOCUS

Channel your cross-pollination through this lens. How does **$FOCUS** influence which ideas you transform?"
  fi

  FULL_PROMPT="$FULL_PROMPT

## Ideas from all personas

$IDEATION_TRANSCRIPT

---

You are Persona $((NEXT_INDEX + 1)) of $PERSONA_COUNT in Cross-Pollination Round $NEXT_ROUND of $MAX_ROUNDS. Transform and combine — don't just agree."

elif [[ "$NEXT_PHASE" == "synthesize" ]]; then
  # SYNTHESIZE: synthesize prompt + topic + FULL transcript
  SYNTH_PROMPT=$(cat "$PLUGIN_ROOT/prompts/phases/synthesize.md")

  FULL_PROMPT="$SYNTH_PROMPT

$QUESTION"

  if [[ -n "$FOCUS" ]]; then
    FULL_PROMPT="$FULL_PROMPT

## Focus Lens: $FOCUS

Weight your synthesis toward ideas and connections related to: **$FOCUS**"
  fi

  if [[ -n "$STEERING_BLOCK" ]]; then
    FULL_PROMPT="$FULL_PROMPT
$STEERING_BLOCK"
  fi

  FULL_PROMPT="$FULL_PROMPT

## Full session transcript

$IDEATION_TRANSCRIPT

---

Produce the final synthesis report. Rank honestly — not everything is a 5/5."
fi

# Build system message
if [[ "$NEXT_PHASE" == "seed" ]]; then
  SYSTEM_MSG="Spark: SEED phase — $NEXT_PERSONA_NAME ($((NEXT_INDEX + 1)) of $PERSONA_COUNT)"
elif [[ "$NEXT_PHASE" == "cross" ]]; then
  SYSTEM_MSG="Spark: CROSS-POLLINATE phase — $NEXT_PERSONA_NAME (Round $NEXT_ROUND, $((NEXT_INDEX + 1)) of $PERSONA_COUNT)"
elif [[ "$NEXT_PHASE" == "synthesize" ]]; then
  SYSTEM_MSG="Spark: SYNTHESIZE phase — produce final structured report"
fi

# Output JSON to block exit and inject next prompt
jq -n \
  --arg prompt "$FULL_PROMPT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
