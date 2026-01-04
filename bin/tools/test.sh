#!/usr/bin/env bash
#
# Copyright &copy; 2026 Market Acumen, Inc.
#

# Run bash tests
phpContainerTestPHPUnit() {
  local handler="_${FUNCNAME[0]}"
  local testHome

  testHome="$(catchEnvironment "$handler" buildHome)" || return $?
  [ -d "$testHome/test" ] || throwArgument "$handler" "Missing test directory" || return $?
  local bin="$testHome/vendor/bin/phpunit"
  [ -x "$bin" ] || throwArgument "$handler" "Missing phpunit binary: $(decorate file "$bin")" || return $?

  XDEBUG_ENABLED=true XDEBUG_MODE=coverage catchEnvironment "$handler" "$bin" "$@" || return $?
}
_phpContainerTestPHPUnit() {
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

phpContainerTestBash() {
  local handler="_${FUNCNAME[0]}"
  local testHome

  testHome="$(catchEnvironment "$handler" buildHome)" || return $?
  [ -d "$testHome/test" ] || throwArgument "$handler" "Missing test directory" || return $?

  # Include our own test support files if needed
  [ ! -d "$testHome/test/support" ] || catchEnvironment "$handler" bashSourcePath "$testHome/test/support" || return $?

  catchEnvironment "$handler" testTools testSuite --tests "$testHome/test/tests/" "$@" || return $?
}
_phpContainerTestBash() {
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

phpContainerTest() {
  local handler="_${FUNCNAME[0]}"
  catchEnvironment "$handler" phpContainerTestPHPUnit "$@" || return $?
  catchEnvironment "$handler" phpContainerTestBash "$@" || return $?
}
_phpContainerTest() {
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}
