#!/bin/sh
# lib.agentvm.programs.sh
#
# A box's programs window (AgentVM.programs.json, the views 651-654): what `agent-vm exec` and
# `box shell` ran in the box, newest first, and the permission prompts programs waited on. One
# window per box (lib.agentvm.ui.sh, "Box windows"); the box's name is the window's pasteboard
# value "box", set by the init handler from the open request. Sources lib.agentvm.main.sh for
# reading `status` into the window's own cache (main_read_status, main_row).
#
# WHEN IT READS: on opening, on every activation and on Refresh; there is no poll loop.
#
# A PROGRAM WITH NO END. agent-vm records a program's exit status when it ends; a program still
# running and one whose client died without writing an end both have none. The window calls it
# running only while the box runs and its client process on this Mac (hostPid) still exists, and
# "no end recorded" otherwise. A pid can be reused, so a long-dead client may still read as
# running while the box runs; that is all the record allows.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_PROGRAMS_LIB:-}" ] && return 0
__AGENTVM_APP_PROGRAMS_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

PROG_TABLE_ID=651
PROG_NOTICES_ID=652
PROG_REFRESH_ID=653
PROG_NOTE_ID=654

# How many of the last programs the window reads.
PROG_EXECLOG_LAST=200
# How many prompt notices the window lists, and how much of each command: the notices sit under
# the table with no scrolling of their own, so they are kept short.
PROG_NOTICES_MAX=5
PROG_NOTICE_COMMAND_MAX=60

# prog_file <uuid> <box> <rows|error>  ->  that file of the box's programs, in the window's cache.
prog_file() {
    ui_cache "$1" "prog-$2.$3"
}

# prog_read <uuid> <box>  ->  0 with the box's last programs in its rows file (agentvm_execlog_rows);
# agent-vm's status otherwise, with its message in the error file (empty after a success).
prog_read() {
    agentvm_valid_name "$2" || return 2
    local _json
    _json="$(agentvm_box_execlog "$2" "$PROG_EXECLOG_LAST")"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        ui_one_line "$(agentvm_last_error "$_status")" | ui_store "$(prog_file "$1" "$2" error)"
        return "$_status"
    fi
    printf '%s\n' "$_json" | agentvm_execlog_rows | ui_store "$(prog_file "$1" "$2" rows)"
    : | ui_store "$(prog_file "$1" "$2" error)"
    return 0
}

# prog_live_pids <rows file> <box state> <programs running in it now>  ->  " 1 2 " : the clients of
# programs with no end that still exist, between spaces, for awk's index(); nothing unless the box
# runs and agent-vm counts a program running in it now, which narrows what a reused pid can fake.
prog_live_pids() {
    case "$2" in
        running|unresponsive) ;;
        *) return 0 ;;
    esac
    case "$3" in
        ""|-|0|*[!0123456789]*) return 0 ;;
    esac
    local _pids="$(/usr/bin/awk -F'\t' '$3 == "-" && $6 ~ /^[123456789][0123456789]*$/ { print $6 }' "$1")"
    local _live=" "
    local _pid
    for _pid in $_pids; do
        kill -0 "$_pid" 2>/dev/null && _live="$_live$_pid "
    done
    printf '%s\n' "$_live"
}

# prog_table_rows <uuid> <box>  ->  the table's rows: started, command, its status (the exit status
# and what it means; running; stopped at a prompt; no end recorded), how long it ran, user. The
# command comes second: it is what the row is about.
prog_table_rows() {
    local _rows="$(prog_file "$1" "$2" rows)"
    [ -f "$_rows" ] || return 0
    local _row="$(main_row "$1" boxes "$2")"
    local _state="$(printf '%s\n' "$_row" | /usr/bin/cut -f2)"
    local _execs="$(printf '%s\n' "$_row" | /usr/bin/cut -f10)"
    /usr/bin/awk -F'\t' -v live="$(prog_live_pids "$_rows" "$_state" "$_execs")" '
        function took(s) {
            if (s == "-") return "-"
            if (s < 1) return "under 1 s"
            if (s < 60) return s " s"
            m = int((s + 30) / 60)
            if (m < 60) return m " min"
            return int(m / 60) " h " (m % 60) " min"
        }
        NF {
            status = $3
            if ($3 == "-") status = index(live, " " $6 " ") ? "running" : "no end recorded"
            else if ($3 == "0") status = "0, done"
            else if ($3 == "125") status = "125, exec failed"
            else if ($3 == "126") status = "126, not runnable"
            else if ($3 == "127") status = "127, not found"
            else if ($3 + 0 > 128 && $3 + 0 < 160) status = $3 ", signal " ($3 - 128)
            if ($8 == "true") status = status ", stopped at a prompt"
            printf "%s\t%s\t%s\t%s\t%s\n", $1, $5, status, took($2), $4
        }' "$_rows"
}

# prog_notices_text <uuid> <box>  ->  the programs that waited on a permission prompt, newest
# first, at most PROG_NOTICES_MAX, with their commands cut to PROG_NOTICE_COMMAND_MAX characters;
# and when the box's image needs Full Disk Access, which spares its boxes the folder prompts, a
# line saying so. Nothing when no program waited on one.
prog_notices_text() {
    local _rows="$(prog_file "$1" "$2" rows)"
    [ -f "$_rows" ] || return 0
    local _lines="$(/usr/bin/awk -F'\t' -v max="$PROG_NOTICES_MAX" -v width="$PROG_NOTICE_COMMAND_MAX" '
        $7 != "-" && n < max {
            n++
            command = $5
            if (length(command) > width) command = substr(command, 1, width - 3) "..."
            printf "%s  %s waited on a permission prompt: %s.\n", $1, command, $7
        }' "$_rows")"
    [ -n "$_lines" ] || return 0
    printf '%s\n' "$_lines"
    local _image="$(main_row "$1" boxes "$2" | /usr/bin/cut -f3)"
    local _needs="$(main_row "$1" images "$_image" | /usr/bin/cut -f8)"
    case ",$_needs," in
        *,full-disk-access,*)
            printf 'Image %s needs Full Disk Access: until it has it, programs in its boxes are asked before they open Desktop, Documents or Downloads.\n' "$_image" ;;
    esac
    return 0
}

# prog_problem <uuid> <box>  ->  why the window cannot show the box now: `status` failed, or it no
# longer lists the box. Nothing when it can.
prog_problem() {
    local _error="$(main_status_error "$1")"
    if [ -n "$_error" ]; then
        printf '%s\n' "$_error"
    elif [ -z "$(main_row "$1" boxes "$2")" ]; then
        printf 'Box %s no longer exists.\n' "$2"
    fi
}

# prog_paint <uuid>  ->  the window from the caches, for its box. When the box cannot be shown
# (prog_problem), the table and the notices are empty and the note says why.
prog_paint() {
    local _uuid="$1"
    local _box="$(ui_get box "$_uuid")"
    [ -n "$_box" ] || return 0
    agentvm_valid_name "$_box" || return 0
    local _problem="$(prog_problem "$_uuid" "$_box")"
    if [ -n "$_problem" ]; then
        : | "$dialog" "$_uuid" "$PROG_TABLE_ID" omc_table_set_rows_from_stdin
        "$dialog" "$_uuid" "$PROG_NOTICES_ID" ""
        "$dialog" "$_uuid" "$PROG_NOTE_ID" "$_problem"
        return 0
    fi
    prog_table_rows "$_uuid" "$_box" | "$dialog" "$_uuid" "$PROG_TABLE_ID" omc_table_set_rows_from_stdin
    "$dialog" "$_uuid" "$PROG_NOTICES_ID" "$(prog_notices_text "$_uuid" "$_box")"
    local _error="$(/bin/cat "$(prog_file "$_uuid" "$_box" error)" 2>/dev/null)"
    local _rows="$(prog_file "$_uuid" "$_box" rows)"
    if [ -n "$_error" ]; then
        "$dialog" "$_uuid" "$PROG_NOTE_ID" "$_error"
    elif [ ! -f "$_rows" ]; then
        "$dialog" "$_uuid" "$PROG_NOTE_ID" "The programs have not been read yet."
    elif [ ! -s "$_rows" ]; then
        "$dialog" "$_uuid" "$PROG_NOTE_ID" "No program has run in this box yet."
    else
        "$dialog" "$_uuid" "$PROG_NOTE_ID" "The last $PROG_EXECLOG_LAST programs that agent-vm exec and box shell ran. The log stays on this Mac, out of the box's reach."
    fi
}

# prog_refresh <uuid>  ->  `status` read into the window's cache (the box's state and its image's
# needs decide what a row and the notices say), then the box's last programs, and the window
# painted. Nothing more is read for a box `status` does not list, or when `status` failed.
prog_refresh() {
    local _box="$(ui_get box "$1")"
    [ -n "$_box" ] && agentvm_valid_name "$_box" || return 0
    main_read_status "$1"
    local _status=$?
    if [ "$_status" -eq 0 ] && [ -n "$(main_row "$1" boxes "$_box")" ]; then
        prog_read "$1" "$_box"
    fi
    prog_paint "$1"
}
