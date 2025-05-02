#!/usr/bin/env bash
#
# developer.sh is loaded automatically by
#
# Copyright &copy; 2025 Market Acumen, Inc.
#

if source "${BASH_SOURCE[0]%/*}/tools.sh"; then
  __phpContainerContextInitialize() {
    reloadChanges --name "$(buildEnvironmentGet APPLICATION_NAME)" "bin/tools.sh" "bin/tools/"
    developerAnnounce < <(__applicationToolsList)
  }

  __phpContainerContextInitialize
fi
