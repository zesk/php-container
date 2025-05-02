#!/usr/bin/env bash
#
# Zesk tools
#
# Copyright &copy; 2025 Market Acumen, Inc.
#

__zeskTools() {
  local home

  home=$(__environment buildHome) || return $?

  local zeskTools

  zeskTools="$home/vendor/zesk/zesk/bin/tools/"
  if [ -d "$zeskTools" ]; then
    if buildDebugEnabled bin-tools; then
      decorate info "Loading $(decorate file "$zeskTools") ..."
    fi
    __environment bashSourcePath --exclude "*/__*.sh" "$zeskTools" || :
  fi
}

__zeskTools
