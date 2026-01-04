#!/usr/bin/env bash
#
# Zesk tools
#
# Copyright &copy; 2026 Market Acumen, Inc.
#

__zeskTools() {
  local home

  home=$(catchEnvironment "returnMessage" buildHome) || return $?

  local zeskTools

  zeskTools="$home/vendor/zesk/zesk/bin/tools/"
  if [ -d "$zeskTools" ]; then
    if buildDebugEnabled bin-tools; then
      decorate info "Loading $(decorate file "$zeskTools") ..."
    fi
    catchEnvironment "returnMessage" bashSourcePath --exclude "*/__*.sh" "$zeskTools" || :
  fi

  unset "${FUNCNAME[0]}"
}

__zeskTools
