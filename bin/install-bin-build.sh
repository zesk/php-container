#!/usr/bin/env bash
#
# Since scripts may copy this file directly, must replicate until deprecated
#
# Load build system - part of zesk/build
#
# Copy this into your project to install the build system during development and in pipelines
#
# Copyright &copy; 2026 Market Acumen, Inc.
#
# Debugging: 73b0bd4ba49583263542da725669003fc821eb63

# URL of latest release
__installBinBuildLatest() {
  printf -- "%s\n" "https://api.github.com/repos/zesk/build/releases/latest"
}

# tarball of version
__installBinBuildDownload() {
  printf -- "%s%s\n" "https://api.github.com/repos/zesk/build/tarball/" "$1"
}

# Download remote JSON as a temporary file (delete it)
# Requires: executableExists throwEnvironment fileTemporaryName __installBinBuildLatest curl urlFetch printf
__installBinBuildJSON() {
  local handler="$1" jsonFile message

  executableExists jq || throwEnvironment "$handler" "Requires jq to install" || return $?
  jsonFile=$(fileTemporaryName "$handler") || return $?
  if ! urlFetch "$(__installBinBuildLatest)" "$jsonFile"; then
    message="$(printf -- "%s\n%s\n" "Unable to fetch latest JSON:" "$(cat "$jsonFile")")"
    rm -rf "$jsonFile" || :
    throwEnvironment "$handler" "$message" || return $?
  fi
  printf "%s\n" "$jsonFile"
}

# Requires: jsonField printf
__githubInstallationURL() {
  local handler="$1" jsonFile="$2"
  url=$(jsonField "$handler" "$jsonFile" .tarball_url) || return $?
  printf -- "%s\n" "$url"
}

# Installs Zesk Build from GitHub
# Requires: __installBinBuildJSON __githubInstallationURL rm throwArgument printf
__installBinBuildURL() {
  local handler="$1" && shift
  local version="$1" && shift

  if [ -n "$version" ]; then
    __installBinBuildDownload "$version"
    return 0
  fi
  export ___TEMP_BIN_BUILD_URL
  if [ -n "${___TEMP_BIN_BUILD_URL-}" ]; then
    printf "%s\n" "$___TEMP_BIN_BUILD_URL"
    return 0
  fi
  local jsonFile url
  jsonFile=$(__installBinBuildJSON "$handler") || return $?
  url=$(__githubInstallationURL "$handler" "$jsonFile") || return $?
  rm -rf "$jsonFile" || :
  [ "${url#https://}" != "$url" ] || throwArgument "$handler" "URL (\"$url\") must begin with https://" || return $?
  ___TEMP_BIN_BUILD_URL="$url"
  printf -- "%s\n" "$url"
}

# Checks requested version OR Zesk Build version on GitHub
# Requires: __installBinBuildJSON jsonField jq versionSort decorate __githubInstallationURL throwArgument
__installBinBuildVersion() {
  local handler="$1" installPath="$2" packagePath="$3" desiredVersion="$4" jsonFile="" version url upIcon="☝️" okIcon="👌"

  if [ -n "$desiredVersion" ]; then
    version=$desiredVersion
    if [ -d "$packagePath" ] && [ -f "$packagePath/build.json" ]; then
      myVersion=$(jq -r .version <"$packagePath/build.json")
      if [ "$version" = "$myVersion" ]; then
        printf -- "%s %s" "$okIcon" "$(decorate info "$version")"
        return 0
      fi
      printf -- "%s %s️ %s" "$(decorate error "$myVersion")" "$upIcon" "$(decorate success "$version")"
    fi
    return 1
  fi

  export ___TEMP_BIN_BUILD_URL
  jsonFile=$(__installBinBuildJSON "$handler") || return $?
  # Version comparison
  version=$(jsonField "$handler" "$jsonFile" .tag_name) || returnClean $? "$jsonFile" || return $?

  if [ -d "$packagePath" ] && [ -f "$packagePath/build.json" ]; then
    local latest
    myVersion=$(jq -r .version <"$packagePath/build.json")
    # shellcheck disable=SC2119
    latest=$(printf "%s\n" "$myVersion" "$version" | versionSort | tail -n 1)
    if [ "$myVersion" = "$latest" ]; then
      printf -- "%s %s" "$okIcon" "$(decorate info "$version")"
      catchEnvironment "$handler" rm -f "$jsonFile" || return $?
      return 0
    fi
    printf -- "%s %s️ %s" "$(decorate error "$myVersion")" "$upIcon" "$(decorate success "$version")"
  fi

  # URL caching
  url=$(__githubInstallationURL "$handler" "$jsonFile") || returnClean $? "$jsonFile" || return $?
  catchEnvironment "$handler" rm -f "$jsonFile" || return $?
  [ "${url#https://}" != "$url" ] || throwArgument "$handler" "URL must begin with https://" || return $?
  ___TEMP_BIN_BUILD_URL="$url"

  return 1
}

# Check the install directory after installation and output the version
# Requires: __installCheck
__installBinBuildCheck() {
  __installCheck "zesk/build" "build.json" "$@"
}

# _IDENTICAL_ returnClean 21

# Delete files or directories and return the same exit code passed in.
# Argument: exitCode - Integer. Required. Exit code to return.
# Argument: item - Exists. Optional. One or more files or folders to delete, failures are logged to stderr.
# Requires: isUnsignedInteger returnArgument throwEnvironment usageDocument throwArgument __help
# Group: Sugar
returnClean() {
  local handler="_${FUNCNAME[0]}"
  [ "${1-}" != "--help" ] || __help "$handler" "$@" || return 0
  local exitCode="${1-}" && shift
  if ! isUnsignedInteger "$exitCode"; then
    throwArgument "$handler" "$exitCode (not an integer) $*" || return $?
  else
    catchEnvironment "$handler" rm -rf "$@" || return "$exitCode"
    return "$exitCode"
  fi
}
_returnClean() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# _IDENTICAL_ jsonField 29

# Fetch a non-blank field from a JSON file with error handling
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# Argument: handler - Function. Required. Error handler.
# Argument: jsonFile - File. Required. A JSON file to parse
# Argument: ... - Arguments. Optional. Passed directly to jq
# stdout: selected field
# stderr: error messages
# Return Code: 0 - Field was found and was non-blank
# Return Code: 1 - Field was not found or is blank
# Requires: jq executableExists throwEnvironment printf rm decorate head
jsonField() {
  [ "${1-}" != "--help" ] || __help "_${FUNCNAME[0]}" "$@" || return 0
  local handler="$1" jsonFile="$2" value message && shift 2

  [ -f "$jsonFile" ] || throwEnvironment "$handler" "$jsonFile is not a file" || return $?
  executableExists jq || throwEnvironment "$handler" "Requires jq - not installed" || return $?
  if ! value=$(jq -r "$@" <"$jsonFile"); then
    message="$(printf -- "%s\n%s\n" "Unable to fetch selector $(decorate each code -- "$@") from JSON:" "$(head -n 100 "$jsonFile")")"
    throwEnvironment "$handler" "$message" || return $?
  fi
  [ -n "$value" ] || throwEnvironment "$handler" "$(printf -- "%s\n%s\n" "Selector $(decorate each code -- "$@") was blank from JSON:" "$(head -n 100 "$jsonFile")")" || return $?
  printf -- "%s\n" "$value"
}
_jsonField() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# IDENTICAL __installCheck 20

# Check the directory after an installation and output the version and ID from a file
#
# Argument: name - String. Required. Installed name.
# Argument: versionFile - RelativeFile. Required. Relative path to version file, containing `.id` and `.version` jq selectors.
# Argument: usageFunction - Function. Required. Call this on failure.
# Argument: installPath - Directory. Required. Path to check for installation.
# Argument: versionSelector - String. Optional. Selector to use to extract version from the file.
# Argument: idSelector - String. Optional. Selector to use to extract version from the file.
# Requires: dirname jq decorate printf throwEnvironment read jq
__installCheck() {
  local name="$1" version="$2" handler="$3" installPath="$4" versionSelector="${5-".version"}" idSelector="${6-".id"}"
  local versionFile="$installPath/$version" id
  if [ ! -f "$versionFile" ]; then
    throwEnvironment "$handler" "$(printf "%s: %s\n\n  %s\n  %s\n" "$(decorate error "$name")" "Incorrect version or broken install (can't find $version):" "rm -rf $(dirname "$installPath/$version")" "${BASH_SOURCE[0]}")" || return $?
  fi
  read -r version id < <(jq -r "($versionSelector + \" \" + $idSelector)" <"$versionFile" || :) || :
  [ -n "$version" ] && [ -n "$id" ] || throwEnvironment "$handler" "$versionFile missing version: \"$version\" or id: \"$id\"" || return $?
  printf "%s %s (%s)\n" "$(decorate BOLD blue "$name")" "$(decorate code "$version")" "$(decorate orange "$id")"
}

# fn: {base}
# Installs a remote package system in a local project directory if not installed. Also
# will overwrite the installation binary with the latest version after installation.
#
# Determines the most recent version using GitHub API unless --url or --local is specified
#
# Unless `--local` is supplied, needs internet access via `curl` or` `wget`.
#
# Creates the directory `../../bin/build` relative to the installer by default, can be modified.
#
# Argument: --local localPackageDirectory - Directory. Optional. Directory of an existing bin/build installation to mock behavior for testing
# Argument: --url url - URL. Optional. URL of a tar.gz. file. Download source code from here.
# Argument: --debug - Flag. Optional. Debugging is on.
# Argument: --force - Flag. Optional. Force installation even if file is up to date.
# Argument: --diff - Flag. Optional. Show differences between old and new file.
# Return Code: 1 - Environment error
# Return Code: 2 - Argument error
__installPackageConfiguration() {
  local rel="$1"
  shift
  ! consoleHasColors || decorateInitialized || decorate info -- >/dev/null
  _installRemotePackage "$rel" "bin/build" "install-bin-build.sh" --version-function __installBinBuildVersion --url-function __installBinBuildURL --check-function __installBinBuildCheck --name "Zesk Build" "$@"
}

# IDENTICAL _installRemotePackage 379

# Installs {name} in a local project directory if not installed. Also
# will overwrite {source} with the latest version after installation.
#
# INTERNAL: URL can be determined programmatically using `urlFunction`.
# INTERNAL:
# INTERNAL: `versionFunction` can be used to avoid upgrades when versions have not changed. `versionFunction` can return a string which is appended to the message:
# INTERNAL:
# INTERNAL:      "{name} Newest version installed {versionFunctionOutput}"
# INTERNAL:
# INTERNAL: Calling signature for `version-function`:
# INTERNAL:
# INTERNAL:    Example:     version-function handler applicationHome installPath requestedVersion
# INTERNAL:    Argument: handler - Function. Required. Function to call when an error occurs.
# INTERNAL:    Argument: applicationHome - Directory. Required. Path to the application home where target will be installed, or is installed. (e.g. myApp/)
# INTERNAL:    Argument: installPath - Directory. Required. Path to the installPath home where target will be installed, or is installed. (e.g. myApp/bin/build)
# INTERNAL:    Argument: requestedVersion - EmptyString. Optional. Requested version to install.
# INTERNAL:
# INTERNAL: `version-function` should return 0 to halt the installation. Any other return code, installation continues normally.
# INTERNAL:
# INTERNAL: Calling signature for `url-function`:
# INTERNAL:
# INTERNAL:    Example:      url-function handler requestedVersion
# INTERNAL:    Argument: handler - Function. Required. Function to call when an error occurs.
# INTERNAL:    Argument: requestedVersion - EmptyString. Optional. Requested version to install.
# INTERNAL:
# INTERNAL: `url-function` should output a URL and exit 0. Any other return code terminates installation.
# INTERNAL:
# INTERNAL: Calling signature for `check-function`:
# INTERNAL:
# INTERNAL:    Example:      check-function handler installPath
# INTERNAL:    Argument: handler - Function. Required. Function to call when an error occurs.
# INTERNAL:    Argument: installPath - Directory. Required. Path to the installPath home where target will be installed, or is installed. (e.g. myApp/bin/build)
# INTERNAL:
# INTERNAL: If `checkFunction` fails, it should output any errors to `stderr` and return a non-zero exit code.
# INTERNAL:
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# Argument: relative - RelativePath. Required. Path from this script to our application root. INTERNAL.
# Argument: defaultPackagePath - RelativePath. Required. Path from application root to where the package should be installed. INTERNAL.
# Argument: packageInstallerName - ApplicationFile. Required. The new installer file, post installation, relative to the `installationPath`. INTERNAL.
# Argument: installationPath - ApplicationDirectory. Optional. Path to where the package should be installed instead of the defaultPackagePath.
# Argument: --help - Flag. Optional. Display this help.
# Argument: --source source - String. Optional. Source to display for the binary name. INTERNAL.
# Argument: --name name - String. Optional. Name to display for the remote package name. INTERNAL.
# Argument: --local localPackageDirectory - Directory. Optional. Directory of an existing installation to mock behavior for testing. INTERNAL.
# Argument: --url url - URL. Optional. URL of a tar.gz file. Download source code from here.
# Argument: --user username - String. Optional. Add `username:password` to remote request.
# Argument: --password passwordText - String. Optional. Add `username:password` to remote request.
# Argument: --header headerText - String. Optional. Add one or more headers to the remote request.
# Argument: --version-function urlFunction - Function. Optional. Function to compare live version to local version. Exits 0 if they match. Output version text if you want. INTERNAL.
# Argument: --version version - String. Optional. Download just **this** version of Zesk Build. Prevents stable breaking with new versions of Zesk Build.
# Argument: --url-function urlFunction - Function. Optional. Function to return the URL to download. INTERNAL.
# Argument: --check-function checkFunction - Function. Optional. Function to check the installation and output the version number or package name. INTERNAL.
# Argument: --installer installer - Executable. Optional. Multiple. Binary to run after installation succeeds. Can be supplied multiple times. If `installer` begins with a `@` then any errors by the installer are ignored.
# Argument: --replace file - File. Optional. Replace the target file with this script and delete this one. Internal only, do not use. INTERNAL.
# Argument: --finalize file - File. Optional. Remove the temporary file and exit 0. INTERNAL.
# Argument: --debug - Flag. Optional. Debugging is on. INTERNAL.
# Argument: --force - Flag. Optional. Force installation even if file is up to date.
# Argument: --skip-self - Flag. Optional. Skip the installation script self-update. (By default it is enabled.)
# Argument: --diff - Flag. Optional. Show differences between old and new file.
# Return Code: 1 - Environment error
# Return Code: 2 - Argument error
# Requires: cp rm cat printf realPath executableExists returnMessage fileTemporaryName catchArgument throwArgument catchEnvironment decorate validate isFunction __decorateExtensionQuote
_installRemotePackage() {
  local handler="_${FUNCNAME[0]}"

  local relative="${1-}" defaultPackagePath="${2-}" packageInstallerName="${3-}"

  shift 3

  case "${BUILD_DEBUG-}" in 1 | true) __installRemotePackageDebug BUILD_DEBUG ;; esac

  local source="" name="${FUNCNAME[1]}"
  local localPath="" fetchArguments=() url="" urlFunction="" checkFunction="" installers=()
  local versionFunction="" fixedVersion=""
  local installPath="" installArgs=() forceFlag=false installReason="" skipSelf=false

  # _IDENTICAL_ argumentNonBlankLoopHandler 6
  local __saved=("$@") __count=$#
  while [ $# -gt 0 ]; do
    local argument="$1" __index=$((__count - $# + 1))
    # __IDENTICAL__ __checkBlankArgumentHandler 1
    [ -n "$argument" ] || throwArgument "$handler" "blank #$__index/$__count ($(decorate each quote -- "${__saved[@]}"))" || return $?
    case "$argument" in
    # _IDENTICAL_ helpHandler 1
    --help) "$handler" 0 && return $? || return $? ;;
    --source) shift && source=$(validate "$handler" String "$argument" "${1-}") || return $? ;;
    --name) shift && name=$(validate "$handler" String "$argument" "${1-}") || return $? ;;
    --mock | --local)
      [ -z "$localPath" ] || throwArgument "$handler" "$argument already" || return $?
      shift && localPath="$(catchArgument "$handler" realPath "${1%/}")" || return $?
      ;;
    --user | --header | --password) shift && fetchArguments+=("$argument" "$(validate "$handler" String "$argument" "${1-}")") || return $? ;;
    --url)
      [ -z "$url" ] || throwArgument "$handler" "$argument already" || return $?
      shift && url=$(validate "$handler" String "$argument" "${1-}") || return $?
      ;;
    --version) shift && fixedVersion=$(validate "$handler" String "$argument" "${1-}") || return $? ;;
    --version-function)
      [ -z "$versionFunction" ] || throwArgument "$handler" "$argument already" || return $?
      shift && versionFunction=$(validate "$handler" "Function" "$argument" "${1-}") || return $?
      ;;
    --url-function)
      [ -z "$urlFunction" ] || throwArgument "$handler" "$argument already" || return $?
      shift && urlFunction=$(validate "$handler" "Function" "$argument" "${1-}") || return $?
      ;;
    --check-function)
      [ -z "$checkFunction" ] || throwArgument "$handler" "$argument already" || return $?
      shift && checkFunction=$(validate "$handler" "Function" "$argument" "${1-}") || return $?
      ;;
    --installer) shift && installers+=("$(validate "$handler" String "$argument" "${1-}")") || return $? ;;
    # I believe this ensures that the process running does not modify its source script directly
    #
    # 1. Copy new script to bin/install.sample.sh.$$
    # 2. Run exec bin/install.sample.sh.$$ --replace bin/install.sample.sh
    # 3. Memory reloaded with "new" version of script
    # 4. New version copies itself (.sh.$$) to old installer (.sh version), and runs
    # 4. exec bin/install.sample.sh --finalize bin/install.sample.sh.$$
    # 5. Loads NEW version of script, and then deletes `bin/install.sample.sh.$$` and exits
    #
    # But I could be wrong.
    --replace)
      local newName
      shift
      newName=$(validate "$handler" String "$argument" "${1-}") || return $?
      decorate BOLD blue "Updating -> $(decorate BOLD orange "$newName")"
      catchEnvironment "$handler" cp -f "${BASH_SOURCE[0]}" "$newName" || return $?
      catchEnvironment "$handler" chmod +x "$newName" || return $?
      exec "$newName" --finalize "${BASH_SOURCE[0]}" || return $?
      return 0
      ;;
    --finalize)
      local oldName
      shift
      oldName=$(validate "$handler" String "$argument" "${1-}") || return $?
      catchEnvironment "$handler" rm -rf "$oldName" || return $?
      return 0
      ;;
    --debug)
      __installRemotePackageDebug "$argument"
      ;;
    --skip-self) skipSelf=true ;;
    --force) forceFlag=true && installReason="--force specified" ;;
    --diff) installArgs+=("$argument") ;;
    *) installPath=$(validate "$handler" String "installPath" "$1") || return $? ;;
    esac
    shift
  done

  local installFlag=false
  local myBinary myPath applicationHome installPath packagePath
  # Move to starting point
  myBinary=$(catchEnvironment "$handler" realPath "${BASH_SOURCE[0]}") || return $?
  myPath="${myBinary%/*}" || return $?
  applicationHome=$(catchEnvironment "$handler" realPath "$myPath/$relative") || return $?
  applicationHome="${applicationHome%/}"
  [ -n "$installPath" ] || installPath="$applicationHome/$defaultPackagePath"
  installPath="${installPath%/}"
  packagePath="${installPath#"$applicationHome"}"
  packagePath="${packagePath#/}"

  catchEnvironment "$handler" pushd "$applicationHome" || return $?
  if [ -z "$url" ]; then
    if [ -n "$urlFunction" ]; then
      url=$(catchEnvironment "$handler" "$urlFunction" "$handler" "$fixedVersion") || return $?
      if [ -z "$url" ]; then
        throwArgument "$handler" "$urlFunction $fixedVersion failed" || return $?
      fi
    fi
  fi
  if [ -z "$url" ] && [ -z "$localPath" ]; then
    throwArgument "$handler" "--local or --url|--url-function is required" || return $?
  fi

  if [ ! -d "$installPath" ]; then
    [ -n "$installReason" ] || installReason="not installed"
    if $forceFlag; then
      printf "%s (%s)\n" "$(decorate orange "Forcing installation")" "$(decorate blue "$installReason")"
    fi
    installFlag=true
  elif ! $forceFlag && [ -n "$versionFunction" ]; then
    local newVersion=""
    if newVersion=$("$versionFunction" "$handler" "$applicationHome" "$packagePath" "$fixedVersion"); then
      printf "%s %s %s\n" "$(decorate value "$name")" "$(decorate info "Newest version installed")" "$newVersion"
      __installRemotePackageGitCheck "$applicationHome" "$packagePath" || :
      return 0
    fi
    forceFlag=true
    [ -z "$fixedVersion" ] && installReason="newer version available: $newVersion" || installReason="fixed version available: $newVersion"
  fi
  if $forceFlag; then
    [ -n "$installReason" ] || installReason="directory exists"
    printf "%s (%s)\n" "$(decorate orange "Forcing installation")" "$(decorate BOLD blue "$installReason")"
    installFlag=true
  fi
  binName="$(basename "$myBinary")"
  if [ "$binName" = "main" ]; then
    skipSelf=true
    binName=" ($(decorate BOLD orange "bash pipe"))"
  else
    binName=" ($(decorate BOLD blue "$(basename "$myBinary")"))"
  fi
  local suffix
  if $installFlag; then
    local start
    start=$(($(catchEnvironment "$handler" date +%s) + 0)) || return $?
    __installRemotePackageDirectory "$handler" "$packagePath" "$applicationHome" "$url" "$localPath" "${fetchArguments[@]+"${fetchArguments[@]}"}" || return $?
    [ -d "$packagePath" ] || throwEnvironment "$handler" "Unable to download and install $packagePath (not a directory, still)" || return $?
    suffix="in $(($(date +%s) - start)) seconds$binName"
  else
    suffix="already installed"
  fi
  local messageFile
  messageFile=$(fileTemporaryName "$handler") || return $?
  if [ -n "$checkFunction" ]; then
    "$checkFunction" "$handler" "$packagePath" >"$messageFile" 2>&1 || return $?
  else
    catchEnvironment "$handler" printf -- "%s\n" "$packagePath" >"$messageFile" || return $?
  fi
  local message
  message="Installed $(cat "$messageFile") $suffix"
  catchEnvironment "$handler" rm -f "$messageFile" || return $?
  __installRemotePackageGitCheck "$applicationHome" "$packagePath" || :
  message="$message (local)$binName"
  printf -- "%s\n" "$message"

  local exitCode=0

  if [ "${#installers[@]}" -gt 0 ]; then
    local installer lastExit=0 installerLog

    installerLog=$(fileTemporaryName "$handler") || return $?

    for installer in "${installers[@]}"; do
      local ignoreErrors=false
      if [ "${installer#@}" != "$installer" ]; then
        ignoreErrors=true
        installer="${installer#@}"
      fi
      if [ ! -f "$installer" ]; then
        throwEnvironment "$handler" "$installer is missing" || exitCode=$?
        continue
      fi
      if [ ! -x "$installer" ]; then
        throwEnvironment "$handler" "$installer is not executable" || exitCode=$?
        continue
      fi
      decorate info "Running installer $(decorate code "$installer") ($ignoreErrors) ..."
      catchEnvironment "$handler" "$installer" >"$installerLog" 2>&1 || lastExit=$?
      if [ $lastExit -gt 0 ]; then
        if $ignoreErrors; then
          decorate warning "Installer $(decorate code "$installer") did not succeed [$(decorate value "$lastExit")]"
          decorate code <"$installerLog"
        else
          decorate error "Installer $(decorate code "$installer") failed [$(decorate value "$lastExit")]" 1>&2
          decorate code <"$installerLog" 1>&2
          exitCode=$lastExit || :
        fi
        printf -- "" >"$installerLog" || :
      fi
    done

    rm -f "$installerLog" || :

    if [ "$exitCode" != 0 ]; then
      # Exit before replacing script below
      return "$exitCode"
    fi
  fi
  $skipSelf || __installRemotePackageLocal "$installPath/$packageInstallerName" "$myBinary" "$relative"
}

# Error handler for _installRemotePackage
# Argument: returnCode - UnsignedInteger. Required. Exit code.
# Argument: message ... - EmptyString. Optional. Error message to show.
# Requires: usageDocumentSimple
__installRemotePackage() {
  local source content
  source=$(basename "${BASH_SOURCE[0]}")
  content="$(usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@" | grep -v "INTERNAL")"
  content="${content//\{name\}/$name}"
  content="${content//\{source\}/$source}"
  printf -- "%s\n" "$content"
}

# Debug is enabled, show why
# Requires: decorate
# Debugging: 73b0bd4ba49583263542da725669003fc821eb63
__installRemotePackageDebug() {
  decorate orange "${1-} enabled" && set -x
}

# Install the package directory
# Requires: uname pushd popd rm tar dirname
# Requires: catchReturn catchEnvironment throwEnvironment urlFetch
__installRemotePackageDirectory() {
  local handler="$1" packagePath="$2" applicationHome="$3" url="$4" localPath="$5"
  local start tarArgs osName
  local target="$applicationHome/.$$.package.tar.gz"

  shift 5
  if [ -n "$localPath" ]; then
    __installRemotePackageDirectoryLocal "$handler" "$packagePath" "$applicationHome" "$localPath"
    return $?
  fi
  catchReturn "$handler" urlFetch "$url" "$target" || return $?
  [ -f "$target" ] || throwEnvironment "$handler" "$target does not exist after download from $url" || return $?
  packagePath=${packagePath%/}
  packagePath=${packagePath#/}
  if ! osName="$(uname)" || [ "$osName" != "Darwin" ]; then
    tarArgs=(--wildcards "*/$packagePath/*")
  else
    tarArgs=(--include="*$packagePath/*")
  fi
  catchEnvironment "$handler" pushd "$(dirname "$target")" >/dev/null || return $?
  catchEnvironment "$handler" rm -rf "$packagePath" || return $?
  catchEnvironment "$handler" tar xf "$target" --strip-components=1 "${tarArgs[@]}" || return $?
  catchEnvironment "$handler" popd >/dev/null || return $?
  rm -f "$target" || :
}

# Install the build directory from a copy
# Requires: rm mv cp mkdir
# Requires: returnUndo catchEnvironment throwEnvironment
__installRemotePackageDirectoryLocal() {
  local handler="$1" packagePath="$2" applicationHome="$3" localPath="$4" installPath tempPath

  installPath="${applicationHome%/}/${packagePath#/}"
  # Clean target regardless
  if [ -d "$installPath" ]; then
    tempPath="$installPath.aboutToDelete.$$"
    catchEnvironment "$handler" rm -rf "$tempPath" || return $?
    catchEnvironment "$handler" mv -f "$installPath" "$tempPath" || return $?
    catchEnvironment "$handler" cp -r "$localPath" "$installPath" || returnUndo $? rf -f "$installPath" -- mv -f "$tempPath" "$installPath" || return $?
    catchEnvironment "$handler" rm -rf "$tempPath" || :
  else
    tempPath=$(catchEnvironment "$handler" dirname "$installPath") || return $?
    [ -d "$tempPath" ] || catchEnvironment "$handler" mkdir -p "$tempPath" || return $?
    catchEnvironment "$handler" cp -r "$localPath" "$installPath" || return $?
  fi
}

# Check .gitignore is correct
# Requires: grep printf
# Requires: decorate
__installRemotePackageGitCheck() {
  local applicationHome="$1" pattern="${2%/}"
  pattern="/${pattern#/}/"
  local ignoreFile="$1/.gitignore"
  if [ -f "$ignoreFile" ] && ! grep -q -e "^$pattern" "$ignoreFile"; then
    printf -- "%s %s %s %s:\n\n    %s\n" "$(decorate code "$ignoreFile")" \
      "does not ignore" \
      "$(decorate code "$pattern")" \
      "$(decorate error "recommend adding it")" \
      "$(decorate code "printf \"%s\n\" \"$pattern/\" >> \"$ignoreFile\"")"
  fi
}

# Argument: source - File. New source installer to customize.
# Argument: targetBinary - File. Target installer to update.
# Argument: relativePath - RelativePath. Path to the top of the project for the installer.
# Assumes our source handles the `--replace` argument to replace itself.
# Requires: grep printf chmod wait
# Requires: returnEnvironment isUnsignedInteger cat returnClean
__installRemotePackageLocal() {
  local source="$1" myBinary="$2" relTop="$3"
  {
    grep -v -e '^__installPackageConfiguration ' <"$source"
    printf "%s %s \"%s\"\n" "__installPackageConfiguration" "$relTop" '$@'
  } >"$myBinary.$$"
  if ! chmod +x "$myBinary.$$"; then
    rm -rf "$myBinary.$$" || :
    returnEnvironment "chmod +x failed" || return $?
  fi
  exec "$myBinary.$$" --replace "$myBinary"
}

# <-- END of IDENTICAL _installRemotePackage

# Summary: Sort versions in the format v0.0.0
#
# Sorts semantic versions prefixed with a `v` character; intended to be used as a pipe.
#
# vXXX.XXX.XXX
#
# for sort - -k 1.c,1 - the `c` is the 1-based character index, so 2 means skip the 1st character
#
# Odd you can't globally flip sort order with -r - that only works with non-keyed entries I assume
#
# Argument: -r | --reverse - Reverse the sort order (optional)
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# Example:     git tag | grep -e '^v[0-9.]*$' | versionSort
# Requires: throwArgument sort usageDocument decorate
versionSort() {
  local handler="_${FUNCNAME[0]}"

  local reverse=""

  # _IDENTICAL_ argumentNonBlankLoopHandler 6
  local __saved=("$@") __count=$#
  while [ $# -gt 0 ]; do
    local argument="$1" __index=$((__count - $# + 1))
    # __IDENTICAL__ __checkBlankArgumentHandler 1
    [ -n "$argument" ] || throwArgument "$handler" "blank #$__index/$__count ($(decorate each quote -- "${__saved[@]}"))" || return $?
    case "$argument" in
    # _IDENTICAL_ helpHandler 1
    --help) "$handler" 0 && return $? || return $? ;;
    -r | --reverse)
      reverse="r"
      ;;
    *)
      # _IDENTICAL_ argumentUnknownHandler 1
      throwArgument "$handler" "unknown #$__index/$__count \"$argument\" ($(decorate each code -- "${__saved[@]}"))" || return $?
      ;;
    esac
    shift
  done
  sort -t . -k "1.2,1n$reverse" -k "2,2n$reverse" -k "3,3n$reverse"
}
_versionSort() {
  true || versionSort --help
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# IDENTICAL validate 132

# Summary: Validate a value by type
# Argument: handler - Function. Required. Error handler.
# Argument: type - Type. Required. Type to validate. If more than validation set is specified, specifying a `type` of "" inherits the previous `type`. Blank `types` are not allowed.
# Argument: name - String. Required. Name of the variable which is being validated. If more than validation set is specified, specifying a name of "" inherits the previous name. Blank names are not allowed.
# Argument: value - EmptyString. Required. Value to validate.
#
# Validation sets are passed as three arguments, optionally repeated: `type` `name ` `value`
#
# Types are case-insensitive:
#
# #### Text and formats
#
# - `EmptyString` - (alias `string?`, `any`) - Any value at all
# - `String` - (no aliases) - Any non-empty string
# - `EnvironmentVariable` - (alias `env`) - A non-empty string which contains alphanumeric characters or the underscore and does not begin with a digit.
# - `Secret` - (no aliases) - A value which is security sensitive
# - `Date` - (no aliases) - A valid date in the form `YYYY-MM-DD`
# - `URL` - (no aliases) - A Universal Resource Locator in the form `scheme://user:password@host:port/path`
#
# #### Numbers
#
# - `Flag` - (no aliases) - Presence of an option to enables a feature. (e.g. `--debug` is a `flag`)
# - `Boolean` - (alias `bool`) - A value `true` or `false`
# - `BooleanLike` - (aliases `boolean?`, `bool?`) - A value which should be evaluated to a boolean value
# - `Integer` - (alias `int`) - Any integer, positive or negative
# - `UnsignedInteger` - (aliases `uint`, `unsigned`) - Any integer 0 or greater
# - `PositiveInteger` - (alias `positive`) - Any integer 1 or greater
# - `Number` - (alias `number`) - Any integer or real number
#
# #### File system
#
# - `Exists` - (no aliases - A file (or directory) which exists in the file system of any type
# - `File` - (no aliases) - A file which exists in the file system which is not any special type
# - `Link` - (no aliases) - A link which exists in the file system
# - `Directory` - (alias `dir`) - A directory which exists in the file system
# - `DirectoryList` - (alias `dirlist`) - One or more directories as arguments
# - `FileDirectory` - (alias `parent`) - A file whose directory exists in the file system but which may or may not exist.
# - `RealDirectory` - (alias `realdir`) - The real path of a directory which must exist.
# - `RealFile` - (alias `real`) - The real path of a file which must exist.
# - `RemoteDirectory` - (alias `remotedir`) - The path to a directory on a remote host.
#
# #### Application-relative
#
# - `ApplicationDirectory` - (alias `appdir`) - A directory path relative to `BUILD_HOME`
# - `ApplicationFile` - (alias `appfile`) - A file path relative to `BUILD_HOME`
# - `ApplicationDirectoryList` - (alias `appdirlist`) - One or more arguments of type `ApplicationDirectory`
#
# #### Functional
#
# - `Function` - (alias `function`) - A defined function
# - `Callable` - (alias `callable`) - A function or executable
# - `Executable` - (alias `bin`) - Any binary available within the `PATH`
#
# #### Lists
#
# - `Array` - (no aliases) - Zero or more arguments
# - `List` - (no  aliases) - Zero or more arguments
# - `ColonDelimitedList` - (alias `list:`) - A colon-delimited list `:`
# - `CommaDelimitedList` - (alias `list,`) - A comma-delimited list `,`
#
# You can repeat the `type` `name` `value` more than once in the arguments and each will be checked until one fails
# Return Code: 0 - Valid is valid, stdout is a filtered version of the value to be used
# Return Code: 2 - Valid is invalid, output reason to stderr
# Requires: __validateTypeString __validateTypePositiveInteger __validateTypeFunction __validateTypeCallable
# Requires: isFunction throwArgument __help decorate
validate() {
  local handler="_${FUNCNAME[0]}"
  local prefix="__validateType"

  [ "${1-}" != "--help" ] || __help "_${FUNCNAME[0]}" "$@" || return 0
  [ $# -ge 4 ] || throwArgument "$handler" "Missing arguments - expect 4 or more (#$#: $(decorate each code -- "$@"))" || return $?

  local handler="$1" && shift

  local name="" index=0
  while [ $# -ge 3 ]; do
    index=$((index + 1))
    local type="$1" value="$3"
    name="${2:-"$name"}"
    [ -n "$name" ] || throwArgument "$handler" "name required" || return $?
    if isFunction _validateTypeMapper; then
      type=$(_validateTypeMapper "$type")
    fi
    local typeFunction="$prefix$type"
    isFunction "$typeFunction" || throwArgument "$handler" "validate $type is not a valid type:"$'\n'"$(validateTypeList)" || return $?
    # Outputs stdout value if successful
    if ! "$typeFunction" "$value"; then
      local suffix="" ess="s" && [ "${#value}" -ne 1 ] || ess=""
      [ -z "$value" ] || suffix=" $(decorate error "$value")"
      throwArgument "$handler" "$name (#$index \"$(decorate code "$value")\" [${#value} char$ess]) is not type $(decorate label "$type")$suffix" || return $?
    fi
    shift 3
  done
}
_validate() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# output arguments to stderr and return the argument error
# Return: 2
# Return Code: 2 - Argument error
_validateThrow() {
  printf -- "%s\n" "$@" 1>&2
  return 2
}

# Non-empty string
# Requires: _validateThrow
__validateTypeString() {
  [ -n "${1-}" ] || _validateThrow "blank" || return $?
  printf "%s\n" "${1-}"
}

# Requires: isPositiveInteger _validateThrow
__validateTypePositiveInteger() {
  isPositiveInteger "${1-}" || _validateThrow || return $?
  printf "%s\n" "${1#+}"
}

# Requires: isFunction _validateThrow
__validateTypeFunction() {
  isFunction "${1-}" || _validateThrow || return $?
  printf "%s\n" "${1-}"
}

# Requires: isCallable _validateThrow
__validateTypeCallable() {
  isCallable "${1-}" || _validateThrow || return $?
  printf "%s\n" "${1-}"
}

# IDENTICAL urlFetch 168

# Summary: Fetch URL content
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# Argument: --dump headerFile - String. Optional. Dump the headers to the file specified, specify `-` to output to `stdout`.
# Argument: --header header - String. Optional. Send a header in the format 'Name: Value'
# Argument: --wget - Flag. Optional. Force use of wget. If unavailable, fail.
# Argument: --redirect-max maxRedirections - PositiveInteger. Optional. Sets the number of allowed redirects from the original URL. Default is 9.
# Argument: --curl - Flag. Optional. Force use of curl. If unavailable, fail.
# Argument: --binary binaryName - Callable. Use this binary instead. If the base name of the file is not `curl` or `wget` you MUST supply `--argument-format`.
# Argument: --argument-format format - String. Optional. Supply `curl` or `wget` for parameter formatting.
# Argument: --user userName - String. Optional. If supplied, uses HTTP Simple authentication. Usually used with `--password`. Note: User names may not contain the character `:` when using `curl`.
# Argument: --password password - String. Optional. If supplied along with `--user`, uses HTTP Simple authentication.
# Argument: --agent userAgent - String. Optional. Specify the user agent string.
# Argument: --timeout timeoutSeconds - PositiveInteger. Optional. A number of seconds to wait before failing. Defaults to `BUILD_URL_TIMEOUT` environment value.
# Argument: url - URL. Required. URL to fetch to target file.
# Argument: file - FileDirectory. Optional. Target file. Use `-` to send to `stdout`. Default value is `-`.
# Requires: returnMessage executableExists decorate
# Requires: validate
# Requires: throwArgument catchArgument
# Requires: throwEnvironment catchEnvironment
# Environment: BUILD_URL_TIMEOUT
urlFetch() {
  local handler="_${FUNCNAME[0]}"

  local wgetArgs=() curlArgs=() genericArgs=() headers=()
  local binary=() userHasColons=false user="" password="" format="" url="" target=""
  local maxRedirections=9 timeoutSeconds="" debugFlag=false saveHeadersFile=""

  # _IDENTICAL_ argumentNonBlankLoopHandler 6
  local __saved=("$@") __count=$#
  while [ $# -gt 0 ]; do
    local argument="$1" __index=$((__count - $# + 1))
    # __IDENTICAL__ __checkBlankArgumentHandler 1
    [ -n "$argument" ] || throwArgument "$handler" "blank #$__index/$__count ($(decorate each quote -- "${__saved[@]}"))" || return $?
    case "$argument" in
    # _IDENTICAL_ helpHandler 1
    --help) "$handler" 0 && return $? || return $? ;;
    --header)
      shift && local name="${1%%:}" value="${1#*:}"
      if [ "$name" = "${1-}" ] || [ "$value" = "${1-}" ]; then
        catchArgument "$handler" "Invalid $argument ${1-} passed" || return $?
      fi
      headers+=("$1")
      curlArgs+=("--header" "$1")
      wgetArgs+=("--header=$1")
      genericArgs+=("$argument" "$1")
      ;;
    --dump)
      local file && shift && file=$(validate "$handler" String "$argument" "${1-}") || return $?
      [ "$file" = '-' ] || file=$(validate "$handler" FileDirectory "$argument" "$file") || return $?
      curlArgs+=("-D" "$file")
      wgetArgs+=("--save-headers")
      saveHeadersFile="$file"
      ;;
    --wget) binary=("wget") ;;
    --curl) binary=("curl") ;;
    --binary)
      local tempBin
      shift && tempBin=$(validate "$handler" String "$argument" "${1-}") || return $?
      executableExists "$tempBin" || throwArgument "$handler" "$tempBin must be in PATH: $PATH" || return $?
      binary=("$tempBin")
      ;;
    --argument-format)
      shift && format=$(validate "$handler" String "$argument" "${1-}") || return $?
      case "$format" in curl | wget) ;; *) throwArgument "$handler" "$argument must be curl or wget" || return $? ;; esac
      ;;
    --redirect-max) shift && maxRedirections=$(validate "$handler" PositiveInteger "$argument" "${1-}") || return $? ;;
    --password) shift && password="$1" ;;
    --user)
      shift && user=$(validate "$handler" String "$argument (user)" "$user") || return $?
      if [ "$user" != "${user#*:}" ]; then
        userHasColons=true
      fi
      curlArgs+=(--user "$user:$password")
      wgetArgs+=("--http-user=$user" "--http-password=$password")
      genericArgs+=("$argument" "$1")
      ;;
    --debug) debugFlag=true ;;
    --timeout)
      shift && timeoutSeconds=$(validate "$handler" PositiveInteger "$argument" "${1-}") || return $?
      ;;
    --agent)
      local agent
      shift && agent=$(validate "$handler" String "$argument" "${1-}") || return $?
      wgetArgs+=("--user-agent=$agent")
      curlArgs+=("--user-agent" "$agent")
      genericArgs+=("$argument" "$agent")
      ;;
    *)
      if [ -z "$url" ]; then
        url="$1"
      elif [ -z "$target" ]; then
        target="$1"
        shift
        break
      else
        # _IDENTICAL_ argumentUnknownHandler 1
        throwArgument "$handler" "unknown #$__index/$__count \"$argument\" ($(decorate each code -- "${__saved[@]}"))" || return $?
      fi
      ;;
    esac
    shift
  done

  if [ -z "$timeoutSeconds" ]; then
    export BUILD_URL_TIMEOUT
    timeoutSeconds="${BUILD_URL_TIMEOUT-}"
  fi

  # URL
  [ -n "$url" ] || throwArgument "$handler" "URL is required" || return $?

  # target
  [ -n "$target" ] || target="-"
  [ "$target" = "-" ] || curlArgs+=("-o" "$target")

  # User
  if [ -n "$user" ]; then
    curlArgs+=("--user" "$user:$password")
    wgetArgs+=("--http-user=$user" "--http-password=$password")
    genericArgs+=("--user" "$user" "--password" "$password")
  fi

  # Binary
  [ "${#binary[@]}" -gt 0 ] || executableExists wget && binary=("wget") || executableExists "curl" && binary=("curl") || throwArgument "$handler" "No binary found" || return $?

  if [ "${binary[0]}" = "curl" ] && $userHasColons; then
    throwArgument "$handler" "$argument: Users ($argument \"$(decorate code "$user")\") with colons are not supported by curl, use wget" || return $?
  fi

  # Timeout
  if isPositiveInteger "$timeoutSeconds"; then
    curlArgs+=(--retry 1 --connect-timeout "$timeoutSeconds" --max-time "$timeoutSeconds")
    wgetArgs+=("--tries=1 --timeout=$timeoutSeconds")
    genericArgs+=(--timeout "$timeoutSeconds")
  fi

  [ "${#binary[@]}" -gt 0 ] || throwEnvironment "$handler" "wget or curl required" || return $?
  [ -n "$format" ] || format="${binary[0]}"
  ! $debugFlag || binary=("decorate" "each" "code" "${binary[@]}")
  case "$format" in
  wget)
    # -q - quiet
    wgetArgs+=(--max-redirect "$maxRedirections" -q)
    if [ -z "$saveHeadersFile" ]; then
      catchEnvironment "$handler" "${binary[@]}" --output-document="$target" "${wgetArgs[@]+"${wgetArgs[@]}"}" "$url" "$@" || return $?
    else
      # wget outputs headers at top of file as CRLF lines terminated by a blank CRLF line then the content
      local tempDownload && tempDownload=$(fileTemporaryName "$handler") || return $?
      catchEnvironment "$handler" "${binary[@]}" --output-document="$tempDownload" "${wgetArgs[@]+"${wgetArgs[@]}"}" "$url" "$@" || return $?
      catchEnvironment "$handler" sed -e 's/\r$//g' -e '/^$/ q' <"$tempDownload" | catchEnvironment "$handler" tee "$saveHeadersFile" || return $?
      catchEnvironment "$handler" sed -e '/\r$/d' <"$tempDownload" | catchEnvironment "$handler" tee "$target" || return $?
      catchEnvironment "$handler" rm -f "$tempDownload" || return $?
    fi
    ;;
  curl)
    # -L - follow redirects, -s - silent, -f - (FAIL) ignore documents for 4XX or 5XX errors
    curlArgs+=(-L --max-redirs "$maxRedirections" -s -f --no-show-error)
    catchEnvironment "$handler" "${binary[@]}" "$url" "$@" "${curlArgs[@]+"${curlArgs[@]}"}" || return $?
    ;;
  *) throwEnvironment "$handler" "No handler for binary format $(decorate value "$format") (binary is $(decorate each code "${binary[@]}")) $(decorate each value -- "${genericArgs[@]}")" || return $? ;;
  esac
}
_urlFetch() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# IDENTICAL __help 57

# Simple help argument handler.
#
# Easy `--help` handler for any function useful when it's the only option.
#
# Useful for utilities which single argument types, single arguments, and no arguments (except for `--help`)
#
# Oddly one of the few functions we can not offer the `--help` flag for.
# DOC TEMPLATE: noArgumentsForHelp 1
# Without arguments, displays help.
# Argument: --only - Flag. Optional. Must be first parameter. If calling function ONLY takes the `--help` parameter then throw an argument error if the argument is anything but `--help`.
# Argument: handlerFunction - Function. Required. Must be first or second parameter. If calling function ONLY takes the `--help` parameter then throw an argument error if the argument is anything but `--help`.
# Argument: arguments ... - Arguments. Optional. Arguments passed to calling function to check for `--help` argument.
#
# Example:     # NOT DEFINED handler
# Example:
# Example:     __help "_${FUNCNAME[0]}" "$@" || return 0
# Example:     [ "${1-}" != "--help" ] || __help "_${FUNCNAME[0]}" "$@" || return 0
# Example:     [ $# -eq 0 ] || __help --only "_${FUNCNAME[0]}" "$@" || return "$(convertValue $? 1 0)"
# Example:     # Argument 1 absolutely exists
# Example:     [ "$1" != "--help" ] || __help "_${FUNCNAME[0]}" "$@" || return 0
# Example:
# Example:     # DEFINED handler
# Example:
# Example:     local handler="_${FUNCNAME[0]}"
# Example:     __help "$handler" "$@" || return 0
# Example:     [ "$1" != "--help" ] || __help "$handler" "$@" || return 0
# Example:     [ "${1-}" != "--help" ] || __help "$handler" "$@" || return 0
# Example:     [ $# -eq 0 ] || __help --only "$handler" "$@" || return "$(convertValue $? 1 0)"
# Example:
# Example:     # Blank Arguments for help
# Example:     [ $# -gt 0 ] || __help "_${FUNCNAME[0]}" --help || return 0
# Example:     [ $# -gt 0 ] || __help "$handler" --help || return 0
#
# DEPRECATED-Example: [ $# -eq 0 ] || __help --only "_${FUNCNAME[0]}" "$@" || return $?
# DEPRECATED-Example: [ $# -eq 0 ] || __help --only "$handler" "$@" || return $?
#
# Requires: throwArgument usageDocument ___help
__help() {
  [ $# -gt 0 ] || ! ___help 0 || return 0
  local flag="--help"
  local handler="${1-}" && shift
  if [ "$handler" = "--only" ]; then
    handler="${1-}" && shift
    [ $# -gt 0 ] || return 0
    [ "$#" -eq 1 ] && [ "${1-}" = "$flag" ] || throwArgument "$handler" "Only argument allowed is \"$flag\": $*" || return $?
  fi
  while [ $# -gt 0 ]; do
    [ "$1" != "$flag" ] || ! "$handler" 0 || return 1
    shift
  done
  return 0
}
___help() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

usageDocument() {
  usageDocumentSimple "$@"
}

# IDENTICAL __usageMessage 39

# Summary: Icon for usage messages
# - `0` - meaning no error, icon is `🏆`
# - non-`0` - Error, icon is `❌`
__usageMessageIcon() {
  [ "$1" -eq 0 ] && printf -- "%s" "🏆" || printf -- "%s" "❌"
}

# Summary: Style usage messages
# Format arguments using the usage message return code to style output.
# Argument: returnCode - UnsignedInteger. Required. Return code to use as the basis for styling output.
# - `0` - meaning no error, style is `info`
# - `1` - Environment error, style is `error`
# - `2` - Argument error, style is `red`
# - `*` - All additional errors, style is `orange`
__usageMessageStyle() {
  local color="info" && case "$1" in 0) ;; 1) color="error" ;; 2) color="red" ;; *) color="orange" ;; esac && shift
  decorate "$color" "$@"
}

# Output the message for usage consistently
# Argument: returnCode - UnsignedInteger. Optional. Exit code to possibly display with message.
# Argument: message ... - String. Optional. Display this message which describes why `exitCode` occurred.
# Requires: decorate returnCodeString
__usageMessage() {
  local returnCode="${1-0}"
  [ $# -eq 0 ] || shift
  local suffix="$*"
  if [ "$returnCode" -eq 0 ]; then
    [ -n "$suffix" ] || return 0
    __usageMessageStyle "$returnCode" "$suffix"
  elif [ "$returnCode" != 2 ]; then
    [ -z "$suffix" ] || suffix=" $(decorate code "$suffix")"
    printf "%s %s%s\n" "$(__usageMessageIcon "$returnCode")" "$(__usageMessageStyle "$returnCode" "[$(returnCodeString "$returnCode")]")" "$suffix"
  else
    [ -z "$suffix" ] || suffix=" $(decorate code "$suffix")"
    printf "%s %s%s\n" "$(__usageMessageIcon "$returnCode")" "$(__usageMessageStyle "$returnCode" "[$(returnCodeString "$returnCode")]")" "$suffix"
  fi
}

# IDENTICAL __usageDocumentCached 36

# Summary: Display cached usage for a function
# Argument: handler - Function. Required.
# Argument: home - Directory. BUILD_HOME
# Argument: functionName - String. Function to display usage for
# Argument: returnCode - UnsignedInteger. Optional. Exit code to display. Defaults to `0` - no error.
# Argument: message ... - String. Optional. Display this message which describes why `exitCode` occurred.
# Environment: BUILD_COLORS
# Environment: BUILD_DOCUMENTATION_PATH
# Requires: decorateThemed catchEnvironment __usageMessage decorate
__usageDocumentCached() {
  local handler="$1" && shift
  local home="$1" && shift
  local functionName="$1" && shift
  export BUILD_DOCUMENTATION_PATH
  local paths && IFS=":" read -r -d $'\n' -a paths <<<"${BUILD_DOCUMENTATION_PATH-"bin/build/documentation"}"
  local settingsFile="" path && for path in "${paths[@]+"${paths[@]}"}"; do
    settingsFile="$home/${path%/}/$functionName.sh"
    [ ! -f "$settingsFile" ] || break
  done
  [ -n "$settingsFile" ] || return 1
  decorateInitialized || decorate info -- || return $?
  (
    local helpConsole="" helpPlain=""
    # shellcheck source=/dev/null
    catchEnvironment "$handler" source "$settingsFile" || return $?
    if [ "${BUILD_COLORS-}" != "false" ] && [ -n "$helpConsole" ]; then
      __usageMessage "$@" || return $?
      catchEnvironment "$handler" decorateThemed <<<"$helpConsole" || return $?
    else
      [ -n "$helpPlain" ] || return 1
      __usageMessage "$@" || return $?
      catchEnvironment "$handler" printf "%s\n" "$helpPlain" || return $?
    fi
  ) || return $?
}

# IDENTICAL usageDocumentSimple 33

# Output a simple error message for a function
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# Argument: source - File. Required. File where documentation exists.
# Argument: function - String. Required. Function to document.
# Argument: returnCode - UnsignedInteger. Required. Exit code to return.
# Argument: message ... - String. Optional. Message to display to the user.
# Requires: bashFunctionComment decorate read printf returnCodeString __help usageDocument __usageDocumentCached __usageMessageStyle __usageMessage
usageDocumentSimple() {
  local handler="_${FUNCNAME[0]}"

  [ "${1-}" != "--help" ] || __help "$handler" "$@" || return 0
  local source="${1-}" functionName="${2-}" returnCode="${3-}" && shift 3

  [ "$returnCode" -eq 0 ] || exec 3>&1 1>&2
  if ! __usageDocumentCached "$handler" "${BUILD_HOME-}" "${functionName}" "$returnCode" "$@"; then
    __usageMessage "$returnCode" "$@" || return $?
    export BUILD_HOME
    if [ ! -f "$source" ]; then
      [ -d "${BUILD_HOME-}" ] || returnArgument "Unable to locate $source (PWD: \"${PWD-}\", BUILD_HOME?: \"${BUILD_HOME-}\")" || return $?
      source="$BUILD_HOME/$source"
      [ -f "$source" ] || returnArgument "Unable to locate $source (PWD: \"${PWD-}\", BUILD_HOME: \"${BUILD_HOME-}\")" || return $?
    fi
    bashFunctionComment "$source" "$functionName" | sed "s/{fn}/$functionName/g" | __usageMessageStyle "$returnCode"
  fi
  [ "$returnCode" -eq 0 ] || exec 1>&3 3>&-
  return "$returnCode"
}
_usageDocumentSimple() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# IDENTICAL bashFunctionComment 48

# Extracts the final comment from a stream
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# Requires: fileReverseLines sed cut grep convertValue
bashFinalComment() {
  [ $# -eq 0 ] || __help --only "_${FUNCNAME[0]}" "$@" || return "$(convertValue $? 1 0)"
  grep -v -e '\(shellcheck \| IDENTICAL \|_IDENTICAL_\|DOC TEMPLATE:\|Internal:\|INTERNAL:\)' | fileReverseLines | sed -n -e 1d -e '/^[[:space:]]*#/ { p'$'\n''b'$'\n''}; q' | sed -e 's/^[[:space:]]*#[[:space:]]//' -e 's/^[[:space:]]*#$//' | fileReverseLines || :
  # Explained:
  # - grep -v ... - Removes internal documentation and anything we want to hide from the user
  # - fileReverseLines - First reversal to get that comment, file lines are reverse ordered
  # - `sed 1d` - Deletes the first line (e.g. the `function() { ` which was the LAST thing in the line and is now our first line
  # - `sed -n` - disables automatic printing
  # - `sed -e '/^[[:space:]]*#/ { p'$'\n''b'$'\n''}; q'` - while matching `[space]#` print lines then quit when does not match
  # - `sed -e 's/^[[:space:]]*#[[:space:]]//' -e 's/^[[:space:]]*#$//' - trim comment character and first space after
  # - Why the odd $'\n'? See https://stackoverflow.com/questions/15467616/sed-gives-me-unexpected-eof-pending-s-error-and-i-have-no-idea-why ... On BSD sed you must use newlines between statements.
  # - fileReverseLines - File is back to normal
}
_bashFinalComment() {
  ! false || bashFinalComment --help
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# Extract a bash comment from a file. Excludes lines containing the following tokens:
#
# - `" IDENTICAL "` or `"_IDENTICAL_"`
# - `"Internal:"` or `"INTERNAL:"`
# - `"DOC TEMPLATE:"`
#
# Argument: source - File. Required. File where the function is defined.
# Argument: functionName - String. Required. The name of the bash function to extract the documentation for.
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# Requires: grep cut fileReverseLines __help
# Requires: usageDocument
bashFunctionComment() {
  local source="${1-}" functionName="${2-}"
  local maxLines=1000
  __help "_${FUNCNAME[0]}" "$@" || return 0
  grep -m 1 -B $maxLines -e "^\s*$functionName() {" "$source" | bashFinalComment
  # Explained:
  # - grep -m 1 ... - Finds the `function() {` string in the file and all lines beforehand (up to 1000 lines)
}
_bashFunctionComment() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# _IDENTICAL_ convertValue 37

# map a value from one value to another given from-to pairs
#
# Prints the mapped value to stdout
#
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# Argument: value - String. A value.
# Argument: from - String. When value matches `from`, instead print `to`
# Argument: to - String. The value to print when `from` matches `value`
# Argument: ... - String. Optional. Additional from-to pairs can be passed, first matching value is used, all values will be examined if none match
convertValue() {
  local __handler="_${FUNCNAME[0]}" value="" from="" to=""
  # __IDENTICAL__ __checkHelp1__handler 1
  [ "${1-}" != "--help" ] || __help "$__handler" "$@" || return 0

  while [ $# -gt 0 ]; do
    if [ -z "$value" ]; then
      value=$(validate "$__handler" string "value" "$1") || return $?
    elif [ -z "$from" ]; then
      from=$(validate "$__handler" string "from" "$1") || return $?
    elif [ -z "$to" ]; then
      to=$(validate "$__handler" string "to" "$1") || return $?
      if [ "$value" = "$from" ]; then
        printf "%s\n" "$to"
        return 0
      fi
      from="" && to=""
    fi
    shift
  done
  printf "%s\n" "${value:-0}"
}
_convertValue() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# IDENTICAL executeInputSupport 39

# Support arguments and stdin as arguments to an executor
# Argument: executor ... -- - The command to run on each line of input or on each additional argument. Arguments to prefix the final variable argument can be supplied prior to an initial `--`.
# Argument: -- - Alone after the executor forces `stdin` to be ignored. The `--` flag is also removed from the arguments passed to the executor.
# Argument: ... - Any additional arguments are passed directly to the executor
executeInputSupport() {
  local handler="$1" executor=() && shift

  while [ $# -gt 0 ]; do
    if [ "$1" = "--" ]; then
      shift
      break
    fi
    executor+=("$1")
    shift
  done
  [ ${#executor[@]} -gt 0 ] || return 0

  local byte
  # On Darwin `read -t 0` DOES NOT WORK as a select on stdin
  if [ $# -eq 0 ] && IFS="" read -r -t 1 -n 1 byte; then
    local line done=false
    if [ "$byte" = $'\n' ]; then
      catchEnvironment "$handler" "${executor[@]}" "" || return $?
      byte=""
    fi
    while ! $done; do
      IFS="" read -r line || done=true
      [ -n "$byte$line" ] || ! $done || break
      catchEnvironment "$handler" "${executor[@]}" "$byte$line" || return $?
      byte=""
    done
  else
    if [ "${1-}" = "--" ]; then
      shift
    fi
    catchEnvironment "$handler" "${executor[@]}" "$@" || return $?
  fi
}

# IDENTICAL fileReverseLines 18

# Reverses a pipe's input lines to output using an awk trick.
#
# Not recommended on big files.
#
# Summary: Reverse output lines
# Source: https://web.archive.org/web/20090208232311/http://student.northpark.edu/pemente/awk/awk1line.txt
# Credits: Eric Pement
# Depends: awk
fileReverseLines() {
  [ "${1-}" != "--help" ] || __help "_${FUNCNAME[0]}" "$@" || return 0
  awk '{a[i++]=$0} END {for (j=i-1; j>=0;) print a[j--] }'
}
_fileReverseLines() {
  true || fileReverseLines --help
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# IDENTICAL _realPath 20

# Find the full, actual path of a file avoiding symlinks or redirection.
# See: readlink realpath
# DOC TEMPLATE: noArgumentsForHelp 1
# Without arguments, displays help.
# Argument: file ... - File. Required. One or more files to `realpath`.
# Requires: executableExists realpath __help usageDocument returnArgument
realPath() {
  # __IDENTICAL__ --help-when-blank 1
  [ $# -gt 0 ] || __help "_${FUNCNAME[0]}" --help || return 0
  if executableExists realpath; then
    realpath "$@"
  else
    readlink -f -n "$@"
  fi
}
_realPath() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# IDENTICAL fileTemporaryName 34

# Wrapper for `mktemp`. Generate a temporary file name, and fail using a function
# Argument: handler - Function. Required. Function to call on failure. Function Type: returnMessage
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# Argument: ... - Arguments. Optional. Any additional arguments are passed through.
# Requires: mktemp __help catchEnvironment usageDocument
# BUILD_DEBUG: temp - Logs backtrace of all temporary files to a file in application root named after this function to detect and clean up leaks
# Environment: BUILD_DEBUG
fileTemporaryName() {
  local handler="_${FUNCNAME[0]}"
  __help "$handler" "$@" || return 0
  handler="$1" && shift
  local debug=",${BUILD_DEBUG-},"
  if [ "${debug#*,temp,}" != "$debug" ]; then
    local target="${BUILD_HOME-.}/.${FUNCNAME[0]}"
    printf "%s" "fileTemporaryName: " >>"$target"
    catchEnvironment "$handler" mktemp "$@" | tee -a "$target" || return $?
    local sources=() count=${#FUNCNAME[@]} index=0
    while [ "$index" -lt "$count" ]; do
      sources+=("${BASH_SOURCE[index + 1]-}:${BASH_LINENO[index]-"$LINENO"} - ${FUNCNAME[index]-}")
      index=$((index + 1))
    done
    printf "%s\n" "${sources[@]}" "-- END" >>"$target"
  else
    catchEnvironment "$handler" mktemp "$@" || return $?
  fi
}
_fileTemporaryName() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# <-- END of IDENTICAL fileTemporaryName

# IDENTICAL executableExists 40

# Summary: Does a binary exist in the PATH?
# Argument: --any - Flag. Optional. If any binary exists then return 0 (success). Otherwise, all binaries must exist.
# Argument: binary ... - String. Required. One or more Binaries to find in the system `PATH`.
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# Return Code: 0 - If all values are found (without the `--any` flag), or if *any* binary is found with the `--any` flag
# Return Code: 1 - If any value is not found (without the `--any` flag), or if *all* binaries are NOT found with the `--any` flag.
# Example:     executableExists cp date aws ls mv stat || throwEnvironment "$handler" "Need basic environment to work" || return $?
# Example:     executableExists --any terraform tofu || throwEnvironment "$handler" "No available infrastructure providers" || return $?
# Example:     executableExists --any curl wget || throwEnvironment "$handler" "No way to download URLs easily" || return $?
# Requires: throwArgument decorate __decorateExtensionEach command
executableExists() {
  local handler="_${FUNCNAME[0]}"
  local __saved=("$@") __count=$# anyFlag=false
  [ $# -gt 0 ] || throwArgument "$handler" "no arguments" || return $?
  while [ $# -gt 0 ]; do
    local argument="$1" __index=$((__count - $# + 1))
    # __IDENTICAL__ __checkBlankArgumentHandler 1
    [ -n "$argument" ] || throwArgument "$handler" "blank #$__index/$__count ($(decorate each quote -- "${__saved[@]}"))" || return $?
    case "$argument" in
    # _IDENTICAL_ helpHandler 1
    --help) "$handler" 0 && return $? || return $? ;;
    --any) anyFlag=true ;;
    *)
      local bin
      # printf is returned as just printf with no path, same with all builtins
      bin=$(command -v "$1" 2>/dev/null) || return 1
      [ -n "$bin" ] || return 1
      [ "${bin:0:1}" != "/" ] || [ -e "$bin" ] || return 1
      ! $anyFlag || return 0
      ;;
    esac
    shift
  done
}
_executableExists() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# IDENTICAL isCallable 46

# Test if all arguments are callable as a command
# Argument: string - EmptyString. Required. Path to binary to test if it is executable.
# If no arguments are passed, returns exit code 1.
# Return Code: 0 - All arguments are callable as a command
# Return Code: 1 - One or or more arguments are callable as a command
# Requires: throwArgument __help isExecutable isFunction
isCallable() {
  local handler="_${FUNCNAME[0]}"
  [ $# -eq 1 ] || throwArgument "$handler" "Single argument only: $*" || return $?
  [ "${1-}" != "--help" ] || __help "$handler" "$@" || return 0
  if ! isFunction "$1" && ! isExecutable "$1"; then
    return 1
  fi
}
_isCallable() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# Test if all arguments are executable binaries
# Argument: string - String. Required. Path to binary to test if it is executable.
# If no arguments are passed, returns exit code 1.
# Return Code: 0 - All arguments are executable binaries
# Return Code: 1 - One or or more arguments are not executable binaries
# Requires: throwArgument  __help catchEnvironment command
isExecutable() {
  local handler="_${FUNCNAME[0]}"
  [ $# -eq 1 ] || throwArgument "$handler" "Single argument only: $*" || return $?
  [ "${1-}" != "--help" ] || __help "$handler" "$@" || return 0
  # Skip illegal options "--" and "-foo"
  [ "$1" = "${1#-}" ] || return 1
  if [ -f "$1" ]; then
    # Docker has an issue when you mount a local volume inside a container
    # Executable files, inside the container within the mounted volume report as non-executable via `-x` but
    # Report *correctly* when you use `ls`.
    local mode && mode=$(catchEnvironment "$handler" ls -l "$1") || return $?
    mode="${mode%% *}" && [ "${mode#*x}" != "$mode" ]
  else
    [ -n "$(which "$1")" ]
  fi
}
_isExecutable() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# IDENTICAL _type 42

# Test if an argument is a positive integer (non-zero)
# Takes one argument only.
# Argument: value - EmptyString. Required. Value to check if it is an unsigned integer
# Return Code: 0 - if it is a positive integer
# Return Code: 1 - if it is not a positive integer
# Requires: catchArgument isUnsignedInteger usageDocument
isPositiveInteger() {
  # _IDENTICAL_ functionSignatureSingleArgument 2
  local handler="_${FUNCNAME[0]}"
  [ $# -eq 1 ] || catchArgument "$handler" "Single argument only: $*" || return $?
  [ "${1-}" != "--help" ] || __help "$handler" "$@" || return 0
  if isUnsignedInteger "${1-}"; then
    [ "$1" -gt 0 ] || return 1
    return 0
  fi
  return 1
}
_isPositiveInteger() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# Test if argument are bash functions
# Argument: string - Required. String to test if it is a bash function. Builtins are supported. `.` is explicitly not supported to disambiguate it from the current directory `.`.
# If no arguments are passed, returns exit code 1.
# Return Code: 0 - argument is bash function
# Return Code: 1 - argument is not a bash function
# Requires: catchArgument isUnsignedInteger usageDocument type
isFunction() {
  # _IDENTICAL_ functionSignatureSingleArgument 2
  local handler="_${FUNCNAME[0]}"
  [ $# -eq 1 ] || catchArgument "$handler" "Single argument only: $*" || return $?
  [ "${1-}" != "--help" ] || __help "$handler" "$@" || return 0
  # Skip illegal options "--" and "-foo"
  [ "$1" = "${1#-}" ] || return 1
  case "$(type -t "$1")" in function | builtin) [ "$1" != "." ] || return 1 ;; *) return 1 ;; esac
}
_isFunction() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# IDENTICAL decorate 288

# Sets the environment variable `BUILD_COLORS` if not set, uses `TERM` to calculate
#
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# Return Code: 0 - Console or output supports colors
# Return Code: 1 - Colors are likely not supported by console
# Environment: BUILD_COLORS - Boolean. Optional. Whether the build system will output ANSI colors.
# Requires: isPositiveInteger tput
consoleHasColors() {
  # --help is only argument allowed
  [ $# -eq 0 ] || __help --only "_${FUNCNAME[0]}" "$@" || return "$(convertValue $? 1 0)"

  # Values allowed for this global are true and false
  # Important: DO NOT use buildEnvironmentLoad BUILD_COLORS TERM
  export BUILD_COLORS
  if [ -z "${BUILD_COLORS-}" ]; then
    BUILD_COLORS=false
    case "${TERM-}" in "" | "dumb" | "unknown") BUILD_COLORS=true ;; *)
      local termColors
      termColors="$(tput colors 2>/dev/null)"
      isPositiveInteger "$termColors" || termColors=2
      [ "$termColors" -lt 8 ] || BUILD_COLORS=true
      ;;
    esac
  elif [ "${BUILD_COLORS-}" != "true" ]; then
    BUILD_COLORS=false
  fi
  [ "${BUILD_COLORS-}" = "true" ]
}
_consoleHasColors() {
  true || consoleHasColors --help
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

#
# Semantics-based
#
# Argument: label - Text label
# Argument: lightStartCode - Escape code label for light mode (color)
# Argument: endCode - Escape end code
# Argument: text ... - Text to output.
# Requires: consoleHasColors printf
__decorate() {
  local prefix="$1" start="$2" end="$3" && shift 3
  export BUILD_COLORS
  if [ -n "${BUILD_COLORS-}" ] && [ "${BUILD_COLORS-}" = "true" ] || [ -z "${BUILD_COLORS-}" ] && consoleHasColors; then
    if [ $# -eq 0 ]; then printf -- "%s$start" ""; else printf -- "$start%s$end\n" "$*"; fi
    return 0
  fi
  [ $# -gt 0 ] || return 0
  if [ -n "$prefix" ]; then printf -- "%s: %s\n" "$prefix" "$*"; else printf -- "%s\n" "$*"; fi
}

# Output a list of build-in decoration styles, one per line
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
decorations() {
  [ $# -eq 0 ] || __help --only "_${FUNCNAME[0]}" "$@" || return "$(convertValue $? 1 0)"
  printf "%s\n" reset \
    underline no-underline bold no-bold \
    black black-contrast blue cyan green magenta orange red white yellow \
    code info notice success warning error subtle label value decoration
}
_decorations() {
  ! false || decorations --help
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# Singular decoration function
# Argument: style - String. Required. One of: reset underline no-underline bold no-bold black black-contrast blue cyan green magenta orange red white yellow code info notice success warning error subtle label value decoration
# Argument: text ... - String. Optional. Text to output. If not supplied, outputs a code to change the style to the new style. May contain arguments for `style`.
# You can extend this function by writing a your own extension `__decorationExtensionCustom` is called for `decorate custom`.
# stdout: Decorated text
# Environment: __BUILD_DECORATE - String. Cached color lookup.
# Environment: BUILD_COLORS - Boolean. Colors enabled (`true` or `false`).
# Requires: isFunction returnArgument awk catchEnvironment usageDocument executeInputSupport __help
decorate() {
  local handler="_${FUNCNAME[0]}" what="${1-}"
  [ "$what" != "--help" ] || __help "$handler" "$@" || return 0
  [ -n "$what" ] || catchArgument "$handler" "Requires at least one argument: \"$*\"" || return $?
  local style && shift && catchReturn "$handler" _decorateInitialize || return $?
  if ! style=$(__decorateStyle "$what"); then
    local extend func="${what/-/_}"
    extend="__decorateExtension$(printf "%s" "${func:0:1}" | awk '{print toupper($0)}')${func:1}"
    # When this next line calls `catchArgument` it results in an infinite loop, so don't - use returnArgument
    # shellcheck disable=SC2119
    if isFunction "$extend"; then
      executeInputSupport "$handler" "$extend" -- "$@" || return $?
      return 0
    else
      executeInputSupport "$handler" __decorate "❌" "[$what ☹️" "]" -- "$@" || return 2
    fi
  fi
  local lp text="" && IFS=" " read -r lp text <<<"$style" || :
  local p='\033['
  executeInputSupport "$handler" __decorate "$text" "${p}${lp}m" "${p}0m" -- "$@" || return $?
}
_decorate() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# Is the decorate color system initialized yet?
# Useful to set our global color environment at the top level of a script if it hasn't been initialized already.
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# shellcheck disable=SC2120
decorateInitialized() {
  [ "${1-}" != "--help" ] || __help --only "_${FUNCNAME[0]}" "$@" || return 0
  export __BUILD_DECORATE
  [ -n "${__BUILD_DECORATE-}" ]
}
_decorateInitialized() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

_decorateInitialize() {
  export __BUILD_DECORATE
  [ -n "${__BUILD_DECORATE-}" ] || __decorateStyles || return $?
}

# Fetch the requested style as a string: lp dp text
# dp may be a dash for simpler parsing - dp=lp when dp is blank or dash
# text is optional, lp is required to be non-blank
# Requires: __decorateStyles
__decorateStyle() {
  local original style pattern=":$1="

  original="${__BUILD_DECORATE}"
  style="${__BUILD_DECORATE#*"$pattern"}"
  [ "$style" != "$original" ] || return 1
  printf "%s\n" "${style%%:*}"
}

# Default array styles, override if you wish
if ! isFunction __decorateStyles; then
  # This sets __BUILD_DECORATE to the styles strings
  __decorateStyles() {
    __decorateStylesDefaultLight || __decorateStylesDefaultDark # Solely for link
  }
fi

# Default array styles, override if you wish
__decorateStylesBase() {
  local styles=":reset=0:underline=4:no-underline=24:bold=1:no-bold=21:black=109;7:black-contrast=107;30:blue=94:cyan=36:green=92:magenta=35:orange=33:red=31:white=48;5;0;37:yellow=48;5;16;38;5;11:"
  styles="$styles:$(printf "%s:" "$@")"
  styles="$styles:code=1;97;44:warning=1;93;41 Warning:error=1;91 ERROR:"
  export __BUILD_DECORATE
  __BUILD_DECORATE="$styles"
}
__decorateStylesDefaultLight() {
  local aa=(
    "info=38;5;20 Info"
    "notice=46;31 Notice"
    "success=42;30 Success"
    "subtle=1;38;5;252"
    "label=34;103"
    "value=30;107"
    "decoration=45;97"
  )
  __decorateStylesBase "${aa[@]}"
}
__decorateStylesDefaultDark() {
  local aa=(
    "info=33 Info"
    "notice=97;44 Notice"
    "success=0;32 Success"
    "subtle=38;5;240"
    "label=96;40"
    "value=94"
    "decoration=45;30"
  )
  __decorateStylesBase "${aa[@]}"
}

# fn: decorate each
# Runs the following command on each subsequent argument for formatting
# Also supports formatting input lines instead (on the same line)
# Example:     decorate each code -- "$@"
# Requires: decorate printf
# Argument: style - CommaDelimitedList. Required. Style arguments passed directly to decorate for each item.
# Argument: -- - Flag. Optional. Pass as the first argument after the style to avoid reading arguments from stdin.
# Argument: --index - Flag. Optional. Show the index of each item before with a colon. `0:first 1:second` etc.
# Argument: --count - Flag. Optional. Show the count of items in the list after the list is generated.
__decorateExtensionEach() {
  local __saved=("$@") __count=$#
  local formatted=() item addIndex=false showCount=false index=0 prefix="" style=""

  while [ $# -gt 0 ]; do
    case "$1" in --index) addIndex=true ;; --count) showCount=true ;; --arguments) showCount=true ;;
    "") throwArgument "$handler" "Blank argument" || return $? ;;
    *) style="$1" && shift && break ;;
    esac
    shift
  done
  local codes=("$style")
  if [ "$style" != "${style#*,}" ]; then
    IFS="," read -r -a codes <<<"$style"
    [ "${#codes[@]}" -gt 0 ] || throwArgument "$handler" "Blank style passed to each: \"$style\" (${__saved[*]})"
  fi
  if [ $# -eq 0 ]; then
    local byte
    if read -r -t 1 -n 1 byte; then
      if [ "$byte" = $'\n' ]; then
        formatted+=("$prefix$(decorate "${codes[@]}" "")")
        byte=""
      fi
      local done=false
      while ! $done; do
        IFS='' read -r item || done=true
        [ -n "$byte$item" ] || ! $done || break
        ! $addIndex || prefix="$index:"
        formatted+=("$prefix$(decorate "${codes[@]}" "$byte$item")")
        byte=""
        index=$((index + 1))
      done
    fi
  else
    while [ $# -gt 0 ]; do
      ! $addIndex || prefix="$index:"
      item="$1"
      formatted+=("$prefix$(decorate "${codes[@]}" -- "$item")")
      shift
      index=$((index + 1))
    done
  fi
  ! $showCount || formatted+=("[$index]")
  IFS=" " printf -- "%s\n" "${formatted[*]-}"
}

# fn: decorate BOLD
# Argument: style - CommaDelimitedList. Required. Style arguments passed directly to decorate for each item.
# Argument: text ... - EmptyString. Optional. Text to format. Use `--` to output begin codes only.
__decorateExtensionBOLD() {
  local style="${1-}" && shift
  case "$style" in
  "" | "-" | "--")
    decorate bold "$*"
    return 0
    ;;
  esac
  local codes=("$style")
  if [ "$style" != "${style#*,}" ]; then
    IFS="," read -r -a codes <<<"$style"
    [ "${#codes[@]}" -gt 0 ] || throwArgument "$handler" "Blank style passed to BOLD: \"$style\" (${__saved[*]})"
  fi
  if [ "$*" != "--" ]; then
    if [ $# -eq 0 ]; then
      decorate "${codes[@]}" | decorate bold
    else
      decorate bold "$(decorate "${codes[@]}" -- "$@")"
    fi
  else
    decorate bold --
    decorate "${codes[@]}" --
  fi
}

# fn: decorate quote
# Double-quote all arguments as properly quoted bash string
# Mostly $ and " are problematic within a string
# Requires: printf decorate
__decorateExtensionQuote() {
  if [ $# -eq 0 ]; then
    local finished=false
    while ! $finished; do
      local line="" && IFS="" read -d $'\n' -r line || finished=true
      [ -n "$line" ] || ! $finished || continue
      __decorateExtensionQuoteProcessLine "$line" || return $?
    done
  else
    __decorateExtensionQuoteProcessLine "$@" || return $?
  fi
}

# Argument: text ... - String. Text to quote
__decorateExtensionQuoteProcessLine() {
  local text="$*"
  text="${text//\"/\\\"}"
  text="${text//\$/\\\$}"
  printf -- "\"%s\"\n" "$text"
}

# <-- END of IDENTICAL decorate
# <-- END of IDENTICAL decorate

# IDENTICAL execute7

# Argument: binary ... - Executable. Required. Any arguments are passed to `binary`.
# Run binary and output failed command upon error
# Requires: returnMessage
execute() {
  "$@" || returnMessage "$?" "$@" || return $?
}

# _IDENTICAL_ returnCodeString 15

# Output the exit code as a string
#
# INTERNAL: Winner of the one-line bash award 10 years running
# Argument: code ... - UnsignedInteger. String. Exit code value to output.
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# stdout: exitCodeToken, one per line
returnCodeString() {
  local k="" && while [ $# -gt 0 ]; do case "$1" in 0) k="success" ;; 1) k="environment" ;; 2) k="argument" ;; 97) k="assert" ;; 105) k="identical" ;; 108) k="leak" ;; 116) k="timeout" ;; 120) k="exit" ;; 127) k="not-found" ;; 130) k="user-interrupt" ;; 141) k="interrupt" ;; 253) k="internal" ;; 254) k="unknown" ;; --help) "_${FUNCNAME[0]}" 0 && return $? || return $? ;; *) k="[returnCodeString unknown \"$1\"]" ;; esac && [ -n "$k" ] || k="$1" && printf "%s\n" "$k" && shift; done
}
_returnCodeString() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# IDENTICAL returnMessage 42

# Return passed in integer return code and output message to `stderr` (non-zero) or `stdout` (zero)
# Argument: exitCode - UnsignedInteger. Required. Exit code to return. Default is 1.
# Argument: message ... - String. Optional. Message to output
# Return Code: exitCode
# Requires: isUnsignedInteger printf returnMessage
returnMessage() {
  local handler="_${FUNCNAME[0]}"
  local code="${1:-1}" && shift 2>/dev/null
  if [ "$code" = "--help" ]; then "$handler" 0 && return; fi
  isUnsignedInteger "$code" || returnMessage 2 "${FUNCNAME[1]-none}:${BASH_LINENO[1]-} -> ${handler#_} non-integer \"$code\"" "$@" || return $?
  if [ "$code" -gt 0 ]; then
    printf -- "%s %s\n" "❌ [$code]" "${*-§}" 1>&2
  else
    printf -- "%s %s\n" "✅" "${*-§}"
  fi
  return "$code"
}
_returnMessage() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# Summary: Is value an unsigned integer?
# Test if a value is a 0 or greater integer. Leading "+" is ok.
# Source: https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash
# Credits: F. Hauri - Give Up GitHub (isnum_Case)
# Original: is_uint
# Argument: value - EmptyString. Value to test if it is an unsigned integer.
# Return Code: 0 - if it is an unsigned integer
# Return Code: 1 - if it is not an unsigned integer
# Requires: returnMessage
isUnsignedInteger() {
  [ $# -eq 1 ] || returnMessage 2 "Single argument only: $*" || return $?
  case "${1#+}" in --help) usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]}" 0 ;; '' | *[!0-9]*) return 1 ;; esac
}
_isUnsignedInteger() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# <-- END of IDENTICAL returnMessage

# IDENTICAL _tinySugar 72

# Run `handler` with an argument error
# Argument: handler - Function. Required. Error handler.
# Argument: message ... - String. Optional. Error message
throwArgument() {
  returnThrow 2 "$@" || return $?
}

# Run `handler` with an environment error
# Argument: handler - Function. Required. Error handler.
# Argument: message ... - String. Optional. Error message
throwEnvironment() {
  returnThrow 1 "$@" || return $?
}

# Run `command`, upon failure run `handler` with an argument error
# Argument: handler - String. Required. Failure command
# Argument: command ... - Required. Command to run.
# Requires: throwArgument
catchArgument() {
  local handler="${1-}"
  shift && "$@" || throwArgument "$handler" "$@" || return $?
}

# Run `command`, upon failure run `handler` with an environment error
# Argument: handler - String. Required. Failure command
# Argument: command ... - Required. Command to run.
# Requires: throwEnvironment
catchEnvironment() {
  local handler="${1-}"
  shift && "$@" || throwEnvironment "$handler" "$@" || return $?
}

# _IDENTICAL_ _errors 36

# Return `argument` error code. Outputs `message ...` to `stderr`.
# Argument: message ... - String. Optional. Message to output.
# Return Code: 2
# Requires: returnMessage
returnArgument() {
  returnMessage 2 "$@" || return $?
}

# Return `environment` error code. Outputs `message ...` to `stderr`.
# Argument: message ... - String. Optional. Message to output.
# Return Code: 1
# Requires: returnMessage
returnEnvironment() {
  returnMessage 1 "$@" || return $?
}

# Run `handler` with a passed return code
# Argument: returnCode - Integer. Required. Return code.
# Argument: handler - Function. Required. Error handler.
# Argument: message ... - String. Optional. Error message
# Requires: returnArgument
returnThrow() {
  local returnCode="${1-}" && shift || returnArgument "Missing return code" || return $?
  local handler="${1-}" && shift || returnArgument "Missing error handler" || return $?
  "$handler" "$returnCode" "$@" || return $?
}

# Run binary and catch errors with handler
# Argument: handler - Function. Required. Error handler.
# Argument: binary ... - Executable. Required. Any arguments are passed to `binary`.
# Requires: returnArgument
catchReturn() {
  local handler="${1-}" && shift || returnArgument "Missing handler" || return $?
  "$@" || "$handler" "$?" "$@" || return $?
}

# <-- END of IDENTICAL _tinySugar

# IDENTICAL returnUndo 42

# Run a function and preserve exit code
# Returns `code`
# DOC TEMPLATE: --help 1
# Argument: --help - Flag. Optional. Display this help.
# Argument: code - UnsignedInteger. Required. Exit code to return.
# Argument: undoFunction - Callable. Optional. Command to run to undo something. Return status is ignored.
# Argument: -- - Flag. Optional. Used to delimit multiple commands.
# As a caveat, your command to `undo` can NOT take the argument `--` as a parameter.
# Example:     local undo thing
# Example:     thing=$(catchEnvironment "$handler" createLargeResource) || return $?
# Example:     undo+=(-- deleteLargeResource "$thing")
# Example:     thing=$(catchEnvironment "$handler" createMassiveResource) || returnUndo $? "${undo[@]}" || return $?
# Example:     undo+=(-- deleteMassiveResource "$thing")
# Requires: isUnsignedInteger throwArgument decorate execute
# Requires: usageDocument
returnUndo() {
  local __count=$# __saved=("$@") __handler="_${FUNCNAME[0]}" code="${1-}" execArguments=()
  # __IDENTICAL__ __checkHelp1__handler 1
  [ "${1-}" != "--help" ] || __help "$__handler" "$@" || return 0
  shift
  # __IDENTICAL__ __checkCode__handler 1
  isUnsignedInteger "$code" || throwArgument "$__handler" "Not unsigned integer: $(decorate value "[$code]") (#$__count $(decorate each code -- "${__saved[@]}"))" || return $?
  while [ $# -gt 0 ]; do
    case "$1" in
    --)
      [ "${#execArguments[@]}" -eq 0 ] || execute "${execArguments[@]}" || :
      execArguments=()
      ;;
    *)
      execArguments+=("$1")
      ;;
    esac
    shift
  done
  [ "${#execArguments[@]}" -eq 0 ] || execute "${execArguments[@]}" || :
  return "$code"
}
_returnUndo() {
  # __IDENTICAL__ usageDocument 1
  usageDocument "${BASH_SOURCE[0]}" "${FUNCNAME[0]#_}" "$@"
}

# Final line will be rewritten on update
#
# Points to the project root relative to this file's location
#
# So:
#
# - "bin/install-bin-build.sh" -> ".."
# - "bin/pipeline/install-bin-build.sh" -> "../.."
# - "bin/app/vendorApp/install-bin-build.sh" -> "../../.."
#
# -- DO NOT EDIT ANYTHING ABOVE THIS LINE IT WILL BE OVERWRITTEN --
__installPackageConfiguration .. "$@"
