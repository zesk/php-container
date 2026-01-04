#!/usr/bin/env bash
#
# Test-related to php-container
#
# Copyright &copy; 2026 Market Acumen, Inc.
#

testContainerBuild() {
  local usage="_return"

  local home

  home=$(catchEnvironment "$usage" buildHome) || return $?

  matches=(
    --stderr-match "db  Built"
    --stderr-match "web  Built"
  )
  assertExitCode "${matches[@]}" 0 "$home/bin/tools.sh" phpContainerCompose --build || return $?
}
