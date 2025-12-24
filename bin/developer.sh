#!/usr/bin/env bash
#
# developer.sh is loaded automatically by project-activate hook
#
# otherwise load with
#
#     source bin/developer.sh
#
# Copyright &copy; 2025 Market Acumen, Inc.
#

# shellcheck source=/dev/null
if source "${BASH_SOURCE[0]%/*}/tools.sh"; then

  # - `phpContainerCompose build`
  # - Container `phpContainerBash` `suPHPContainerBash`
  __phpContainerDockerHelp() {
    markdownToConsole < <(bashFunctionComment "${BASH_SOURCE[0]}" "${FUNCNAME[0]}")
  }

  # PHP Container
  __phpContainerContext() {
    # Title
    local name
    name=$(catchReturn "$handler" buildEnvironmentGet APPLICATION_NAME) || return $?
    [ -n "$name" ] || name=$(basename "$home")
    title="$name $(catchReturn "$handler" hookVersionCurrent)" || return $?
    bigText --bigger "$title"

    muzzle reloadChanges --stop 2>&1 || :
    muzzle reloadChanges --name "$(buildEnvironmentGet APPLICATION_NAME)" "bin/developer.sh" "bin/tools/" "bin/developer.sh"
    muzzle buildCompletion

    bashPrompt --skip-prompt bashPromptModule_TermColors

    export BUILD_PROJECT_DEACTIVATE="${FUNCNAME[0]}Undo"

    pathConfigure --last "$home/bin" "$home/vendor/bin" "$home/bin/build"

    markdownToConsole < <(bashFunctionComment "${BASH_SOURCE[0]}" "${FUNCNAME[0]}")
    ! whichExists docker || __phpContainerDockerHelp
    unset "${FUNCNAME[0]}" "_${FUNCNAME[0]}"
  }
  ___phpContainerContext() {
    # __IDENTICAL__ usageDocument 1
    usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
  }

  __phpContainerContextUndo() {
    local handler="returnMessage"
    local home

    muzzle reloadChanges --stop 2>&1

    home=$(catchReturn "$handler" buildHome) || return $?

    local name
    name=$(catchReturn "$handler" buildEnvironmentContext "$home" buildEnvironmentGet APPLICATION_NAME) || return $?
    [ -n "$name" ] || name=$(basename "$home")

    statusMessage decorate notice "Deactivating $name ..."

    pathRemove "$home/bin" "$home/vendor/bin" "$home/bin/build"

    unset "${FUNCNAME[0]}" 2>/dev/null
  }

  __phpContainerContext
fi
