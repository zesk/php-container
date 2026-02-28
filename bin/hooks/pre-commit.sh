#!/usr/bin/env bash
#
# PHP Container pre-commit
#
# Copyright &copy; 2026 Market Acumen, Inc.
#

# shellcheck source=/dev/null
source "${BASH_SOURCE[0]%/*}/../tools.sh"

# fn: {base}
# PHP Container pre-commit:
#
# 1. Build `./test/tests-index`
# 2. Run next pre-commit hook
__hookPreCommit() {
  local handler="_${FUNCNAME[0]}"

  # _IDENTICAL_ argumentNonBlankLoopHandler 6
  local __saved=("$@") __count=$#
  while [ $# -gt 0 ]; do
    local argument="$1" __index=$((__count - $# + 1))
    # __IDENTICAL__ __checkBlankArgumentHandler 1
    [ -n "$argument" ] || throwArgument "$handler" "blank #$__index/$__count ($(decorate each quote -- "${__saved[@]}"))" || return $?
    case "$argument" in
    # _IDENTICAL_ helpHandler 1
    --help) "$handler" 0 && return $? || return $? ;;
    *)
      # _IDENTICAL_ argumentUnknownHandler 1
      throwArgument "$handler" "unknown #$__index/$__count \"$argument\" ($(decorate each code -- "${__saved[@]}"))" || return $?
      ;;
    esac
    shift
  done

  catchReturn "$handler" phpContainerTestBash --make-index || return $?

  # IDENTICAL hookRunOptionalNext 1
  catchReturn "$handler" hookRunOptional --next "${BASH_SOURCE[0]}" "$HOOK_NAME" "${__saved[@]+"${__saved[@]}"}" || return $?
}
___hookPreCommit() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

__hookPreCommit "$@"
