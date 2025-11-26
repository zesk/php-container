#!/usr/bin/env bash
#
# Sample live version script, uses github API to fetch release version
#
# Copyright &copy; 2025 Market Acumen, Inc.
#

# shellcheck source=/dev/null
if ! source "${BASH_SOURCE[0]%/*}/../tools.sh"; then
  printf "%s\n" "Unable to load ${BASH_SOURCE[0]%/*}/../tools.sh" 1>&2
else
  # Fetch the current live version of the software
  __hookVersionLive() {
    local usage="_${FUNCNAME[0]}"

    local name owner
    name=$(catchEnvironment "$usage" buildEnvironmentGet GITHUB_REPOSITORY_NAME) || return $?
    [ -n "$name" ] || throwEnvironment "$usage" "GITHUB_REPOSITORY_NAME is blank" || return $?

    owner=$(catchEnvironment "$usage" buildEnvironmentGet GITHUB_REPOSITORY_OWNER) || return $?
    [ -n "$owner" ] || throwEnvironment "$usage" "GITHUB_REPOSITORY_OWNER is blank" || return $?
    catchEnvironment "$usage" githubLatestRelease "$owner/$name" "$@" || return $?
  }
  ___hookVersionLive() {
    # __IDENTICAL__ usageDocument 1
    usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
  }
  __hookVersionLive "$@"
fi
