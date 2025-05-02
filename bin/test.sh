#!/usr/bin/env bash
#
# test.sh
#
# Standard testing wrapper
#
# Copyright &copy; 2025 Market Acumen, Inc.
#

# shellcheck source=/dev/null
source "${BASH_SOURCE[0]%/*}/tools.sh" || exit 99

#
# Standard test layout
#
# Test functions prefixed with the word `test` in:
#
# - ./test/tests/suite-tests.sh
#
# Test support files (available per test):
#
# - ./test/support/*.sh -
#
# Once ready, do `testTools testSuite --help`
#
__buildTestSuite() {
  local usage="_${FUNCNAME[0]}"
  local testHome

  testHome="$(__catchEnvironment "$usage" buildHome)" || return $?
  [ -d "$testHome/test" ] || __throwArgument "$usage" "Missing test directory" || return $?

  # Include our own test support files if needed
  [ ! -d "$testHome/test/support" ] || __catchEnvironment "$usage" bashSourcePath "$testHome/test/support" || return $?

  __catchEnvironment "$usage" testTools testSuite --tests "$testHome/test/tests/" "$@" || return $?
}
___buildTestSuite() {
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

__buildTestSuite "$@"
