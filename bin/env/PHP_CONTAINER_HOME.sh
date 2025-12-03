#!/usr/bin/env bash
# Copyright &copy; 2025 Market Acumen, Inc.
# Type: String
# Category: Application
# All about PHP_CONTAINER_HOME and how it is used
export PHP_CONTAINER_HOME
PHP_CONTAINER_HOME="${PHP_CONTAINER_HOME-}"

if [ -z "${PHP_CONTAINER_HOME-}" ]; then
  # Fetch the PHP container home
  phpContainerHome() {
    local handler="_${FUNCNAME[0]}"
    local here="${BASH_SOURCE[0]%/*}"

    here=$(catchReturn "$handler" realPath "$here/..") || return $?
    here="${here%/*}"
    printf "%s\n" "$here"

    unset "${FUNCNAME[0]}" "_${FUNCNAME[0]}"
  }
  _phpContainerHome() {
    # __IDENTICAL__ usageDocument 1
    usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
  }

  PHP_CONTAINER_HOME=$(phpContainerHome)
fi
