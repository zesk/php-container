#!/usr/bin/env bash
#
# Test-related to php-container
#
# Copyright &copy; 2025 Market Acumen, Inc.
#

testContainerBuild() {
  local usage="_return"

  local home

  home=$(catchEnvironment "$usage" buildHome) || return $?

  matches=(
    --stderr-match "db  Built"
    --stderr-match "web  Built"
  )
  assertExitCode --line "$LINENO" "${matches[@]}" 0 "$home/bin/tools.sh" phpContainerCompose --build || return $?
}
