#!/usr/bin/env bats
# Shellcheck lint integration tests

load "../helpers/setup"

@test "setup-spark.sh passes shellcheck" {
  run shellcheck -s bash "$PLUGIN_ROOT/scripts/setup-spark.sh"
  assert_success
}

@test "stop-hook.sh passes shellcheck" {
  run shellcheck -s bash "$PLUGIN_ROOT/hooks/stop-hook.sh"
  assert_success
}
