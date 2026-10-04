#!/bin/sh
# lib.agentvm.install.sh
#
# The Install agent-vm window (AgentVM.install.json, the views 4201-4207): the newest agent-vm
# from its GitHub releases, downloaded, checked and installed for this user. One window at a
# time (lib.agentvm.ui.sh, "Box windows", with the kind "install" and the name "window"), opened
# by Install... or Update... on the first step of Get started, and by Check for Updates in
# Settings. It is the only part of the app that works without a usable agent-vm.
#
# WHAT IS INSTALLED. agent-vm's releases each carry one package, agent-vm_<version>.pkg, under
# the tag <version>. It installs for the user who runs it, with no password, into
# ~/.local/share/agent-vm/versions/<version>/, and points ~/.local/bin/agent-vm and
# ~/.local/bin/avm at it. It has two parts: agent-vm itself, and "add ~/.local/bin to your
# shell's PATH", which the window's checkbox chooses.
#
# THE STEPS of Download and Install (install_perform), each said in the window's status line:
#   newest    the version of the newest release: where .../releases/latest redirects to. No
#             GitHub API, no token. A release older than AGENTVM_MIN_VERSION is not installed.
#   download  the package, over https only, into a new temporary folder.
#   verify    Gatekeeper must accept the package as notarized Developer ID software (spctl), and
#             the first certificate of its signature must be a Developer ID Installer
#             certificate of agent-vm's team (pkgutil). Nothing unverified is ever installed.
#   parts     a choice changes file for installer: the agent-vm part selected, the PATH part as
#             the checkbox says, and any part this app does not know left out. installer is
#             asked what it would select with that file, and anything else is refused.
#   install   installer, without its windows (-target CurrentUserHomeDirectory). Once it has
#             begun it is left to finish, window or no window: stopping it halfway would leave
#             half a version behind. One that takes over ten minutes is stopped.
#   check     ~/.local/bin/agent-vm must now report the release's version.
# The temporary folder goes however the handler ends.
#
# TEST SEAMS, like AGENTVM_APP_AGENT_VM: AGENTVM_APP_CURL, AGENTVM_APP_SPCTL,
# AGENTVM_APP_PKGUTIL and AGENTVM_APP_INSTALLER name the programs used in place of
# /usr/bin/curl, /usr/sbin/spctl, /usr/sbin/pkgutil and /usr/sbin/installer;
# AGENTVM_APP_INSTALL_TIMEOUT, in seconds, replaces the ten minutes installing may take.
#
# Sources lib.agentvm.main.sh. POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_INSTALL_LIB:-}" ] && return 0
__AGENTVM_APP_INSTALL_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

curl_tool="${AGENTVM_APP_CURL:-/usr/bin/curl}"
spctl_tool="${AGENTVM_APP_SPCTL:-/usr/sbin/spctl}"
pkgutil_tool="${AGENTVM_APP_PKGUTIL:-/usr/sbin/pkgutil}"
installer_tool="${AGENTVM_APP_INSTALLER:-/usr/sbin/installer}"
install_timeout="${AGENTVM_APP_INSTALL_TIMEOUT:-600}"

# Where agent-vm is released, and who signs it.
install_releases="https://github.com/abra-code/agent-vm/releases"
install_team="T9NM2ZLDTY"
# The package's parts, as PackageBuilder names the choices of its two components.
install_agentvm_choice="com_abracode_pkg_agent_vm_choice"
install_path_choice="com_abracode_pkg_agent_vm_path_choice"

INSTALL_HEAD_ID=4201
INSTALL_PATH_ID=4203
INSTALL_NOTE_ID=4204
INSTALL_STATUS_ID=4205
INSTALL_BAR_ID=4206
INSTALL_BUTTON_ID=4207
# The handler that is installing, by its process: one installation at a time, whichever window
# started it (a window closed while it installs can be opened again).
INSTALL_RUNNING_KEY="agentvm_install_running"

# install_is <uuid>  ->  0 while that window is an open Install agent-vm window.
install_is() {
    [ "$(ui_get install "$1")" = "1" ]
}

# install_enter <uuid>  ->  0 when the handler that runs may act on a click: no other click of
# the window is still being worked on (a second Download and Install would install twice). The
# mark is the window's value "busy", as "click-<the handler's process>"; one whose process is
# gone holds nothing. install_leave removes this handler's mark and its temporary folder.
install_enter() {
    local _holder="$(ui_get busy "$1")"
    case "$_holder" in
        click-|click-0*|click-*[!0123456789]*) ;;
        click-*)
            kill -0 "${_holder#click-}" 2>/dev/null && return 1 ;;
    esac
    ui_set busy "$1" "click-$$"
    install_busy_uuid="$1"
    trap 'install_leave' EXIT
    return 0
}
install_leave() {
    # A handler ended while installer runs (a signal, say) leaves the folder: installer, which
    # goes on by itself, still reads the package and the changes file from it.
    if [ "${install_in_flight:-0}" != "1" ]; then
        case "${install_folder:-}" in
            */AgentVM-install.*) /bin/rm -rf "$install_folder" ;;
        esac
    fi
    [ "$("$pasteboard" "$INSTALL_RUNNING_KEY" get)" = "$$" ] && "$pasteboard" "$INSTALL_RUNNING_KEY" set ""
    [ -n "${install_busy_uuid:-}" ] || return 0
    [ "$(ui_get busy "$install_busy_uuid")" = "click-$$" ] || return 0
    ui_set busy "$install_busy_uuid" ""
}

# install_one_line <text>  ->  the text on one line, runs of blanks as one.
install_one_line() {
    printf '%s' "$1" | /usr/bin/tr '\t\r\n' '   ' | /usr/bin/sed 's/  */ /g; s/^ //; s/ $//'
    printf '\n'
}

# install_valid_version <text>  ->  0 when it is a version as agent-vm's tags are: numbers
# joined by dots. It becomes part of an address and of a file's name.
install_valid_version() {
    case "$1" in
        ''|*[!0123456789.]*|.*|*.|*..*) return 1 ;;
    esac
    case "$1" in
        *.*) return 0 ;;
    esac
    return 1
}

# install_installed_version  ->  the version ~/.local/bin/agent-vm reports, or nothing. The
# installed one, whichever agent-vm the app is set to run.
install_installed_version() {
    [ -f "$agentvm_installed" ] && [ -x "$agentvm_installed" ] || return 0
    local _said
    _said="$("$agentvm_installed" --version 2>/dev/null </dev/null)"
    local _status=$?
    [ "$_status" -eq 0 ] || return 0
    _said="$(printf '%s\n' "$_said" | /usr/bin/tail -1)"
    install_valid_version "$_said" || return 0
    printf '%s\n' "$_said"
}

# install_newest  ->  the newest release's version on stdout and 0; otherwise why it could not
# be learned, and 1. GitHub redirects .../releases/latest to .../releases/tag/<tag>; with no
# release it redirects to the list.
install_newest() {
    local _where
    _where="$("$curl_tool" --silent --show-error --head --location --proto =https --proto-redir =https \
        --max-time 30 --output /dev/null --write-out '%{url_effective}' "$install_releases/latest" 2>"$agentvm_err_file.curl" </dev/null)"
    local _status=$?
    local _said="$(install_one_line "$(/bin/cat "$agentvm_err_file.curl" 2>/dev/null)")"
    /bin/rm -f "$agentvm_err_file.curl"
    if [ "$_status" -ne 0 ]; then
        printf 'GitHub could not be asked for the newest agent-vm: %s\n' "${_said:-curl status $_status}"
        return 1
    fi
    case "$_where" in
        "$install_releases/tag/"*) ;;
        *)  printf 'GitHub names no newest agent-vm release (see %s).\n' "$install_releases"
            return 1 ;;
    esac
    local _version="${_where#"$install_releases/tag/"}"
    if ! install_valid_version "$_version"; then
        printf 'The newest agent-vm release has a tag that is not a version (see %s).\n' "$install_releases"
        return 1
    fi
    printf '%s\n' "$_version"
}

# install_download <version> <folder>  ->  the release's package in the folder, and 0; otherwise
# why not, and 1. A download that stays below 1000 bytes a second for a minute fails, as does
# one that takes over half an hour or is past 200 MB (the package is a few megabytes).
install_download() {
    local _name="agent-vm_$1.pkg"
    local _said
    _said="$("$curl_tool" --silent --show-error --fail --location --proto =https --proto-redir =https \
        --speed-limit 1000 --speed-time 60 --max-time 1800 --max-filesize 209715200 --output "$2/$_name" "$install_releases/download/$1/$_name" 2>&1 </dev/null)"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        printf 'Could not download %s: %s\n' "$_name" "$(install_one_line "${_said:-curl status $_status}")"
        return 1
    fi
    if [ ! -s "$2/$_name" ]; then
        printf 'The download of %s left no file.\n' "$_name"
        return 1
    fi
    return 0
}

# install_verify <package>  ->  0 when the package is notarized Developer ID software signed by
# agent-vm's team; otherwise why it is not installed, and 1.
install_verify() {
    local _name="${1##*/}"
    local _said
    _said="$("$spctl_tool" --assess --type install --verbose "$1" 2>&1 </dev/null)"
    local _status=$?
    local _notarized="$(printf '%s\n' "$_said" | /usr/bin/grep -c '^source=Notarized Developer ID$')"
    if [ "$_status" -ne 0 ] || [ "${_notarized:-0}" -eq 0 ]; then
        printf '%s is not notarized Developer ID software, so it was not installed (%s).\n' "$_name" "$(install_one_line "${_said:-spctl status $_status}")"
        return 1
    fi
    _said="$("$pkgutil_tool" --check-signature "$1" 2>&1 </dev/null)"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        printf 'The signature of %s could not be checked, so it was not installed: %s\n' "$_name" "$(install_one_line "$_said")"
        return 1
    fi
    # The first certificate of the chain is the signer's: "1. Developer ID Installer: Name (TEAM)".
    local _team="$(printf '%s\n' "$_said" | /usr/bin/sed -n 's/^ *1\. Developer ID Installer: .*(\([A-Z0-9]*\)) *$/\1/p' | /usr/bin/head -1)"
    if [ -z "$_team" ]; then
        printf '%s is not signed with a Developer ID Installer certificate, so it was not installed.\n' "$_name"
        return 1
    fi
    if [ "$_team" != "$install_team" ]; then
        printf '%s is signed by the Developer ID team %s, not agent-vm'"'"'s (%s), so it was not installed.\n' "$_name" "$_team" "$install_team"
        return 1
    fi
    return 0
}

# install_parts <package> <folder> <1|0: the PATH part too>  ->  the choice changes file
# <folder>/choices.plist, and 0; otherwise why nothing is installed, and 1. installer confirms
# the selection before anything is installed: changing one part can change another.
install_parts() {
    local _name="${1##*/}"
    "$installer_tool" -showChoiceChangesXML -pkg "$1" -target CurrentUserHomeDirectory > "$2/parts.xml" 2>"$2/parts.err" </dev/null
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        printf 'installer could not list the parts of %s: %s\n' "$_name" "$(install_one_line "$(/bin/cat "$2/parts.err")")"
        return 1
    fi
    local _parts
    _parts="$(/usr/bin/plutil -convert json -o - "$2/parts.xml" 2>/dev/null | /usr/bin/jq -r '[.[] | .choiceIdentifier | strings] | unique | .[]' 2>/dev/null)"
    local _has="$(printf '%s\n' "$_parts" | /usr/bin/grep -c -x -F "$install_agentvm_choice")"
    if [ "$_has" -eq 0 ]; then
        printf '%s has no agent-vm part, so AgentVM cannot tell what it would install. See %s.\n' "$_name" "$install_releases"
        return 1
    fi
    printf '%s\n' "$_parts" | /usr/bin/jq -R -n --arg agentvm "$install_agentvm_choice" --arg path "$install_path_choice" --arg with_path "$3" '
        [inputs | select(length > 0) | {choiceIdentifier: ., choiceAttribute: "selected",
            attributeSetting: (if . == $agentvm then 1 elif . == $path and $with_path == "1" then 1 else 0 end)}]' > "$2/choices.json"
    _status=$?
    [ "$_status" -eq 0 ] && /usr/bin/plutil -convert xml1 -o "$2/choices.plist" "$2/choices.json" 2>/dev/null
    _status=$?
    if [ "$_status" -ne 0 ] || [ ! -s "$2/choices.plist" ]; then
        printf 'The parts of %s to install could not be written down, so nothing was installed.\n' "$_name"
        return 1
    fi
    "$installer_tool" -showChoicesAfterApplyingChangesXML "$2/choices.plist" -pkg "$1" -target CurrentUserHomeDirectory > "$2/confirmed.xml" 2>"$2/parts.err" </dev/null
    _status=$?
    if [ "$_status" -ne 0 ]; then
        printf 'installer could not confirm the parts to install from %s: %s\n' "$_name" "$(install_one_line "$(/bin/cat "$2/parts.err")")"
        return 1
    fi
    # What installer would select, against what was asked: the parts that differ. Any setting but
    # 0 or false counts as selected (a group selected in part is -1).
    local _wrong
    _wrong="$(/usr/bin/plutil -convert json -o - "$2/confirmed.xml" 2>/dev/null | /usr/bin/jq -r --arg agentvm "$install_agentvm_choice" --arg path "$install_path_choice" --arg with_path "$3" '
        [.[] | select(.choiceAttribute == "selected")
             | {key: (.choiceIdentifier | tostring), value: (.attributeSetting != 0 and .attributeSetting != false)}] | from_entries as $selected
        | "read:" + ([($selected | to_entries[] | select(.value != (.key == $agentvm or (.key == $path and $with_path == "1"))) | .key),
           (if $selected[$agentvm] == null then $agentvm else empty end)] | unique | join(", "))' 2>/dev/null)"
    _status=$?
    # jq says "read:" only when it had an answer to read: given nothing (an answer plutil could
    # not convert), it says nothing and still ends well.
    case "$_wrong" in
        read:*) _wrong="${_wrong#read:}" ;;
        *)      _status=1 ;;
    esac
    if [ "$_status" -ne 0 ]; then
        printf 'installer'"'"'s answer about the parts of %s could not be read, so nothing was installed.\n' "$_name"
        return 1
    fi
    if [ -n "$_wrong" ]; then
        printf '%s does not let AgentVM install only the parts chosen (%s), so nothing was installed. See %s.\n' "$_name" "$_wrong" "$install_releases"
        return 1
    fi
    return 0
}

# install_run <uuid> <package> <folder> <version>  ->  installer run on the package with the
# changes file, its percentage shown in the window's bar; 0 when it ended well, otherwise why
# not, and 1.
install_run() {
    local _name="${2##*/}"
    "$installer_tool" -pkg "$2" -target CurrentUserHomeDirectory -applyChoiceChangesXML "$3/choices.plist" -verboseR > "$3/installer.log" 2>&1 </dev/null &
    local _pid=$!
    local _began="$(/bin/date +%s)"
    local _now _percent
    local _stalled=0
    while kill -0 "$_pid" 2>/dev/null; do
        "$sleep_tool" 1
        _percent="$(/usr/bin/sed -n 's/^installer:%\([0-9][0-9]*\).*$/\1/p' "$3/installer.log" 2>/dev/null | /usr/bin/tail -1)"
        if [ -n "$_percent" ]; then
            "$dialog" "$1" "$INSTALL_BAR_ID" "$_percent" >/dev/null
            "$dialog" "$1" "$INSTALL_STATUS_ID" "Installing agent-vm $4 ($_percent%)" >/dev/null
        fi
        _now="$(/bin/date +%s)"
        if [ "$((_now - _began))" -ge "$install_timeout" ]; then
            _stalled=1
            # Asked to end, and after five seconds made to: one that ignores the first would hold
            # this handler, and the window, for good.
            kill "$_pid" 2>/dev/null
            while kill -0 "$_pid" 2>/dev/null; do
                "$sleep_tool" 1
                _now="$(/bin/date +%s)"
                [ "$((_now - _began))" -ge "$((install_timeout + 5))" ] && kill -9 "$_pid" 2>/dev/null
            done
            break
        fi
    done
    wait "$_pid"
    local _status=$?
    if [ "$_stalled" -eq 1 ]; then
        printf 'Installing %s did not finish within %s minutes, and AgentVM stopped waiting for it. /var/log/install.log shows what installer was waiting for; try again once that has ended.\n' "$_name" "$((install_timeout / 60))"
        return 1
    fi
    if [ "$_status" -ne 0 ]; then
        # Its last words: what it said besides progress, or else its last phase and status lines.
        local _words="$(/usr/bin/awk '
            /^installer:%/ || /^[ \t]*$/                     { next }
            /^installer:PHASE:/ || /^installer:STATUS:/       { phase = phase " " $0; next }
            { said = said " " $0 }
            END { print (said != "" ? said : phase) }' "$3/installer.log" 2>/dev/null)"
        printf 'Could not install %s: %s (/var/log/install.log has the details).\n' "$_name" "$(install_one_line "${_words:-installer status $_status}")"
        return 1
    fi
    return 0
}

# install_check <version>  ->  0 when ~/.local/bin/agent-vm now reports that version; otherwise
# what it reports, and 1.
install_check() {
    local _have="$(install_installed_version)"
    [ "$_have" = "$1" ] && return 0
    if [ ! -x "$agentvm_installed" ]; then
        printf 'The installation ended, and agent-vm %s is not installed: there is no agent-vm at %s (/var/log/install.log has the details).\n' "$1" "$(agentvm_display_path "$agentvm_installed")"
    else
        printf 'The installation ended, and agent-vm %s is not installed: %s reports %s (/var/log/install.log has the details).\n' "$1" "$(agentvm_display_path "$agentvm_installed")" "${_have:-no version}"
    fi
    return 1
}

# install_paint <uuid> <head> <status> <1|0: the button is on>  ->  the window's lines and button,
# with the note under the checkbox: which agent-vm the app runs when it is not the installed
# one, and what an update leaves alone.
install_paint() {
    "$dialog" "$1" "$INSTALL_HEAD_ID" "$2"
    "$dialog" "$1" "$INSTALL_STATUS_ID" "$3"
    ui_enable "$1" "$INSTALL_BUTTON_ID" "$4"
    ui_enable "$1" "$INSTALL_PATH_ID" "$4"
    ui_show "$1" "$INSTALL_BAR_ID" 0
    local _note=""
    case "$(agentvm_origin)" in
        developer)
            _note="AgentVM is set to run a developer agent-vm ($(agentvm_display_path "$(agentvm_bin)")) and keeps doing so. The one installed here is the one Terminal and Cadabra run." ;;
        *)  [ -n "$(install_installed_version)" ] && _note="Boxes that are running keep the agent-vm they were started with until they are stopped." ;;
    esac
    "$dialog" "$1" "$INSTALL_NOTE_ID" "$_note"
}

# install_refresh <uuid>  ->  GitHub asked for the newest release, the installed agent-vm asked
# for its version, and the window painted: what would be installed, and whether there is
# anything to install.
install_refresh() {
    local _uuid="$1"
    "$dialog" "$_uuid" "$INSTALL_HEAD_ID" "Asking GitHub for the newest agent-vm..."
    ui_enable "$_uuid" "$INSTALL_BUTTON_ID" 0
    local _newest
    _newest="$(install_newest)"
    local _status=$?
    install_is "$_uuid" || return 0
    local _have="$(install_installed_version)"
    local _installed="agent-vm is not installed."
    [ -n "$_have" ] && _installed="agent-vm $_have is installed."
    if [ "$_status" -ne 0 ]; then
        # Download and Install asks again, so the button stays.
        install_paint "$_uuid" "$_installed" "$_newest" 1
        return 0
    fi
    ui_set newest "$_uuid" "$_newest"
    agentvm_version_at_least "$_newest" "$AGENTVM_MIN_VERSION"
    local _enough=$?
    if [ "$_enough" -ne 0 ]; then
        install_paint "$_uuid" "$_installed" "The newest agent-vm release is $_newest, and this AgentVM needs $AGENTVM_MIN_VERSION or newer. It is not released yet: see $install_releases." 0
        return 0
    fi
    if [ -n "$_have" ]; then
        agentvm_version_at_least "$_have" "$_newest"
        local _current=$?
        if [ "$_current" -eq 0 ] && [ "$_have" != "$_newest" ]; then
            install_paint "$_uuid" "agent-vm $_have is installed, which is newer than the newest release, $_newest." "" 0
            return 0
        fi
        if [ "$_current" -eq 0 ]; then
            install_paint "$_uuid" "agent-vm $_have is installed, and it is the newest." "" 0
            return 0
        fi
        install_paint "$_uuid" "agent-vm $_newest is available. $_installed" "" 1
        return 0
    fi
    install_paint "$_uuid" "agent-vm $_newest is the newest. $_installed" "" 1
}

# install_fail <uuid> <why>  ->  the window as it is after a step failed: why, and the button on
# again. Nothing was installed, or the check after installing says what is there.
install_fail() {
    install_is "$1" || return 0
    "$dialog" "$1" "$INSTALL_STATUS_ID" "$2"
    ui_show "$1" "$INSTALL_BAR_ID" 0
    ui_enable "$1" "$INSTALL_BUTTON_ID" 1
    ui_enable "$1" "$INSTALL_PATH_ID" 1
}

# install_perform <uuid> <1|0: the PATH part too>  ->  Download and Install: the steps of the
# header, each said in the status line. A window that closes before installing begins stops it;
# after that it runs to its end. On success every open main window reads agent-vm again.
install_perform() {
    local _uuid="$1"
    local _other="$("$pasteboard" "$INSTALL_RUNNING_KEY" get)"
    case "$_other" in
        ''|0*|*[!0123456789]*) ;;
        *)  if kill -0 "$_other" 2>/dev/null; then
                install_fail "$_uuid" "agent-vm is being installed already. Wait for that to end, then look again."
                return 1
            fi ;;
    esac
    ui_enable "$_uuid" "$INSTALL_BUTTON_ID" 0
    ui_enable "$_uuid" "$INSTALL_PATH_ID" 0
    "$dialog" "$_uuid" "$INSTALL_STATUS_ID" "Asking GitHub for the newest agent-vm..."
    local _version
    _version="$(install_newest)"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        install_fail "$_uuid" "$_version"
        return 1
    fi
    agentvm_version_at_least "$_version" "$AGENTVM_MIN_VERSION"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        install_fail "$_uuid" "The newest agent-vm release is $_version, and this AgentVM needs $AGENTVM_MIN_VERSION or newer, so it was not installed."
        return 1
    fi
    install_folder="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/AgentVM-install.XXXXXX")"
    _status=$?
    if [ "$_status" -ne 0 ] || [ ! -d "$install_folder" ]; then
        install_folder=""
        install_fail "$_uuid" "A temporary folder for the download could not be made."
        return 1
    fi
    local _package="$install_folder/agent-vm_$_version.pkg"
    local _why
    "$dialog" "$_uuid" "$INSTALL_STATUS_ID" "Downloading agent-vm $_version..."
    _why="$(install_download "$_version" "$install_folder")"
    _status=$?
    if [ "$_status" -eq 0 ]; then
        "$dialog" "$_uuid" "$INSTALL_STATUS_ID" "Checking the signature of agent-vm_$_version.pkg..."
        _why="$(install_verify "$_package")"
        _status=$?
    fi
    if [ "$_status" -eq 0 ]; then
        _why="$(install_parts "$_package" "$install_folder" "$2")"
        _status=$?
    fi
    if [ "$_status" -ne 0 ]; then
        install_fail "$_uuid" "$_why"
        return 1
    fi
    # The last moment it can be stopped: by closing the window.
    install_is "$_uuid" || return 1
    "$pasteboard" "$INSTALL_RUNNING_KEY" set "$$"
    install_in_flight=1
    "$dialog" "$_uuid" "$INSTALL_STATUS_ID" "Installing agent-vm $_version..."
    "$dialog" "$_uuid" "$INSTALL_BAR_ID" 0
    ui_show "$_uuid" "$INSTALL_BAR_ID" 1
    _why="$(install_run "$_uuid" "$_package" "$install_folder" "$_version")"
    _status=$?
    install_in_flight=0
    "$pasteboard" "$INSTALL_RUNNING_KEY" set ""
    if [ "$_status" -eq 0 ]; then
        _why="$(install_check "$_version")"
        _status=$?
    fi
    if [ "$_status" -ne 0 ]; then
        install_fail "$_uuid" "$_why"
        return 1
    fi
    local _main="$(ui_item_window main window)"
    [ -n "$_main" ] && main_refresh "$_main" full
    install_is "$_uuid" || return 0
    local _path_note=""
    [ "$2" = "1" ] && _path_note=" Open a new Terminal window for avm and agent-vm to be found there."
    install_paint "$_uuid" "agent-vm $_version is installed, and it is the newest." "Installed.$_path_note" 0
    return 0
}
