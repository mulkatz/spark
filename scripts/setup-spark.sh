#!/bin/bash

# Spark Setup — Parse arguments, create state file, output initial prompt
# Called by the /spark command via commands/spark.md

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Defaults
ROUNDS=1
FOCUS=""
CONTEXT_PATHS=()
INTERACTIVE=false
INTERACTIVE_LEVEL=""
OUTPUT=""
PERSONAS=()
QUESTION_PARTS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --personas)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --personas requires a value (comma-separated names or custom:description)" >&2
        exit 1
      fi
      # Split comma-separated personas (with special handling for linkedin: which may contain commas)
      IFS=',' read -ra RAW_PERSONA_ARGS <<< "$2"
      _pi=0
      while [[ $_pi -lt ${#RAW_PERSONA_ARGS[@]} ]]; do
        _p=$(printf '%s' "${RAW_PERSONA_ARGS[$_pi]}" | sed 's/^ *//;s/ *$//')
        if [[ "$_p" == linkedin:* ]]; then
          # LinkedIn references may contain commas — consume subsequent segments
          # until we hit something that looks like a new persona
          _combined="$_p"
          _pj=$((_pi + 1))
          while [[ $_pj -lt ${#RAW_PERSONA_ARGS[@]} ]]; do
            _next=$(printf '%s' "${RAW_PERSONA_ARGS[$_pj]}" | sed 's/^ *//;s/ *$//')
            # Stop if this segment starts a new persona (custom:, linkedin:, or valid preset)
            if [[ "$_next" == custom:* ]] || [[ "$_next" == linkedin:* ]] || [[ -f "$PLUGIN_ROOT/prompts/personas/${_next}.md" ]]; then
              break
            fi
            _combined="$_combined, $_next"
            _pj=$((_pj + 1))
          done
          PERSONAS+=("$_combined")
          _pi=$_pj
        else
          if [[ -n "$_p" ]]; then
            PERSONAS+=("$_p")
          fi
          _pi=$((_pi + 1))
        fi
      done
      shift 2
      ;;
    --rounds)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --rounds requires a number (1-3)" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --rounds must be a positive integer (got: '$2')" >&2
        exit 1
      fi
      ROUNDS="$2"
      shift 2
      ;;
    --interactive=full)
      INTERACTIVE=true
      INTERACTIVE_LEVEL="full"
      shift
      ;;
    --interactive)
      INTERACTIVE=true
      INTERACTIVE_LEVEL="checkpoint"
      shift
      ;;
    --focus)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --focus requires a value (e.g., \"business model\", \"user experience\")" >&2
        exit 1
      fi
      FOCUS="$2"
      shift 2
      ;;
    --context)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --context requires a path (file or directory)" >&2
        exit 1
      fi
      CONTEXT_PATHS+=("$2")
      shift 2
      ;;
    --output)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --output requires a file path" >&2
        exit 1
      fi
      OUTPUT="$2"
      shift 2
      ;;
    *)
      QUESTION_PARTS+=("$1")
      shift
      ;;
  esac
done

QUESTION="${QUESTION_PARTS[*]:-}"

# Validate topic
if [[ -z "$QUESTION" ]]; then
  echo "Error: No topic provided." >&2
  echo "" >&2
  echo "Usage: /spark \"How can we make remote work more creative?\" [--personas NAME,...] [--rounds N]" >&2
  exit 1
fi

# Validate rounds
if [[ "$ROUNDS" -lt 1 ]] || [[ "$ROUNDS" -gt 3 ]]; then
  echo "Error: --rounds must be between 1 and 3 (got: $ROUNDS)" >&2
  exit 1
fi

# Validate persona names
PERSONA_COUNT=${#PERSONAS[@]}
if [[ "$PERSONA_COUNT" -gt 0 ]]; then
  for pname in "${PERSONAS[@]}"; do
    # Check for pipe separator (reserved)
    if [[ "$pname" == *"|"* ]]; then
      echo "Error: persona name cannot contain '|' (reserved separator): $pname" >&2
      exit 1
    fi
    # Check for HTML comment markers
    if [[ "$pname" == *"<!--"* ]] || [[ "$pname" == *"-->"* ]]; then
      echo "Error: persona name cannot contain HTML comment markers: $pname" >&2
      exit 1
    fi
    # Skip custom: prefix for file validation
    if [[ "$pname" == custom:* ]]; then
      # Custom persona — validate description is not empty
      local_desc="${pname#custom:}"
      if [[ -z "$local_desc" ]]; then
        echo "Error: custom persona requires a description (custom:Your description here)" >&2
        exit 1
      fi
      continue
    fi
    # Skip linkedin: prefix for file validation
    if [[ "$pname" == linkedin:* ]]; then
      local_ref="${pname#linkedin:}"
      if [[ -z "$local_ref" ]]; then
        echo "Error: linkedin persona requires a URL or name (linkedin:URL or linkedin:Name, Title)" >&2
        exit 1
      fi
      continue
    fi
    # Validate preset persona exists
    preset_file="$PLUGIN_ROOT/prompts/personas/${pname}.md"
    if [[ ! -f "$preset_file" ]]; then
      echo "Error: Unknown persona '$pname'. Available presets:" >&2
      for f in "$PLUGIN_ROOT"/prompts/personas/*.md; do
        echo "  - $(basename "$f" .md)" >&2
      done
      exit 1
    fi
  done
fi

# Validate context paths
for ctx_path in "${CONTEXT_PATHS[@]+"${CONTEXT_PATHS[@]}"}"; do
  if [[ ! -e "$ctx_path" ]]; then
    echo "Error: Context path not found: $ctx_path" >&2
    exit 1
  fi
done

# Check for existing active session
SPARK_STATE_FILE=".claude/spark-state.local.md"
if [[ -f "$SPARK_STATE_FILE" ]]; then
  echo "Error: A Spark session is already active." >&2
  echo "Use /spark-cancel to cancel it, or /spark-status to check progress." >&2
  exit 1
fi

# --- Persona Selection ---

# Available persona presets
AVAILABLE_PERSONAS=()
for f in "$PLUGIN_ROOT"/prompts/personas/*.md; do
  AVAILABLE_PERSONAS+=("$(basename "$f" .md)")
done

# Auto-select 3 personas if none specified
if [[ "$PERSONA_COUNT" -eq 0 ]]; then
  if [[ ${#AVAILABLE_PERSONAS[@]} -lt 3 ]]; then
    echo "Error: At least 3 persona files are required in prompts/personas/ (found: ${#AVAILABLE_PERSONAS[@]})" >&2
    exit 1
  fi
  # Portable random shuffle: awk with srand + sort + head
  SELECTED=$(printf '%s\n' "${AVAILABLE_PERSONAS[@]}" | awk 'BEGIN{srand()}{print rand()"\t"$0}' | sort -n | cut -f2 | head -3)
  while IFS= read -r p; do
    PERSONAS+=("$p")
  done <<< "$SELECTED"
  PERSONA_COUNT=${#PERSONAS[@]}
fi

# Resolve persona descriptions
PERSONA_NAMES=()
PERSONA_DESCRIPTIONS=()
for persona in "${PERSONAS[@]}"; do
  if [[ "$persona" == custom:* ]]; then
    # Custom persona — use description directly
    local_desc="${persona#custom:}"
    PERSONA_NAMES+=("$persona")
    PERSONA_DESCRIPTIONS+=("$local_desc")
  elif [[ "$persona" == linkedin:* ]]; then
    # LinkedIn persona — placeholder description, will be generated in persona_gen phase
    local_ref="${persona#linkedin:}"
    PERSONA_NAMES+=("$persona")
    PERSONA_DESCRIPTIONS+=("[Persona to be researched and generated from: $local_ref]")
  else
    preset_file="$PLUGIN_ROOT/prompts/personas/${persona}.md"
    if [[ -f "$preset_file" ]]; then
      PERSONA_NAMES+=("$persona")
      PERSONA_DESCRIPTIONS+=("$(cat "$preset_file")")
    else
      PERSONA_NAMES+=("$persona")
      PERSONA_DESCRIPTIONS+=("$persona")
    fi
  fi
done

# --- LinkedIn Persona Detection ---
# Identify which persona indices need generation (linkedin: personas)

GEN_INDICES=()
for i in $(seq 0 $((PERSONA_COUNT - 1))); do
  if [[ "${PERSONA_NAMES[$i]}" == linkedin:* ]]; then
    GEN_INDICES+=("$i")
  fi
done
GEN_INDICES_STR=""
if [[ ${#GEN_INDICES[@]} -gt 0 ]]; then
  GEN_INDICES_STR=$(IFS='|'; echo "${GEN_INDICES[*]}")
fi

# --- Display Name Helper ---
# Strips custom:/linkedin: prefixes for human-readable output

display_name() {
  local name="$1"
  if [[ "$name" == custom:* ]]; then
    echo "Custom Perspective"
  elif [[ "$name" == linkedin:* ]]; then
    local ref="${name#linkedin:}"
    if [[ "$ref" == http* ]]; then
      echo "$ref" | sed 's|.*/in/||;s|/.*||;s|-| |g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1'
    else
      echo "${ref%%,*}"
    fi
  else
    echo "$name"
  fi
}

# --- Random Constraint Selection ---
# Oblique-strategy-inspired constraints for the Seed phase.
# Each persona gets a unique constraint to break fixation.

CONSTRAINTS=(
  "What if this had to work without any technology?"
  "What if a child had to understand and use this?"
  "What if this needed to work in complete silence?"
  "What if the solution had to be beautiful, not just functional?"
  "What if you could only solve this by removing something?"
  "What if this had to work in reverse — starting from the end?"
  "What if the most important user is someone who hates this?"
  "What if this had to fit on a single piece of paper?"
  "What if this needed to work across 100 years?"
  "What if the solution had to make people laugh?"
  "What if this had to work with zero budget?"
  "What if you could only use materials found in nature?"
  "What if the first version had to be built in one day?"
  "What if this had to work for exactly one person, perfectly?"
  "What if the solution had to be invisible?"
  "What if this needed to create a ritual or habit?"
  "What if the opposite of the obvious approach is better?"
  "What if this had to work during a power outage?"
)

# Select unique constraints (one per persona, no duplicates)
SELECTED_CONSTRAINTS=()
CONSTRAINT_INDICES=()
for i in $(seq 0 $((PERSONA_COUNT - 1))); do
  while true; do
    idx=$((RANDOM % ${#CONSTRAINTS[@]}))
    # Check for duplicate
    duplicate=false
    for used in "${CONSTRAINT_INDICES[@]+"${CONSTRAINT_INDICES[@]}"}"; do
      if [[ "$used" -eq "$idx" ]]; then
        duplicate=true
        break
      fi
    done
    if [[ "$duplicate" == "false" ]]; then
      CONSTRAINT_INDICES+=("$idx")
      SELECTED_CONSTRAINTS+=("${CONSTRAINTS[$idx]}")
      break
    fi
  done
done

# --- Context Generation ---

CONTEXT_MAX_CHARS=5000
CONTEXT_BODY=""
CONTEXT_SOURCE=""

# Generate context summary for a directory
generate_dir_context() {
  local dir_path="$1"
  local output=""

  output+="### Directory: $dir_path"$'\n\n'
  output+='```'$'\n'
  if command -v tree >/dev/null 2>&1; then
    output+="$(tree -L 3 --noreport "$dir_path" 2>/dev/null | head -50)"
  else
    output+="$(find "$dir_path" -maxdepth 3 -type f 2>/dev/null | sort | head -50)"
  fi
  output+=$'\n''```'$'\n\n'

  output+="**Key declarations:**"$'\n''```'$'\n'
  output+="$(grep -rn --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
    --include='*.py' --include='*.go' --include='*.rs' --include='*.java' --include='*.rb' \
    --include='*.swift' --include='*.kt' --include='*.cs' --include='*.sh' \
    -E '^\s*(export\s+)?(class |interface |type |enum |function |def |fn |func |pub |struct |trait |const |let |var |async function )' \
    "$dir_path" 2>/dev/null | head -40 || echo "(no declarations found)")"
  output+=$'\n''```'$'\n'

  printf '%s' "$output"
}

# Generate context summary for a file
generate_file_context() {
  local file_path="$1"
  local output=""
  local line_count
  line_count=$(wc -l < "$file_path" 2>/dev/null | tr -d ' ' || echo "0")

  output+="### File: $file_path ($line_count lines)"$'\n\n'
  output+='```'$'\n'
  if [[ "$line_count" -gt 150 ]]; then
    output+="$(head -150 "$file_path")"
    output+=$'\n'"... (truncated, $line_count total lines)"
  else
    output+="$(cat "$file_path")"
  fi
  output+=$'\n''```'$'\n'

  printf '%s' "$output"
}

# Build context if any context source specified
HAS_CONTEXT=false
if [[ ${#CONTEXT_PATHS[@]} -gt 0 ]]; then
  HAS_CONTEXT=true
  CONTEXT_BODY="## Context"$'\n'

  for ctx_path in "${CONTEXT_PATHS[@]+"${CONTEXT_PATHS[@]}"}"; do
    if [[ -d "$ctx_path" ]]; then
      CONTEXT_BODY+=$'\n'"$(generate_dir_context "$ctx_path")"$'\n'
      CONTEXT_SOURCE+="${ctx_path} "
    elif [[ -f "$ctx_path" ]]; then
      CONTEXT_BODY+=$'\n'"$(generate_file_context "$ctx_path")"$'\n'
      CONTEXT_SOURCE+="${ctx_path} "
    fi
  done

  # Truncate context if too long
  CONTEXT_LEN=${#CONTEXT_BODY}
  if [[ "$CONTEXT_LEN" -gt "$CONTEXT_MAX_CHARS" ]]; then
    CONTEXT_BODY="${CONTEXT_BODY:0:$CONTEXT_MAX_CHARS}"$'\n\n'"*... (context truncated at $CONTEXT_MAX_CHARS chars)*"
  fi

  CONTEXT_SOURCE=$(printf '%s' "$CONTEXT_SOURCE" | sed 's/ $//')
fi

# Create .claude directory if needed
mkdir -p .claude

# Escape strings for YAML double-quoted values
yaml_escape() {
  local s="$1"
  s="${s//\\/\\\\}"    # \ → \\  (must be first)
  s="${s//\"/\\\"}"    # " → \"
  s="${s//$'\n'/\\n}"  # newline → \n
  s="${s//$'\t'/\\t}"  # tab → \t
  s="${s//$'\r'/\\r}"  # CR → \r
  printf '%s' "$s"
}

# Escape question for YAML
QUESTION_YAML="\"$(yaml_escape "$QUESTION")\""

# Build personas YAML value (pipe-separated for easy parsing)
PERSONAS_YAML=$(IFS='|'; echo "${PERSONA_NAMES[*]}")

# Generate default output path if not specified
if [[ -z "$OUTPUT" ]]; then
  slug=$(printf '%s' "$QUESTION" | LC_ALL=C tr -dc 'A-Za-z0-9 ' | head -c 50 | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-' | sed 's/^-//; s/-$//')
  slug="${slug:-ideation}"
  OUTPUT="$HOME/Desktop/spark-$(date +%Y-%m-%d)-${slug}.html"
fi

# Create state file
# Build constraints YAML value (pipe-separated)
CONSTRAINTS_YAML=$(IFS='|'; echo "${SELECTED_CONSTRAINTS[*]}")

# Determine initial phase
INITIAL_PHASE="seed"
if [[ -n "$GEN_INDICES_STR" ]]; then
  INITIAL_PHASE="persona_gen"
fi

cat > "$SPARK_STATE_FILE" <<EOF
---
active: true
question: $QUESTION_YAML
phase: $INITIAL_PHASE
persona_index: 0
round: 1
max_rounds: $ROUNDS
personas: "$(yaml_escape "$PERSONAS_YAML")"
constraints: "$(yaml_escape "$CONSTRAINTS_YAML")"
interactive: $INTERACTIVE
interactive_level: "$(yaml_escape "$INTERACTIVE_LEVEL")"
focus: "$(yaml_escape "$FOCUS")"
context_source: "$(yaml_escape "$CONTEXT_SOURCE")"
output: "$(yaml_escape "$OUTPUT")"
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
gen_indices: "$(yaml_escape "$GEN_INDICES_STR")"
gen_current: 0
---
EOF

# Append persona descriptions to state file body
for i in $(seq 0 $((PERSONA_COUNT - 1))); do
  printf '\n<!-- persona:%s -->\n%s\n<!-- /persona -->\n' "${PERSONA_NAMES[$i]}" "${PERSONA_DESCRIPTIONS[$i]}" >> "$SPARK_STATE_FILE"
done

# Append context to state file body
if [[ "$HAS_CONTEXT" == "true" ]]; then
  printf '\n%s\n' "$CONTEXT_BODY" >> "$SPARK_STATE_FILE"
fi

# Build display names for banner
DISPLAY_NAMES=()
for pn in "${PERSONA_NAMES[@]}"; do
  DISPLAY_NAMES+=("$(display_name "$pn")")
done

# Build the initial prompt
echo ""
echo "============================================================"
echo "  SPARK — Collaborative Ideation"
echo "============================================================"
echo ""
echo "  Topic:       $QUESTION"
echo "  Personas:    ${DISPLAY_NAMES[*]}"
echo "  Rounds:      $ROUNDS"
if [[ -n "$FOCUS" ]]; then
  echo "  Focus:       $FOCUS"
fi
if [[ "$HAS_CONTEXT" == "true" ]]; then
  echo "  Context:     $CONTEXT_SOURCE"
fi
echo "  Output:      $OUTPUT"
if [[ "$INTERACTIVE" == "true" ]]; then
  echo "  Interactive: ENABLED ($INTERACTIVE_LEVEL)"
fi
echo ""

if [[ "$INITIAL_PHASE" == "persona_gen" ]]; then
  # Persona generation phase — research LinkedIn personas first
  FIRST_GEN_INDEX="${GEN_INDICES[0]}"
  FIRST_GEN_PERSONA="${PERSONA_NAMES[$FIRST_GEN_INDEX]}"
  FIRST_GEN_REF="${FIRST_GEN_PERSONA#linkedin:}"
  FIRST_GEN_DISPLAY="$(display_name "$FIRST_GEN_PERSONA")"

  echo "  Phase:       PERSONA GENERATION — $FIRST_GEN_DISPLAY (1 of ${#GEN_INDICES[@]})"
  echo ""
  echo "  The session will cycle through:"
  echo "    Persona Generation (research LinkedIn personas) →"
  echo "    Seed (each persona independently) →"
  echo "    Cross-Pollinate (SCAMPER transformations) →"
  if [[ "$ROUNDS" -gt 1 ]]; then
    echo "    [× $ROUNDS rounds of cross-pollination] →"
  fi
  echo "    Synthesize (pattern recognition + ranking)"
  echo ""
  echo "============================================================"
  echo ""

  # Read persona_gen prompt template
  PERSONA_GEN_PROMPT=$(cat "$PLUGIN_ROOT/prompts/phases/persona-gen.md")

  echo "$PERSONA_GEN_PROMPT"
  echo ""
  echo "## Person to Research"
  echo ""
  echo "> $FIRST_GEN_REF"
else
  # Standard seed phase
  FIRST_PERSONA="${PERSONA_NAMES[0]}"
  FIRST_DESC="${PERSONA_DESCRIPTIONS[0]}"
  FIRST_CONSTRAINT="${SELECTED_CONSTRAINTS[0]}"

  # Read seed phase prompt and inject constraint
  SEED_PROMPT=$(cat "$PLUGIN_ROOT/prompts/phases/seed.md")
  SEED_PROMPT="${SEED_PROMPT//\[INJECT_CONSTRAINT\]/$FIRST_CONSTRAINT}"

  FIRST_DISPLAY="$(display_name "$FIRST_PERSONA")"

  echo "  Phase:       SEED — $FIRST_DISPLAY (1 of $PERSONA_COUNT)"
  echo ""
  echo "  The session will cycle through:"
  echo "    Seed (each persona independently) →"
  echo "    Cross-Pollinate (SCAMPER transformations) →"
  if [[ "$ROUNDS" -gt 1 ]]; then
    echo "    [× $ROUNDS rounds of cross-pollination] →"
  fi
  echo "    Synthesize (pattern recognition + ranking)"
  echo ""
  echo "============================================================"
  echo ""

  # Enhanced custom persona template
  if [[ "$FIRST_PERSONA" == custom:* ]]; then
    echo "# Your Persona"
    echo ""
    echo "You are embodying a unique character for this brainstorming session."
    echo "Fully inhabit this persona based on the following seed:"
    echo ""
    echo "> $FIRST_DESC"
    echo ""
    echo "Build your character completely:"
    echo "- What is your fundamental worldview?"
    echo "- What vocabulary, metaphors, and thinking patterns come naturally to you?"
    echo "- What do you focus on that others might miss?"
    echo "- What are your blind spots and biases?"
    echo ""
    echo "Stay in character throughout. Every idea should feel like it could only"
    echo "come from someone with YOUR specific background and worldview."
  else
    echo "# Persona: $FIRST_PERSONA"
    echo ""
    echo "$FIRST_DESC"
  fi
  echo ""
  echo "---"
  echo ""
  echo "$SEED_PROMPT"
  echo ""
  echo "$QUESTION"
  if [[ -n "$FOCUS" ]]; then
    echo ""
    echo "## Focus Lens: $FOCUS"
    echo ""
    echo "Channel your ideation through this lens. How does your persona's perspective intersect with: **$FOCUS**?"
  fi
  if [[ "$HAS_CONTEXT" == "true" ]]; then
    echo ""
    printf '%s\n' "$CONTEXT_BODY"
  fi
  echo ""
  echo "You are Persona 1 of $PERSONA_COUNT. Generate your ideas independently — you have NOT seen what others think."
fi
