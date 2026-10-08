#!/bin/sh
# lib.agentvm.logs.sh
#
# The Where the Logs Are window (AgentVM.logs.json, the views 4302-4364): the records agent-vm
# keeps on this Mac of what a box ran and contacted, of a job, and of boxes that were deleted,
# by the folder they are in, each with the questions its files answer, Show in Finder and Copy
# Path; and the same asked of agent-vm in Terminal, as lines to copy. One
# window at a time (lib.agentvm.ui.sh, "Box windows", with the kind "logs" and the name
# "window"), opened from the How to Use a Box window and by the URL agentvm://logs.
#
# IT POINTS, AND READS NO LOG. The folders are the store's: Boxes, Jobs and Logs under the folder
# that holds the logs of deleted boxes, which `status` names. For how long those are kept, and how
# many are, is `status`'s to say too. It is read on opening and when the window comes to the
# front. The places are the cache file places.tsv (number, folder) and the lines for Terminal
# lines.tsv (number, command, what it does): Show in Finder and the two kinds of Copy act on what
# the window shows.
#
# It changes nothing: it only says where.
#
# Sources lib.agentvm.main.sh. POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_LOGS_LIB:-}" ] && return 0
__AGENTVM_APP_LOGS_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

LOGS_NOTE_ID=4302
# What is said of the logs of deleted boxes: for how long they are kept, and how many are.
LOGS_KEPT_ID=4305
# Place n has its folder in LOGS_FOLDER_BASE + n, Show in Finder in LOGS_SHOW_BASE + n and Copy
# Path in LOGS_PATH_BASE + n. The places: 1 the boxes' folders (what ran in a box, what it
# contacted, why it did not start or stopped), 2 the jobs' folders (why a build or an update
# failed), 3 the logs of deleted boxes.
LOGS_FOLDER_BASE=4310
LOGS_SHOW_BASE=4320
LOGS_PATH_BASE=4330
LOGS_PLACES=3
# Line n for Terminal has its command in LOGS_COMMAND_BASE + n, its Copy button in
# LOGS_COPY_BASE + n and what it does in LOGS_WHAT_BASE + n.
LOGS_COMMAND_BASE=4340
LOGS_COPY_BASE=4350
LOGS_WHAT_BASE=4360
LOGS_LINES=4

# logs_is <uuid>  ->  0 while that window is an open Where the Logs Are window.
logs_is() {
    [ "$(ui_get logs "$1")" = "1" ]
}

# logs_read <uuid> [full]  ->  `status` read anew, for the store's folder, what it keeps of
# deleted boxes and the names the lines use; "full" first checks which agent-vm runs (on
# opening). An agent-vm that cannot be used is not run: the window then shows the folders of
# the store the app would use.
logs_read() {
    if [ "${2:-}" = "full" ]; then
        main_read_agentvm "$1" >/dev/null
    fi
    [ "$(main_agentvm_line "$1" 1)" = "0" ] || return 1
    main_read_status "$1"
}

# logs_store <uuid>  ->  the store's folder: the one that holds the folder of the kept logs, as
# `status` names it; before agent-vm said, the store the app has agent-vm use (the setting
# agentVMHome), else agent-vm's own default.
logs_store() {
    local _kept="$(main_kept_logs "$1" 4)"
    case "$_kept" in
        /*/*)
            printf '%s\n' "${_kept%/*}"
            return 0 ;;
    esac
    local _home="$(agentvm_setting agentVMHome)"
    case "$_home" in
        /*) printf '%s\n' "$_home" ;;
        *)  printf '%s/Library/Application Support/agent-vm\n' "$HOME" ;;
    esac
}

# logs_place_rows <uuid>  ->  the places: number, folder.
logs_place_rows() {
    local _store="$(logs_store "$1")"
    local _kept="$(main_kept_logs "$1" 4)"
    case "$_kept" in
        /*) ;;
        *)  _kept="$_store/Logs" ;;
    esac
    printf '1\t%s/Boxes\n2\t%s/Jobs\n3\t%s\n' "$_store" "$_store" "$_kept"
}

# logs_place <uuid> <n>  ->  the folder of place n as the window shows it, or nothing.
logs_place() {
    case "$2" in
        1|2|3) ;;
        *) return 0 ;;
    esac
    main_rows "$1" places | /usr/bin/awk -F'\t' -v n="$2" '$1 "" == n { print $2; exit }'
}

# logs_kept_text <uuid>  ->  what is said of the logs of deleted boxes: for how long agent-vm
# keeps them, and how many it keeps now.
logs_kept_text() {
    local _days="$(main_kept_days_text "$1")"
    if [ -z "$_days" ]; then
        if [ "$(main_kept_logs "$1" 3)" = "0" ]; then
            printf 'This store keeps no logs of deleted boxes: a box that is deleted leaves none.\n'
        else
            printf 'The same files, in a folder named after the box and the time it was deleted.\n'
        fi
        return 0
    fi
    local _count="$(main_kept_logs "$1" 1)"
    local _now="none are kept now"
    case "$_count" in
        ''|0|*[!0123456789]*) ;;
        1) _now="1 box's are kept now" ;;
        *) _now="$_count boxes' are kept now" ;;
    esac
    printf 'The same files, kept for %s in a folder named after the box and the time; %s.\n' "$_days" "$_now"
}

# logs_line_rows <uuid>  ->  the lines for Terminal: number, command, what it does. They name what
# exists: the first box and the newest job of `status`, or "work" and a list of the jobs.
logs_line_rows() {
    local _box="$(main_rows "$1" boxes | /usr/bin/sed -n '1p' | /usr/bin/cut -f1)"
    local _note=""
    if [ -z "$_box" ]; then
        _box="work"
        _note=" No box exists yet: work stands for one you make."
    fi
    local _job="$(main_rows "$1" jobs | /usr/bin/awk -F'\t' '$1 "" > newest "" { newest = $1 } END { print newest }')"
    printf '1\tagent-vm box execlog %s\tThe programs agent-vm started in box "%s".%s\n' "$_box" "$_box" "$_note"
    printf '2\tagent-vm box netlog %s --denied\tThe connections it was refused; without --denied, all of them.\n' "$_box"
    if agentvm_valid_job_id "$_job"; then
        printf '3\tagent-vm job log %s\tWhat the newest job wrote; agent-vm job list names the others.\n' "$_job"
    else
        printf '3\tagent-vm job list\tThe jobs of the last week; agent-vm job log, with an id, prints what one wrote.\n'
    fi
    printf '4\tagent-vm store logs\tThe logs kept of deleted boxes, with their sizes.\n'
}

# logs_paint <uuid>  ->  the places and the lines, kept as places.tsv and lines.tsv for the
# buttons, what is said of the kept logs, and the note: why agent-vm could not be asked, if it
# could not. Show in Finder is on for a folder that is on this Mac.
logs_paint() {
    logs_place_rows "$1" | ui_store "$(ui_cache "$1" places.tsv)"
    logs_line_rows "$1" | ui_store "$(ui_cache "$1" lines.tsv)"
    main_rows "$1" places | {
        local _n _folder
        while IFS="$ui_tab" read -r _n _folder; do
            "$dialog" "$1" "$(( LOGS_FOLDER_BASE + _n ))" "$(agentvm_display_path "$_folder")"
            if [ -d "$_folder" ]; then
                ui_enable "$1" "$(( LOGS_SHOW_BASE + _n ))" 1
            else
                ui_enable "$1" "$(( LOGS_SHOW_BASE + _n ))" 0
            fi
        done
    }
    main_rows "$1" lines | {
        local _n _command _what
        while IFS="$ui_tab" read -r _n _command _what; do
            "$dialog" "$1" "$(( LOGS_COMMAND_BASE + _n ))" "$_command"
            "$dialog" "$1" "$(( LOGS_WHAT_BASE + _n ))" "$_what"
        done
    }
    "$dialog" "$1" "$LOGS_KEPT_ID" "$(logs_kept_text "$1")"
    local _note=""
    if [ "$(main_agentvm_line "$1" 1)" != "0" ]; then
        _note="$(main_agentvm_line "$1" 2)"
    else
        local _error="$(main_status_error "$1")"
        [ -n "$_error" ] && _note="agent-vm could not be read: $_error"
    fi
    "$dialog" "$1" "$LOGS_NOTE_ID" "$_note"
}

# logs_refresh <uuid> [full]  ->  reads and paints. For the window that closed while agent-vm
# was read, or while this painted (painting reads the cache, which makes its folder again), the
# cache folder goes: so whether the window is still there is asked once more, last.
logs_refresh() {
    logs_read "$1" "${2:-}"
    if ! logs_is "$1"; then
        ui_cache_clear "$1"
        return 0
    fi
    logs_paint "$1"
    logs_is "$1" || ui_cache_clear "$1"
    return 0
}

# logs_show <uuid> <place number>  ->  that place's folder opened in Finder, when it is on this
# Mac.
logs_show() {
    local _folder="$(logs_place "$1" "$2")"
    [ -n "$_folder" ] && [ -d "$_folder" ] || return 0
    "$open_tool" "$_folder"
}

# logs_put <uuid> <text>  ->  0 with the text on the clipboard, and the note saying so; 1 when
# there is nothing to copy or the clipboard could not be written. The text goes to pbcopy's
# stdin, as the window shows it.
logs_put() {
    [ -n "$2" ] || return 1
    printf '%s' "$2" | "$pbcopy_tool"
    local _status=$?
    [ "$_status" -eq 0 ] || return 1
    "$dialog" "$1" "$LOGS_NOTE_ID" "Copied: $2"
    return 0
}

# logs_copy_path <uuid> <place number>  ->  that place's folder, as a full path, on the clipboard.
logs_copy_path() {
    logs_put "$1" "$(logs_place "$1" "$2")"
}

# logs_copy_line <uuid> <line number>  ->  that line's command on the clipboard.
logs_copy_line() {
    case "$2" in
        1|2|3|4) ;;
        *) return 1 ;;
    esac
    logs_put "$1" "$(main_rows "$1" lines | /usr/bin/awk -F'\t' -v n="$2" '$1 "" == n { print $2; exit }')"
}
