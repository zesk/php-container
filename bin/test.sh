#!/usr/bin/env bash
#
# test.sh
#
# Standard testing wrapper
#
# Copyright &copy; 2026 Market Acumen, Inc.
#

"${BASH_SOURCE[0]%/*}/tools.sh" phpContainerTest "$@"
