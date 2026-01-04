#!/usr/bin/env bash
#
# developer.sh is loaded automatically by project-activate hook
#
# otherwise load with
#
#     source bin/developer.sh
#
# Copyright &copy; 2026 Market Acumen, Inc.
#

# shellcheck source=/dev/null
if source "${BASH_SOURCE[0]%/*}/tools.sh"; then

  # - `phpContainerCompose build` - Build containers
  # - `phpContainerBash` `suPHPContainerBash` - Connect to container instances
  __phpContainerDockerHelp() {
    markdownToConsole < <(bashFunctionComment "${BASH_SOURCE[0]}" "${FUNCNAME[0]}")
  }

  # PHP Container
  __phpContainerContext() {
    local handler="_${FUNCNAME[0]}"

    # Title
    local name
    name=$(catchReturn "$handler" buildEnvironmentGet APPLICATION_NAME) || return $?
    [ -n "$name" ] || name=$(basename "$home")
    title="$name $(catchReturn "$handler" hookVersionCurrent)" || return $?
    bigText --bigger "$title"

    muzzle reloadChanges --stop 2>&1 || :
    muzzle reloadChanges --name "$(buildEnvironmentGet APPLICATION_NAME)" "bin/developer.sh" "bin/tools/" "bin/developer.sh" "etc/docker/tools.sh"
    muzzle buildCompletion

    bashPrompt --skip-prompt bashPromptModule_TermColors

    export BUILD_PROJECT_DEACTIVATE="${FUNCNAME[0]}Undo"

    pathConfigure --last "$home/bin" "$home/vendor/bin" "$home/bin/build"

    markdownToConsole < <(bashFunctionComment "${BASH_SOURCE[0]}" "${FUNCNAME[0]}")
    ! whichExists docker || __phpContainerDockerHelp
    phpContainerHelp

    unset __phpContainerDockerHelp
    unset "${FUNCNAME[0]}" "$handler"
  }
  ___phpContainerContext() {
    # __IDENTICAL__ usageDocument 1
    usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
  }

  __phpContainerContextUndo() {
    local handler="_${FUNCNAME[0]}"

    muzzle reloadChanges --stop 2>&1

    local home
    home=$(catchReturn "$handler" buildHome) || return $?

    local name
    name=$(catchReturn "$handler" buildEnvironmentContext "$home" buildEnvironmentGet APPLICATION_NAME) || return $?
    [ -n "$name" ] || name=$(basename "$home")

    statusMessage decorate notice "Deactivating $name ..."

    pathRemove "$home/bin" "$home/vendor/bin" "$home/bin/build"

    unset "${FUNCNAME[0]}" "$handler"
  }
  ___phpContainerContextUndo() {
    # __IDENTICAL__ usageDocument 1
    usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
  }

  __phpContainerContext
fi
