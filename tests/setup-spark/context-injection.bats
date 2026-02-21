#!/usr/bin/env bats
# Tests for setup-spark.sh context injection

load "../helpers/setup"
load "../helpers/assertions"

# Helper to run setup in isolated dir
run_setup() {
  run bash -c 'cd "$1" && shift && "$@"' _ "$TEST_DIR" "$SETUP_SCRIPT" "$@"
}

@test "file context is included in state file" {
  # Create a test file for context
  echo "some test content" > "$TEST_DIR/test-context.txt"

  run_setup --personas "theater-director,urban-planner,architect" --context "$TEST_DIR/test-context.txt" "Test topic"
  assert_success

  assert_state_body_contains "test-context.txt"
  assert_state_body_contains "some test content"
}

@test "directory context is included in state file" {
  # Create test directory with a file
  mkdir -p "$TEST_DIR/test-dir"
  echo "dir content" > "$TEST_DIR/test-dir/file.txt"

  run_setup --personas "theater-director,urban-planner,architect" --context "$TEST_DIR/test-dir" "Test topic"
  assert_success

  assert_state_body_contains "test-dir"
}

@test "multiple context paths are all included" {
  echo "file one content" > "$TEST_DIR/ctx1.txt"
  echo "file two content" > "$TEST_DIR/ctx2.txt"

  run_setup --personas "theater-director,urban-planner,architect" --context "$TEST_DIR/ctx1.txt" --context "$TEST_DIR/ctx2.txt" "Test topic"
  assert_success

  assert_state_body_contains "file one content"
  assert_state_body_contains "file two content"
}

@test "context source is recorded in frontmatter" {
  echo "test" > "$TEST_DIR/my-file.txt"

  run_setup --personas "theater-director,urban-planner,architect" --context "$TEST_DIR/my-file.txt" "Test topic"
  assert_success

  local ctx
  ctx=$(get_frontmatter "context_source" "$(state_file)")
  [[ "$ctx" == *"my-file.txt"* ]]
}

@test "large context is truncated" {
  # Create a large file (> 5000 chars)
  python3 -c "print('x' * 6000)" > "$TEST_DIR/large.txt"

  run_setup --personas "theater-director,urban-planner,architect" --context "$TEST_DIR/large.txt" "Test topic"
  assert_success

  assert_state_body_contains "truncated"
}
