#!/bin/sh
# lib.agentvm.ui.sh
#
# Window helpers shared by AgentVM.app's handlers: the OMC tools, per-window state, and the few
# system tools a window needs besides agent-vm. Sources lib.agentvm.sh, so a handler sources
# this one file (or a window's own library, which sources it).
#
# PER-WINDOW STATE. Two places, both keyed by the window's UUID: pasteboard keys for small values
# other handlers of the same window read (the selection, the poll loop's token), and a cache
# folder under $TMPDIR for what agent-vm last answered, so a handler that only repaints does not
# run agent-vm again. The window's close handler removes both.
#
# Seams for the tests: AGENTVM_APP_PS (the process list, which a sandboxed test cannot read),
# AGENTVM_APP_SLEEP (the poll loop's wait) and AGENTVM_APP_OPEN (Finder, for Show).
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_UI_LIB:-}" ] && return 0
__AGENTVM_APP_UI_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.sh"

dialog="$OMC_OMC_SUPPORT_PATH/omc_dialog_control"
next_command="$OMC_OMC_SUPPORT_PATH/omc_next_command"
pasteboard="$OMC_OMC_SUPPORT_PATH/pasteboard"
ps_tool="${AGENTVM_APP_PS:-/bin/ps}"
sleep_tool="${AGENTVM_APP_SLEEP:-/bin/sleep}"
open_tool="${AGENTVM_APP_OPEN:-/usr/bin/open}"
ui_tab="$(printf '\t')"

# ui_key <name> <window uuid>  ->  the pasteboard key of one value of one window.
ui_key() {
    printf 'agentvm_%s_%s\n' "$1" "$2"
}

# ui_get <name> <uuid>  ->  that value, or nothing. ui_set <name> <uuid> <value>.
ui_get() {
    "$pasteboard" "$(ui_key "$1" "$2")" get
}
ui_set() {
    "$pasteboard" "$(ui_key "$1" "$2")" set "$3"
}

# ui_cache <uuid> <name>  ->  the path of one cache file of that window (the folder exists).
ui_cache() {
    local _dir="${TMPDIR:-/tmp}/AgentVM/$1"
    [ -d "$_dir" ] || /bin/mkdir -p "$_dir"
    printf '%s/%s\n' "$_dir" "$2"
}

# ui_cache_clear <uuid>  ->  removes that window's cache folder.
ui_cache_clear() {
    [ -n "$1" ] || return 0
    /bin/rm -rf "${TMPDIR:-/tmp}/AgentVM/$1"
}

# ui_store <file>  ->  stdin becomes the file, replaced in one step: other handlers read the
# caches while the poll loop rewrites them, and a file truncated for rewriting would read as
# "no such row". A failed write leaves the old file.
ui_store() {
    /bin/cat > "$1.$$"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        /bin/rm -f "$1.$$"
        return "$_status"
    fi
    /bin/mv -f "$1.$$" "$1"
}

# ui_enable <uuid> <view id> <1|0>  and  ui_show <uuid> <view id> <1|0>.
ui_enable() {
    if [ "$3" = "1" ]; then
        "$dialog" "$1" "$2" omc_enable
    else
        "$dialog" "$1" "$2" omc_disable
    fi
}
ui_show() {
    if [ "$3" = "1" ]; then
        "$dialog" "$1" "$2" omc_show
    else
        "$dialog" "$1" "$2" omc_hide
    fi
}

# ui_process_name <pid>  ->  the name of the program running as that process, or nothing.
# For display only ("Cadabra" as a box's owner): a pid can be reused, so nothing is ever decided
# from it.
ui_process_name() {
    case "$1" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    local _command
    _command="$("$ps_tool" -p "$1" -o comm= 2>/dev/null)"
    local _status=$?
    if [ "$_status" -ne 0 ] || [ -z "$_command" ]; then
        return 0
    fi
    printf '%s\n' "${_command##*/}"
}

# ui_app_alive  ->  0 while the app that runs this handler is running. A loop that outlived the
# app (a quit while it slept) must end rather than poll agent-vm for nobody.
ui_app_alive() {
    [ -n "${OMC_APP_PROCESS_ID:-}" ] || return 1
    kill -0 "$OMC_APP_PROCESS_ID" 2>/dev/null
}

# ui_one_line <text>  ->  the text on one line: tabs and line breaks inside it become spaces.
# For agent-vm's messages, which go into a row of a cache file and into one Text.
ui_one_line() {
    printf '%s' "$1" | /usr/bin/tr '\t\n' '  '
    printf '\n'
}

# ui_seconds_since_epoch <ISO 8601 time, as agent-vm writes it: 2026-09-29T14:02:10Z>
#   ->  that time as seconds since 1970, or nothing when it is not in that form.
ui_seconds_since_epoch() {
    case "$1" in
        [0123456789][0123456789][0123456789][0123456789]-*T*Z) ;;
        *) return 0 ;;
    esac
    /bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null
}

# ui_names_text <name...>  ->  "a", "a and b", "a, b and c".
ui_names_text() {
    local _text=""
    local _count=$#
    local _i=0
    local _name
    for _name; do
        _i=$((_i + 1))
        if [ "$_i" -eq 1 ]; then
            _text="$_name"
        elif [ "$_i" -eq "$_count" ]; then
            _text="$_text and $_name"
        else
            _text="$_text, $_name"
        fi
    done
    printf '%s\n' "$_text"
}

# ui_lines_text <lines>  ->  the lines as "a", "a and b", "a, b and c", or "none".
ui_lines_text() {
    [ -n "$1" ] || {
        echo "none"
        return 0
    }
    local _saved="$IFS"
    IFS='
'
    set -- $1
    IFS="$_saved"
    ui_names_text "$@"
}

# ui_date_text <ISO 8601 time>  ->  its day in this Mac's time zone ("Sep 23, 2026"), or nothing.
ui_date_text() {
    local _seconds="$(ui_seconds_since_epoch "$1")"
    [ -n "$_seconds" ] || return 0
    /bin/date -r "$_seconds" '+%b %e, %Y' | /usr/bin/sed 's/  / /'
}

# ui_duration_text <seconds>  ->  "45 s", "2 min", "1 h 5 min", or nothing when it is not a number.
ui_duration_text() {
    case "$1" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    if [ "$1" -lt 60 ]; then
        printf '%s s\n' "$1"
        return 0
    fi
    # Rounded to whole minutes first, so 59 min 45 s is "1 h 0 min", never "60 min".
    local _minutes=$(( ($1 + 30) / 60 ))
    if [ "$_minutes" -lt 60 ]; then
        printf '%s min\n' "$_minutes"
    else
        printf '%s h %s min\n' "$(( _minutes / 60 ))" "$(( _minutes % 60 ))"
    fi
}

# ui_size_text <bytes>  ->  "37.4 GB" or "296 MB", in decimal units as agent-vm and Finder write
# them, or nothing when it is not a number.
ui_size_text() {
    case "$1" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    /usr/bin/awk -v b="$1" 'BEGIN {
        if (b >= 999500000) printf "%.1f GB\n", b / 1000000000
        else printf "%d MB\n", (b + 500000) / 1000000 }'
}

# -- Box windows ---------------------------------------------------------------------------------
# A box's network and its program log each open in a window of their own, one per box: the main
# window's box pane shows the overview only. A pasteboard key per box and kind names the open
# window as "<app pid> <window uuid>", so a second Details... brings that window to the front.
# Named pasteboards outlive the app, so an entry another run of the app left (a crash skips the
# close handler) is recognized by its pid and ignored; without a pid of its own, a handler takes
# no entry and no request for this run's.
#
# Opening one hands the box to the new window through a request key of its kind, read and cleared
# by the window's init handler, since a chained command carries no arguments. A key per kind, so
# that opening both of a box's windows in quick succession loses neither. The request carries the
# pid too: a window opened by a URL naming the command directly finds no request of this run's
# and closes itself.
#
# A job's progress window (lib.agentvm.progress.sh) is kept the same way, one per job: its kind is
# "progress", and the name is the job's id, which has the form of a name. So is an image's update
# window (lib.agentvm.update.sh): its kind is "update", and the name is the image's; and its Full
# Disk Access guide (lib.agentvm.access.sh), with the kind "access".

# The request key of a kind is this, an underscore and the kind.
AGENTVM_OPEN_REQUEST_KEY="agentvm_open_request"

# ui_item_key <network|programs> <box>  ->  the pasteboard key naming that box's window of that kind.
ui_item_key() {
    printf 'agentvm_window_%s_%s\n' "$1" "$2"
}

# ui_item_window <network|programs> <box>  ->  the uuid of this run's open window of that kind for
# the box, or nothing.
ui_item_window() {
    local _entry="$("$pasteboard" "$(ui_item_key "$1" "$2")" get)"
    [ -n "$_entry" ] && [ -n "${OMC_APP_PROCESS_ID:-}" ] || return 0
    [ "${_entry%% *}" = "$OMC_APP_PROCESS_ID" ] || return 0
    printf '%s\n' "${_entry#* }"
}

# ui_item_claim <network|programs> <box> <uuid>  ->  that window becomes the box's window of that kind.
ui_item_claim() {
    "$pasteboard" "$(ui_item_key "$1" "$2")" set "${OMC_APP_PROCESS_ID:-} $3"
}

# ui_item_release <network|programs> <box> <uuid>  ->  the box has no window of that kind, if that
# one was it.
ui_item_release() {
    local _window="$(ui_item_window "$1" "$2")"
    [ "$_window" = "$3" ] || return 0
    "$pasteboard" "$(ui_item_key "$1" "$2")" set ""
}

# ui_item_open <network|programs> <box> <command guid>  ->  that window of the box in front: the
# open one, or a new one, chained from the handler whose guid is given (AgentVM.network or
# AgentVM.programs).
ui_item_open() {
    agentvm_valid_name "$2" || return 1
    local _window="$(ui_item_window "$1" "$2")"
    if [ -n "$_window" ]; then
        "$dialog" "$_window" omc_window omc_select
        return 0
    fi
    "$pasteboard" "${AGENTVM_OPEN_REQUEST_KEY}_$1" set "${OMC_APP_PROCESS_ID:-} $1:$2"
    "$next_command" "$3" "AgentVM.$1"
}

# ui_item_close <network|programs> <box>  ->  that window of the box closed, if one is open: for a
# box that was deleted. Its close handler releases it.
ui_item_close() {
    local _window="$(ui_item_window "$1" "$2")"
    [ -n "$_window" ] || return 0
    "$dialog" "$_window" omc_window omc_terminate_cancel
}

# ui_item_request <network|programs>  ->  the box a new window of that kind was opened for, or
# nothing; the request is cleared either way, so it is read once.
ui_item_request() {
    local _request="$("$pasteboard" "${AGENTVM_OPEN_REQUEST_KEY}_$1" get)"
    "$pasteboard" "${AGENTVM_OPEN_REQUEST_KEY}_$1" set ""
    [ -n "$_request" ] && [ -n "${OMC_APP_PROCESS_ID:-}" ] || return 0
    [ "${_request%% *}" = "$OMC_APP_PROCESS_ID" ] || return 0
    local _item="${_request#* }"
    case "$_item" in
        "$1":*) ;;
        *) return 0 ;;
    esac
    agentvm_valid_name "${_item#*:}" || return 0
    printf '%s\n' "${_item#*:}"
}

# -- The agentvm URL scheme ----------------------------------------------------------------------
# agentvm://status, agentvm://box/<name> and agentvm://image/<name> bring the main window to the
# front, with that box or image selected (omc.app.handle-url.sh). The handler runs with no window
# of its own, so the main window names itself in a pasteboard entry, as the box windows do
# (ui_item_* with the kind "main" and the name "window"); and when no main window is open, what to
# show waits in a request the next main window's init handler takes, once. Both carry the app's
# pid, so what another run of the app left is ignored.
#
# A URL is text from outside the app: only these three forms are routed, a name must be one
# agent-vm accepts, and nothing a URL names is ever changed, only shown.

AGENTVM_GOTO_KEY="agentvm_goto"

# ui_url_target <url>  ->  "status", "box <name>" or "image <name>" for a URL the app routes, or
# nothing. The scheme and the first part are matched in any case, as URLs are; a query or a
# fragment is dropped; a name is taken as written, with no percent-decoding (a valid name needs
# none).
ui_url_target() {
    local _rest
    case "$1" in
        *://*) _rest="${1#*://}" ;;
        *) return 0 ;;
    esac
    local _scheme="$(printf '%s\n' "${1%%://*}" | /usr/bin/tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')"
    [ "$_scheme" = "agentvm" ] || return 0
    _rest="${_rest%%\?*}"
    _rest="${_rest%%#*}"
    _rest="${_rest%/}"
    local _kind="$(printf '%s\n' "${_rest%%/*}" | /usr/bin/tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')"
    local _name=""
    case "$_rest" in
        */*) _name="${_rest#*/}" ;;
    esac
    case "$_kind" in
        status)
            [ -z "$_name" ] && printf 'status\n' ;;
        box|image)
            agentvm_valid_name "$_name" && printf '%s %s\n' "$_kind" "$_name" ;;
    esac
    return 0
}

# ui_goto_set <target, as ui_url_target prints it>  ->  what the next main window shows on opening.
ui_goto_set() {
    "$pasteboard" "$AGENTVM_GOTO_KEY" set "${OMC_APP_PROCESS_ID:-} $1"
}

# ui_goto_take  ->  that target, if this run of the app left one, or nothing; cleared either way,
# so it is read once. Checked again as it is read: a pasteboard is not a trusted place.
ui_goto_take() {
    local _request="$("$pasteboard" "$AGENTVM_GOTO_KEY" get)"
    "$pasteboard" "$AGENTVM_GOTO_KEY" set ""
    [ -n "$_request" ] && [ -n "${OMC_APP_PROCESS_ID:-}" ] || return 0
    [ "${_request%% *}" = "$OMC_APP_PROCESS_ID" ] || return 0
    local _target="${_request#* }"
    case "$_target" in
        status) printf 'status\n' ;;
        "box "*|"image "*)
            agentvm_valid_name "${_target#* }" && printf '%s\n' "$_target" ;;
    esac
    return 0
}
