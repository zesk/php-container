#!/usr/bin/env bash
#
# Docker related
#
# Copyright &copy; 2025 Market Acumen, Inc.
#

if whichExists docker; then

  phpContainerCompose() {
    dockerCompose --env CONTAINER_PORT_DATABASE=3307 --env CONTAINER_PORT_WEB=8000 --env XDEBUG_IDE_KEY=phpContainer --env XDEBUG_CLIENT_HOST=host.docker.internal "$@"
  }

  phpContainerBash() {
    local usage="_${FUNCNAME[0]}"
    __catchEnvironment "$usage" muzzle dockerCompose up -d || return $?
    __catchEnvironment "$usage" __phpContainerExecute www-data bash "$@" || return $?
  }

  _phpContainerBash() {
    # _IDENTICAL_ usageDocument 1
    usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
  }

  suPHPContainerBash() {
    local usage="_${FUNCNAME[0]}"
    __catchEnvironment "$usage" muzzle dockerCompose up -d || return $?
    __catchEnvironment "$usage" __phpContainerExecute root bash "$@" || return $?
  }
  _suPHPContainerBash() {
    # _IDENTICAL_ usageDocument 1
    usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
  }

  __phpContainerExecute() {
    local user="$1" ttyArg=() && shift
    [ -t 0 ] || ttyArg+=(-T)
    dockerCompose exec "${ttyArg[@]}" -u "$user" web "$@"
  }
fi
