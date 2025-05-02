#!/usr/bin/env bash
#
# developer.sh is loaded automatically by
#
# Copyright &copy; 2025 Market Acumen, Inc.
#

if source "${BASH_SOURCE[0]%/*}/tools.sh"; then
  __phpContainerContextInitialize() {
    local home

    if home=$(__environment buildHome); then
      local zeskTools

      zeskTools="$home/vendor/zesk/zesk/bin/tools/"
      [ ! -d "$zeskTools" ] || __environment bashSourcePath "$zeskTools" || :
    fi

    developerAnnounce < <(__applicationToolsList)
  }

  __phpContainerContextInitialize
fi
