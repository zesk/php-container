#!/usr/bin/env bash
#
# composer-related
#
# Copyright &copy; 2025 Market Acumen, Inc.
#

# For any project, ensures the `version` field in `composer.json` matches `runHook version-current`
#
# Run as a commit hook for any PHP project or as part of your build or development process
#
# Typically the version is copied in without the leading `v`.
#
# Argument: --raw - Flag. Optional. Do not trim leading character from version string.
# Argument: --home - Directory. Optional. Use this directory for the location of `composer.json`.
# Argument: --status - Flag. Optional. When set, returns 0 when te version was updated successfully and $(_code identical) when the files are the same
# Argument: --quiet - Flag. Optional. Do not output anything to stdout and just do the action and exit.
# Exit Code: 0 - File was updated successfully.
# Exit Code: 1 - Environment error
# Exit Code: 2 - Argument error
# Exit Code: 105 - Identical files (only when --status is passed)
composerInheritVersion() {
  local usage="_${FUNCNAME[0]}"
  local version home="" rawFlag=false statusFlag=false quietFlag=false

  # _IDENTICAL_ argument-case-header 5
  local __saved=("$@") __count=$#
  while [ $# -gt 0 ]; do
    local argument="$1" __index=$((__count - $# + 1))
    [ -n "$argument" ] || throwArgument "$usage" "blank #$__index/$__count ($(decorate each quote "${__saved[@]}"))" || return $?
    case "$argument" in
      # _IDENTICAL_ --help 4
      --help)
        "$usage" 0
        return $?
        ;;
      --raw)
        rawFlag=true
        ;;
      --status)
        statusFlag=true
        ;;
      --quiet)
        quietFlag=true
        ;;
      --home)
        shift
        home="$(usageArgumentDirectory "$usage" "$argument" "${1-}")" || return $?
        ;;
      *)
        # _IDENTICAL_ argumentUnknown 1
        throwArgument "$usage" "unknown #$__index/$__count \"$argument\" ($(decorate each code "${__saved[@]}"))" || return $?
        ;;
    esac
    # _IDENTICAL_ argument-esac-shift 1
    shift
  done

  version=$(catchEnvironment "$usage" hookVersionCurrent) || return $?
  if [ -z "$version" ]; then
    throwEnvironment "$usage" "Version returned by version-current hook is blank" || return $?
  fi
  [ -n "$home" ] || home=$(catchEnvironment "$usage" buildHome) || return $?

  if ! $rawFlag; then
    # Strip leading characters (usually a v)
    version="${version#[A-Za-z]}"
  fi

  local composerJSON="$home/composer.json" decoratedComposerJSON

  decoratedComposerJSON="$(decorate file "$composerJSON")"

  [ -f "$composerJSON" ] || throwEnvironment "$usage" "No $decoratedComposerJSON" || return $?

  newComposerJSON="$composerJSON.${FUNCNAME[0]}"

  catchEnvironment "$usage" jq --arg version "$version" ". + { version: \$version }" <"$composerJSON" >"$newComposerJSON" || returnClean$? "$newComposerJSON" || return $?

  local decoratedVersion
  decoratedVersion=$(decorate value "$version")
  if muzzle diff -q "$newComposerJSON" "$composerJSON"; then
    $quietFlag || statusMessage --last decorate info "$decoratedComposerJSON up to date at version $decoratedVersion"
    ! $statusFlag || return "$(_code identical)"
  else
    catchEnvironment "$usage" mv -f "$newComposerJSON" "$composerJSON" || returnClean$? "$newComposerJSON" || return $?
    $quietFlag || statusMessage --last decorate info "$decoratedComposerJSON updated to version $decoratedVersion"
  fi
}
_composerInheritVersion() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}
