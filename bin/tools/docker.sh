#!/usr/bin/env bash
#
# Docker related
#
# Copyright &copy; 2026 Market Acumen, Inc.
#

if whichExists docker; then

  # Fetch the root password for a MySQL compatible database
  privateRootPassword() {
    local handler="_${FUNCNAME[0]}"
    local passwordFiles=("mariadb-root-password" "mysqld-root-password")
    local passwordFile
    for passwordFile in "${passwordFiles[@]}"; do
      passwordFile=$(catchReturn "$handler" userHome ".ssh/$passwordFile") || return $?
      [ -f "$passwordFile" ] || continue
      password=$(catchEnvironment "$handler" head -n 1 "$passwordFile") || return $?
      if [ -z "$password" ]; then
        throwEnvironment "$handler" "$(decorate file "$passwordFile") is blank (first line)" || return $?
      fi
      printf "%s\n" "$password"
      return 0
    done
    throwEnvironment "$handler" "No database root password found" || return $?
  }
  _privateRootPassword() {
    # __IDENTICAL__ usageDocument 1
    usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
  }

  # phpContainer docker compose wrapper
  phpContainerCompose() {
    local handler="_${FUNCNAME[0]}"
    local password
    password=$(catchReturn "$handler" privateRootPassword) || return $?
    catchReturn "$handler" muzzle pushd "$(buildHome)" || return $?
    local envs=(
      --arg "DATABASE_ROOT_PASSWORD=$password"
      --env APPLICATION_USER=www-data
      --env PHP_IDE_CONFIG=serverName=phpContainer
      --env LOG_HOME=/var/www/log
      --env CONTAINER_PORT_DATABASE=3307
      --env CONTAINER_PORT_WEB=8000
      --env XDEBUG_IDE_KEY=phpContainer
      --env XDEBUG_CLIENT_HOST=host.docker.internal
    )
    catchReturn "$handler" dockerCompose "${envs[@]}" "$@" || returnUndo $? muzzle popd || return $?
    catchReturn "$handler" muzzle popd || return $?
  }
  _phpContainerCompose() {
    # __IDENTICAL__ usageDocument 1
    usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
  }

  phpContainerBash() {
    local handler="_${FUNCNAME[0]}"
    catchEnvironment "$handler" muzzle dockerCompose up -d || return $?
    catchEnvironment "$handler" __phpContainerExecute www-data bash "$@" || return $?
  }

  _phpContainerBash() {
    # __IDENTICAL__ usageDocument 1
    usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
  }

  suPHPContainerBash() {
    local handler="_${FUNCNAME[0]}"
    catchEnvironment "$handler" muzzle dockerCompose up -d || return $?
    catchEnvironment "$handler" __phpContainerExecute root bash "$@" || return $?
  }
  _suPHPContainerBash() {
    # __IDENTICAL__ usageDocument 1
    usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
  }

  __phpContainerExecute() {
    local user="$1" ttyArg=() && shift
    [ -t 0 ] || ttyArg+=(-T)
    dockerCompose exec "${ttyArg[@]}" -u "$user" web "$@"
  }
fi
