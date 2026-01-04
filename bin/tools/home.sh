#!/usr/bin/env bash
#
# Docker related
#
# Copyright &copy; 2026 Market Acumen, Inc.
#

export PHP_CONTAINER_DEVELOPMENT_HOME
if [ -z "${PHP_CONTAINER_DEVELOPMENT_HOME-}" ]; then
  catchReturn "returnMessage" buildEnvironmentLoad PHP_CONTAINER_DEVELOPMENT_HOME || return $?
fi
