#!/usr/bin/env bash
# Transcript and hook-input JSON generators for Spark stop-hook tests
#
# The stop hook reads:
# 1. Hook input JSON from stdin (contains transcript_path)
# 2. The transcript file (JSONL with assistant messages)

# Create a JSONL transcript file with assistant messages
# Usage: create_transcript "message1" ["message2" ...]
# Returns: path to the transcript file
create_transcript() {
  local transcript_file="${BATS_TEST_TMPDIR}/transcript-${RANDOM}.jsonl"

  for msg in "$@"; do
    local json_text
    json_text=$(printf '%s' "$msg" | jq -Rs '.')
    printf '{"role":"assistant","message":{"content":[{"type":"text","text":%s}]}}\n' \
      "$json_text" >> "$transcript_file"
  done

  echo "$transcript_file"
}

# Create a transcript with a single assistant message containing raw text
# Usage: create_transcript_raw <<'EOF'
#   multi-line content here
# EOF
# Returns: path to transcript file via TRANSCRIPT_FILE variable
create_transcript_raw() {
  TRANSCRIPT_FILE="${BATS_TEST_TMPDIR}/transcript-${RANDOM}.jsonl"
  local content
  content=$(cat)

  local json_text
  json_text=$(printf '%s' "$content" | jq -Rs '.')

  printf '{"role":"assistant","message":{"content":[{"type":"text","text":%s}]}}\n' \
    "$json_text" > "$TRANSCRIPT_FILE"

  echo "$TRANSCRIPT_FILE"
}

# Create the hook input JSON that the stop hook expects on stdin
# Usage: create_hook_input "/path/to/transcript.jsonl"
# Returns: the JSON string
create_hook_input() {
  local transcript_path="$1"
  jq -n --arg path "$transcript_path" '{"transcript_path": $path}'
}

# Convenience: create transcript + hook input in one call
# Usage: setup_hook_input "assistant message"
# Sets: HOOK_INPUT (to pipe into stop hook), TRANSCRIPT_PATH
setup_hook_input() {
  TRANSCRIPT_PATH=$(create_transcript "$@")
  HOOK_INPUT=$(create_hook_input "$TRANSCRIPT_PATH")
}

# Run the stop hook with the given hook input via bats `run`
# bats `run` doesn't support piped stdin, so we wrap in bash -c
# Usage: run_stop_hook
# Requires: HOOK_INPUT and TEST_DIR to be set
run_stop_hook() {
  run bash -c 'cd "$1" && printf "%s" "$2" | "$3"' _ "$TEST_DIR" "$HOOK_INPUT" "$STOP_HOOK"
}
