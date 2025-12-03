#!/usr/bin/env bash
#
# Docker related
#
# Copyright &copy; 2025 Market Acumen, Inc.
#

export PHP_CONTAINER_HOME
if [ -z "${PHP_CONTAINER_HOME-}" ]; then
  catchReturn "returnMessage" buildEnvironmentLoad PHP_CONTAINER_HOME || return $?
fi
