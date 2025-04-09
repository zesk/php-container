#!/usr/bin/env bash
#
# Deploy Zesk Build
#
# Copyright &copy; 2025 Market Acumen, Inc.
#

# IDENTICAL __source 19

# Load a source file and run a command
# Argument: source - Required. File. Path to source relative to application root..
# Argument: relativeHome - Required. Directory. Path to application root.
# Argument: command ... - Optional. Callable. A command to run and optional arguments.
# Requires: _return
# Security: source
__source() {
  local me="${BASH_SOURCE[0]}" e=253
  local here="${me%/*}"
  local source="$here/${2:-".."}/${1-}" && shift 2 || _return $e "missing source" || return $?
  [ -d "${source%/*}" ] || _return $e "${source%/*} is not a directory" || return $?
  [ -f "$source" ] && [ -x "$source" ] || _return $e "$source not an executable file" "$@" || return $?
  local a=("$@") && set --
  # shellcheck source=/dev/null
  source "$source" || _return $e source "$source" "$@" || return $?
  [ ${#a[@]} -gt 0 ] || return 0
  "${a[@]}" || return $?
}

# IDENTICAL __tools 8

# Load build tools and run command
# Argument: relativeHome - Required. Directory. Path to application root.
# Argument: command ... - Optional. Callable. A command to run and optional arguments.
# Requires: __source _return
__tools() {
  __source bin/build/tools.sh "$@"
}

# IDENTICAL _return 26

# Usage: {fn} [ exitCode [ message ... ] ]
# Argument: exitCode - Required. Integer. Exit code to return. Default is 1.
# Argument: message ... - Optional. String. Message to output to stderr.
# Exit Code: exitCode
# Requires: isUnsignedInteger printf _return
_return() {
  local r="${1-:1}" && shift 2>/dev/null
  isUnsignedInteger "$r" || _return 2 "${FUNCNAME[1]-none}:${BASH_LINENO[1]-} -> ${FUNCNAME[0]} non-integer $r" "$@" || return $?
  printf -- "[%d] ❌ %s\n" "$r" "${*-§}" 1>&2 || : && return "$r"
}

# Test if an argument is an unsigned integer
# Source: https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash
# Credits: F. Hauri - Give Up GitHub (isnum_Case)
# Original: is_uint
# Usage: {fn} argument ...
# Exit Code: 0 - if it is an unsigned integer
# Exit Code: 1 - if it is not an unsigned integer
# Requires: _return
isUnsignedInteger() {
  [ $# -eq 1 ] || _return 2 "Single argument only: $*" || return $?
  case "${1#+}" in '' | *[!0-9]*) return 1 ;; esac
}

# <-- END of IDENTICAL _return

#
# Deploy Zesk Build
#
__buildDeploy() {
  local usage="_${FUNCNAME[0]}"

  local debugFlag=false makeDocumentation=false

  export BUILD_COLORS

  # _IDENTICAL_ argument-case-header 5
  local __saved=("$@") __count=$#
  while [ $# -gt 0 ]; do
    local argument="$1" __index=$((__count - $# + 1))
    [ -n "$argument" ] || __throwArgument "$usage" "blank #$__index/$__count ($(decorate each quote "${__saved[@]}"))" || return $?
    case "$argument" in
      # _IDENTICAL_ --help 4
      --help)
        "$usage" 0
        return $?
        ;;
      --documentation)
        makeDocumentation=true
        ;;
      --debug)
        __buildDebugColors
        debugFlag=true
        ;;
      *)
        # _IDENTICAL_ argumentUnknown 1
        __throwArgument "$usage" "unknown #$__index/$__count \"$argument\" ($(decorate each code "${__saved[@]}"))" || return $?
        ;;
    esac
    # _IDENTICAL_ argument-esac-shift 1
    shift
  done

  local start
  start=$(timingStart)

  ! $debugFlag || statusMessage decorate info "Installing AWS ..."
  __catchEnvironment "$usage" awsInstall || return $?

  local target cloudFrontID
  target=$(buildEnvironmentGet "DOCUMENTATION_S3_PREFIX") || return $?
  cloudFrontID=$(buildEnvironmentGet "DOCUMENTATION_CLOUDFRONT_ID") || return $?

  local home
  home=$(__catchEnvironment "$usage" buildHome) || return $?

  local appId notes

  statusMessage decorate info "Fetching deep copy of repository ..." || :
  __catchEnvironment "$usage" git fetch --unshallow || return $?

  statusMessage decorate info "Collecting application version and ID ..." || :
  currentVersion="$(hookRun version-current)" || __throwEnvironment "$usage" "hookRun version-current" || return $?
  appId=$(hookRun application-id) || __throwEnvironment "$usage" "hookRun application-id" || return $?

  [ -n "$currentVersion" ] || __throwEnvironment "$usage" "Blank version-current" || return $?
  [ -n "$appId" ] || __throwEnvironment "$usage" "No application ID (blank?)" || return $?

  notes=$(releaseNotes) || __throwEnvironment "$usage" "releaseNotes" || return $?
  [ -f "$notes" ] || __throwEnvironment "$usage" "$notes does not exist" || return $?

  bigText "$currentVersion" | wrapLines "    $(decorate green "Zesk BUILD    🛠️️ ") $(decorate magenta)" "$(decorate green " ⚒️ ")" || :
  decorate info "Deploying a new release ... " || :

  if $makeDocumentation; then
    local rootShow rootPath="$home/documentation/site"
    rootShow=$(decorate file "$rootPath")

    if [ -n "$target" ]; then
      __throwEnvironment "$usage" "No DOCUMENTATION_S3_PREFIX but --documentation supplied" || return $?
    fi
    if [ ! -d "$rootPath" ]; then
      __throwEnvironment "$usage" "$rootShow does not exist but --documentation supplied" || return $?
    fi

    # Validate for later (possibly every time in the future)
    [ -n "$target" ] || __throwEnvironment "$usage" "DOCUMENTATION_S3_PREFIX is blank" || return $?
    [ "$target" != "${target#s3://}" ] || __throwEnvironment "$usage" "DOCUMENTATION_S3_PREFIX=$(decorate code "$target") is NOT a S3 URL" || return $?
    [ -n "$cloudFrontID" ] || __throwEnvironment "$usage" "DOCUMENTATION_CLOUDFRONT_ID is blank" || return $?

    ! $debugFlag || statusMessage decorate warning "Publishing documentation to $target ..."

    # Ideally do this in a way which is more transactional with the release version
    ! $debugFlag || statusMessage decorate warning "Syncing documentation to $target ..."
    __catchEnvironment "$usage" aws s3 sync --delete "$rootPath" "$target" || return $?
    ! $debugFlag || statusMessage decorate warning "Creating invalidation for $(decorate code "$cloudFrontID") ..."
    __catchEnvironment "$usage" aws cloudfront create-invalidation --distribution-id "$cloudFrontID" --paths / || return $?
  fi

  if ! githubRelease "$notes" "$currentVersion" "$appId"; then
    decorate warning "Deleting tagged version ... " || :
    gitTagDelete "$currentVersion" || decorate error "gitTagDelete $currentVersion ALSO failed but continuing ..." || :
    __throwEnvironment "$usage" "githubRelease" || return $?
  fi
  timingReport "$start" "Release completed in" || :
}
___buildDeploy() {
  usageDocument "${BASH_SOURCE[0]}" "_${FUNCNAME[0]}" "$@"
}

__tools .. __buildDeploy "$@"
