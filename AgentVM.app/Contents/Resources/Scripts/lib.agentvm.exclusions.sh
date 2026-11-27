#!/bin/sh
# lib.agentvm.exclusions.sh
#
# The Exclusions window (AgentVM.exclusions.json, the views 5301-5311): which folders of a project
# its sessions leave out of their snapshots. One window at a time (lib.agentvm.ui.sh, "Box
# windows", with the kind "exclusions" and the name "window"), opened by Choose... on the
# Exclusions row of the Sessions tab's project pane (a project with no session yet gets a card,
# and so a pane, from the plus button in the tab's toolbar).
#
# THE PROJECT is the window's value "exclusions": its full path, handed over by the main window in
# a pasteboard entry of its own and read once by the init handler. It is also what says that the
# window is an open Exclusions window.
#
# WHAT IT SHOWS. On opening, `session scan` walks the project, which takes seconds for a large
# one; the window says so while it runs. It lists the folders that look like build output, those
# git ignores of 1 GB or more and any of 5 GB or more near the top, with their sizes, and the
# project's saved list. The table has a row per candidate and per saved path the scan did not
# find (a saved path need not exist), each with a checkbox: checked are the saved paths, or, for a
# project with nothing saved, what agent-vm suggests (plainly rebuildable). Add Folder... adds any
# other folder of the project, chosen in a folder panel that opens in the project (its command's
# DEFAULT_LOCATION reads the hidden view 5311, which holds the project's path), as a checked row;
# a folder outside the project is refused. Save replaces the saved list with the checked rows;
# the next session of the project leaves them out, and the sessions already taken are not
# changed.
#
# LEFT OUT IS NOT PROTECTED: undo cannot restore what a snapshot left out. The window says so above
# the list, and again under it while a checked folder is not build output (ignored by git, or
# large), which may hold work that exists nowhere else.
#
# Sources lib.agentvm.main.sh and lib.agentvm.wizard.sh. POSIX sh (bash 3.2 in POSIX mode) only.
# Validate with "sh -n".
[ -n "${__AGENTVM_APP_EXCLUSIONS_LIB:-}" ] && return 0
__AGENTVM_APP_EXCLUSIONS_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

EXCL_HEAD_ID=5301
EXCL_PATH_ID=5302
EXCL_TABLE_ID=5304
EXCL_STATE_ID=5305
EXCL_WARN_ID=5306
EXCL_NOTES_ID=5307
EXCL_SAVE_ID=5309
EXCL_ADD_ID=5310
EXCL_PROJECT_ID=5311

# The project an Exclusions window that opens now is for, as "<app pid> <full path>".
AGENTVM_EXCLUSIONS_OF_KEY="agentvm_exclusions_of"

# excl_project <uuid>  ->  the project's full path while that window is an open Exclusions window,
# or nothing.
excl_project() {
    ui_get exclusions "$1"
}

# excl_is <uuid>  ->  0 while that window is an open Exclusions window.
excl_is() {
    [ -n "$(excl_project "$1")" ]
}

# excl_ask <project> <command guid>  ->  the Exclusions window for it in front: the open one when
# it is for the same project, else a new one, after closing one opened for another (its ticks,
# not saved, go with it).
excl_ask() {
    agentvm_valid_project "$1" || return 1
    local _window="$(ui_item_window exclusions window)"
    if [ -n "$_window" ]; then
        if [ "$(excl_project "$_window")" = "$1" ]; then
            "$dialog" "$_window" omc_window omc_select
            return 0
        fi
        # Released first: the new window's init handler may run before the old one's close handler.
        ui_item_release exclusions window "$_window"
        "$dialog" "$_window" omc_window omc_terminate_cancel
    fi
    "$pasteboard" "$AGENTVM_EXCLUSIONS_OF_KEY" set "${OMC_APP_PROCESS_ID:-} $1"
    ui_item_open exclusions window "$2"
}

# excl_take  ->  the project the main window handed over, if this run of the app did, or nothing;
# cleared either way, so it is read once.
excl_take() {
    local _entry="$("$pasteboard" "$AGENTVM_EXCLUSIONS_OF_KEY" get)"
    "$pasteboard" "$AGENTVM_EXCLUSIONS_OF_KEY" set ""
    [ -n "$_entry" ] && [ -n "${OMC_APP_PROCESS_ID:-}" ] || return 0
    [ "${_entry%% *}" = "$OMC_APP_PROCESS_ID" ] || return 0
    agentvm_valid_project "${_entry#* }" || return 0
    printf '%s\n' "${_entry#* }"
}

# excl_file <uuid> <name>  ->  one of the window's cache files: scan.json (agent-vm's answer),
# saved (the saved list, a path per line), rows.tsv (the table as painted), error.
excl_file() {
    ui_cache "$1" "excl-$2"
}

# excl_rows <uuid>  ->  the table's rows from the cached scan, one per candidate in agent-vm's
# order, then one per saved path the scan did not list: tick ("true" or "false"), path, size,
# why, then, not shown, kind (build, ignored, large, or saved for a saved path the scan did not
# list; excl_add adds rows of the kind chosen). Ticked: the saved paths, or what agent-vm
# suggests when nothing is saved.
excl_rows() {
    local _scan="$(excl_file "$1" scan.json)"
    local _saved="$(excl_file "$1" saved)"
    agentvm_scan_excluded < "$_scan" | ui_store "$_saved"
    agentvm_scan_rows < "$_scan" | /usr/bin/awk -F'\t' -v savedfile="$_saved" '
        function size(b) {
            if (b !~ /^[0-9]+$/) return "-"
            if (b >= 999500000) return sprintf("%.1f GB", b / 1000000000)
            if (b < 500000) return "under 1 MB"
            return sprintf("%d MB", (b + 500000) / 1000000)
        }
        function why(kind, reasons,    n, parts, i, out) {
            if (kind == "ignored") return "ignored by git; may hold work that exists nowhere else"
            if (kind == "large") return "large; may hold work that exists nowhere else"
            n = split(reasons, parts, "; ")
            out = ""
            for (i = 1; i <= n; i++) {
                if (parts[i] == "named as build output" || parts[i] == "-") continue
                out = out (out == "" ? "" : ", ") parts[i]
            }
            return out == "" ? "build output" : "build output (" out ")"
        }
        BEGIN {
            while ((getline line < savedfile) > 0) if (line != "") { want[line] = 1; order[++count] = line }
        }
        NF {
            tick = count > 0 ? (($1 in want) ? "true" : "false") : ($5 == "true" ? "true" : "false")
            seen[$1] = 1
            printf "%s\t%s\t%s\t%s\t%s\n", tick, $1, size($2), why($4, $8), $4
        }
        END {
            for (i = 1; i <= count; i++) if (!(order[i] in seen)) printf "true\t%s\t-\tsaved\tsaved\n", order[i]
        }' | excl_saved_rows "$(excl_project "$1")"
}

# excl_saved_rows <project>  <  rows  ->  the rows, with a saved path the scan did not list said to
# be saved when it is a folder of the project (one added with Add Folder...), or not found in the
# project now.
excl_saved_rows() {
    local _tick _path _size _why _kind
    while IFS="$ui_tab" read -r _tick _path _size _why _kind; do
        if [ "$_kind" = "saved" ] && [ ! -d "$1/$_path" ]; then
            _why="saved; not found in the project now"
        fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$_tick" "$_path" "$_size" "$_why" "$_kind"
    done
}

# excl_ticked <uuid>  ->  the paths ticked in the table as painted, one per line.
excl_ticked() {
    /usr/bin/awk -F'\t' '$1 == "true" { print $2 }' "$(excl_file "$1" rows.tsv)" 2>/dev/null
}

# excl_state_text <uuid>  ->  the line under the table: how many folders are ticked and their size.
excl_state_text() {
    /usr/bin/awk -F'\t' '
        $1 == "true" { n++ }
        END {
            if (n == 0) { print "Nothing checked: the snapshots take the whole project."; exit }
            printf "%d %s checked: the next session leaves %s out of its snapshot.\n", n, (n == 1 ? "folder" : "folders"), (n == 1 ? "it" : "them")
        }' "$(excl_file "$1" rows.tsv)" 2>/dev/null
}

# excl_warn_text <uuid>  ->  the warning under it while a ticked folder is not build output, or
# nothing.
excl_warn_text() {
    local _names="$(/usr/bin/awk -F'\t' '$1 == "true" && ($5 == "ignored" || $5 == "large") { print $2 }' "$(excl_file "$1" rows.tsv)" 2>/dev/null)"
    [ -n "$_names" ] || return 0
    printf '%s may hold work that exists nowhere else, and undo will not restore it.\n' "$(ui_lines_text "$_names")"
}

# excl_paint <uuid>  ->  the window from its caches: the table, the lines under it, agent-vm's
# notes, and Save, on once the scan answered.
excl_paint() {
    local _uuid="$1"
    local _project="$(excl_project "$_uuid")"
    "$dialog" "$_uuid" "$EXCL_HEAD_ID" "Snapshot exclusions for $(/usr/bin/basename "$_project")"
    "$dialog" "$_uuid" "$EXCL_PATH_ID" "$(agentvm_display_path "$_project")"
    "$dialog" "$_uuid" "$EXCL_PROJECT_ID" "$_project"
    local _rows="$(excl_file "$_uuid" rows.tsv)"
    if [ -f "$_rows" ]; then
        "$dialog" "$_uuid" "$EXCL_TABLE_ID" omc_table_set_rows_from_stdin < "$_rows"
    else
        : | "$dialog" "$_uuid" "$EXCL_TABLE_ID" omc_table_set_rows_from_stdin
    fi
    local _error="$(/bin/cat "$(excl_file "$_uuid" error)" 2>/dev/null)"
    if [ -n "$_error" ]; then
        "$dialog" "$_uuid" "$EXCL_STATE_ID" "$_error"
        "$dialog" "$_uuid" "$EXCL_WARN_ID" ""
        "$dialog" "$_uuid" "$EXCL_NOTES_ID" ""
        ui_enable "$_uuid" "$EXCL_SAVE_ID" 0
        ui_enable "$_uuid" "$EXCL_ADD_ID" 0
        return 0
    fi
    if [ ! -f "$_rows" ]; then
        "$dialog" "$_uuid" "$EXCL_STATE_ID" "Looking through the project..."
        "$dialog" "$_uuid" "$EXCL_WARN_ID" ""
        "$dialog" "$_uuid" "$EXCL_NOTES_ID" ""
        ui_enable "$_uuid" "$EXCL_SAVE_ID" 0
        ui_enable "$_uuid" "$EXCL_ADD_ID" 0
        return 0
    fi
    "$dialog" "$_uuid" "$EXCL_STATE_ID" "$(excl_state_text "$_uuid")"
    "$dialog" "$_uuid" "$EXCL_WARN_ID" "$(excl_warn_text "$_uuid")"
    "$dialog" "$_uuid" "$EXCL_NOTES_ID" "$(agentvm_scan_notes < "$(excl_file "$_uuid" scan.json)")"
    ui_enable "$_uuid" "$EXCL_SAVE_ID" 1
    ui_enable "$_uuid" "$EXCL_ADD_ID" 1
}

# excl_scan <uuid>  ->  the window says it is looking, `session scan` runs (seconds for a large
# project), and the window is painted from its answer, ticked as saved or as suggested. A failed
# scan leaves an empty table, agent-vm's reason, and Save off.
excl_scan() {
    local _uuid="$1"
    local _project="$(excl_project "$_uuid")"
    /bin/rm -f "$(excl_file "$_uuid" rows.tsv)" "$(excl_file "$_uuid" error)"
    excl_paint "$_uuid"
    local _json _status
    _json="$(agentvm_session_scan "$_project")"
    _status=$?
    # The window closed while agent-vm looked: nothing is painted, and the cache folder painting
    # made again goes.
    if ! excl_is "$_uuid"; then
        ui_cache_clear "$_uuid"
        return 0
    fi
    if [ "$_status" -ne 0 ]; then
        ui_one_line "Could not look through the project: $(agentvm_last_error "$_status")" | ui_store "$(excl_file "$_uuid" error)"
        excl_paint "$_uuid"
        return "$_status"
    fi
    printf '%s\n' "$_json" | ui_store "$(excl_file "$_uuid" scan.json)"
    excl_rows "$_uuid" | ui_store "$(excl_file "$_uuid" rows.tsv)"
    excl_paint "$_uuid"
    return 0
}

# excl_tick <uuid> <row index>  ->  that row's tick flipped, in the rows as painted.
excl_tick() {
    local _uuid="$1"
    case "$2" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    local _rows="$(excl_file "$_uuid" rows.tsv)"
    [ -f "$_rows" ] || return 0
    /usr/bin/awk -F'\t' -v OFS='\t' -v n="$(( $2 + 1 ))" 'NR == n { $1 = ($1 == "true") ? "false" : "true" } { print }' "$_rows" | ui_store "$_rows"
    excl_paint "$_uuid"
}

# excl_relative <project> <folder>  ->  the folder's path in the project ("Build/Products"), or
# nothing when it is not inside the project (the project itself included). The panel may name the
# folder by another path to the same place (/tmp for /private/tmp): then both are resolved.
excl_relative() {
    local _project="$1"
    local _folder="$2"
    case "$_folder" in
        "$_project"/*) printf '%s\n' "${_folder#"$_project"/}"; return 0 ;;
    esac
    local _real_project _real_folder
    _real_project="$(CDPATH= cd -P -- "$_project" 2>/dev/null && pwd)"
    _real_folder="$(CDPATH= cd -P -- "$_folder" 2>/dev/null && pwd)"
    [ -n "$_real_project" ] && [ -n "$_real_folder" ] || return 0
    case "$_real_folder" in
        "$_real_project"/*) printf '%s\n' "${_real_folder#"$_real_project"/}" ;;
    esac
}

# excl_add <uuid> <folder>  ->  Add Folder...: a folder of the project, chosen in the folder panel,
# becomes a checked row (or its row is checked when the table has it). A folder outside the
# project, or the project itself, is refused with an alert. Nothing before the scan answered.
excl_add() {
    local _uuid="$1"
    local _project="$(excl_project "$_uuid")"
    [ -n "$_project" ] || return 0
    local _rows="$(excl_file "$_uuid" rows.tsv)"
    [ -f "$_rows" ] || return 0
    local _folder="$2"
    [ -n "$_folder" ] || return 0
    # The panel may hand the folder over with a trailing "/".
    case "$_folder" in
        /) ;;
        */) _folder="${_folder%/}" ;;
    esac
    local _relative=""
    agentvm_valid_project "$_folder" && _relative="$(excl_relative "$_project" "$_folder")"
    if [ -z "$_relative" ]; then
        "$dialog" "$_uuid" omc_window omc_present_alert "Choose a folder inside the project" \
            "$(agentvm_display_path "$_folder") is not a folder inside $(agentvm_display_path "$_project").
Only a project's own folders can be excluded from its snapshots." "OK::"
        return 0
    fi
    # The path through the environment: awk -v would read a backslash in it as an escape. It is
    # made a string first, so "01" and "1" are not compared as numbers.
    EXCL_PATH="$_relative" /usr/bin/awk -F'\t' -v OFS='\t' '
        BEGIN { path = ENVIRON["EXCL_PATH"] "" }
        $2 == path { $1 = "true"; found = 1 }
        { print }
        END { if (!found) print "true", path, "-", "chosen by you", "chosen" }' "$_rows" | ui_store "$_rows"
    excl_paint "$_uuid"
}

# excl_saved <project>  ->  the main window, when one is open, reads every project's list again
# and shows it on the project's Exclusions row.
excl_saved() {
    local _main="$(ui_item_window main window)"
    [ -n "$_main" ] || return 0
    ses_read_exclusions "$_main"
    ses_paint "$_main" force
}
