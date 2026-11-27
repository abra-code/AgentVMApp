#!/bin/sh
# lib.agentvm.changes.sh
#
# The Session Changes window (AgentVM.changes.json, the views 5501-5527): what one session
# changed in its project, the selected change compared with the project as it was when the session
# started, and an undo of the ticked entries. One window per session (lib.agentvm.ui.sh, "Box
# windows", with the kind "changes" and the session's id as the name), opened by Changes... under
# the session table of the Sessions tab, or by a double-click on a row.
#
# THE SESSION is the window's value "changes": its id, handed over by the main window in the open
# request and read once by the init handler. It is also what says that the window is an open
# Session Changes window.
#
# WHAT IT SHOWS. On opening, and on Compare Again, `session list` says the session's state and
# `session report` compares the project with the session's snapshot (seconds for a large
# project; the window says so while it runs). A row per change, in agent-vm's order (by path), with
# a tick, what changed, the path, the size and the highest flag. Selecting a row shows it on the
# right:
#   - a file whose two sides are text: the two compared line by line (the Diff element), the side
#     that is missing (an added or a deleted file) taken as empty;
#   - a file that is not text, or too large to compare (DIFF_MAX_BYTES): Quick Look previews of the
#     two sides;
#   - a symlink: where it points, in words; never followed;
#   - a folder, or a change of permissions or of type: what changed, in words.
# A file is read only when it is a plain file whose folder, followed to its real place, is in the
# project (or in the snapshot): a symlink the agent put in its place, or in the place of a folder
# above it, is never read through.
#
# UNDO puts back the ticked entries as they were when the session started (`session undo
# --path`), and what is under them: an entry inside a folder that was added or deleted as a whole
# goes with that folder, so its tick follows the folder's. What the agent left there is moved into
# the session's folder, never deleted (Show Kept Versions). The question before it names the
# programs started for the session that have not ended and whose client still runs on this Mac:
# an agent that still works may change the files again. Only an active or ended session with its
# snapshot is undone from here: an undone session is shown only (what differs from its snapshot
# now changed after the undo), and a discarded one shows the report saved when it ended.
#
# Sources lib.agentvm.main.sh (and through it lib.agentvm.sessions.sh, for the main window's
# Sessions tab after an undo) and lib.agentvm.wizard.sh. POSIX sh (bash 3.2 in POSIX mode) only.
# Validate with "sh -n".
[ -n "${__AGENTVM_APP_CHANGES_LIB:-}" ] && return 0
__AGENTVM_APP_CHANGES_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

CHG_HEAD_ID=5501
CHG_PATH_ID=5502
CHG_SUMMARY_ID=5503
CHG_TABLE_ID=5504
CHG_TITLE_ID=5506
CHG_WHAT_ID=5507
CHG_DIFF_SCROLL_ID=5509
CHG_DIFF_ID=5510
CHG_PREVIEWS_ID=5511
CHG_OLD_PREVIEW_ID=5512
CHG_NEW_PREVIEW_ID=5513
CHG_OLD_SIDE_ID=5514
CHG_NEW_SIDE_ID=5516
CHG_LEFT_OUT_ID=5520
CHG_NOTE_ID=5521
CHG_SHOW_ID=5522
CHG_KEPT_ID=5523
CHG_REFRESH_ID=5524
CHG_TICKED_ID=5525
CHG_UNDO_ID=5527

# The largest file compared line by line; the Diff element reads at most 4 MB.
DIFF_MAX_BYTES=4000000
# How many paths the question before an undo names.
CHG_QUESTION_PATHS=5

# chg_session <uuid>  ->  the session's id while that window is an open Session Changes window, or
# nothing.
chg_session() {
    ui_get changes "$1"
}

# chg_is <uuid>  ->  0 while that window is an open Session Changes window.
chg_is() {
    [ -n "$(chg_session "$1")" ]
}

# chg_file <uuid> <name>  ->  one of the window's cache files: report.json (agent-vm's answer),
# head.tsv (agentvm_report_head), rows.tsv (a tick, then the change rows of
# agentvm_report_change_rows), state (the session's state, as `session list` says it, or
# "discarded" for one it no longer lists), error, pending (the paths an undo asked about), empty
# (an empty file: the missing side of an added or a deleted file).
chg_file() {
    ui_cache "$1" "chg-$2"
}

# chg_head_field <uuid> <field>  ->  one field of the report's head.
chg_head_field() {
    /usr/bin/cut -f"$2" "$(chg_file "$1" head.tsv)" 2>/dev/null
}

# chg_project <uuid>  and  chg_snapshot <uuid>  ->  the project's folder and the snapshot's, from
# the report ("-" or nothing when it names none).
chg_project() {
    chg_head_field "$1" 1
}
chg_snapshot() {
    chg_head_field "$1" 2
}

# chg_editable <uuid>  ->  0 when the window may undo: the session is active or ended, its report
# is a comparison with the snapshot (not the one saved when it ended), and the snapshot is there.
chg_editable() {
    # A comparison that failed leaves the rows of the one before, which may no longer hold.
    [ -s "$(chg_file "$1" error)" ] && return 1
    local _state="$(/bin/cat "$(chg_file "$1" state)" 2>/dev/null)"
    case "$_state" in
        active|ended) ;;
        *) return 1 ;;
    esac
    [ "$(chg_head_field "$1" 3)" = "false" ] || return 1
    local _snapshot="$(chg_snapshot "$1")"
    [ -n "$_snapshot" ] && [ "$_snapshot" != "-" ] && [ -d "$_snapshot" ]
}

# chg_bytes_text <bytes>  ->  "12 bytes", "3.4 KB", "12 MB", "1.2 GB", or nothing for no number.
chg_bytes_text() {
    case "$1" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    if [ "$1" -lt 1000 ]; then
        main_count_text "$1" byte
    elif [ "$1" -lt 999500 ]; then
        /usr/bin/awk -v b="$1" 'BEGIN { printf "%.1f KB\n", b / 1000 }'
    else
        ui_size_text "$1"
    fi
}

# chg_time_text <seconds since the epoch>  ->  "Nov 25 15:33", or nothing.
chg_time_text() {
    case "$1" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    /bin/date -r "$1" '+%b %e %H:%M' | /usr/bin/sed 's/  / /'
}

# chg_read <uuid>  ->  the session's state from `session list` and its report from `session
# report`, into the window's cache; the ticks of entries the new report still lists are kept.
# agent-vm's status; its message in the error file (empty after a success).
chg_read() {
    local _uuid="$1"
    local _id="$(chg_session "$_uuid")"
    agentvm_valid_session_id "$_id" || return 2
    local _list _status
    _list="$(agentvm_session_list)"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        ui_one_line "Could not read the sessions: $(agentvm_last_error "$_status")" | ui_store "$(chg_file "$_uuid" error)"
        return "$_status"
    fi
    local _record="$(printf '%s\n' "$_list" | agentvm_session_rows | CHG_ID="$_id" /usr/bin/awk -F'\t' '$1 == ENVIRON["CHG_ID"]')"
    printf '%s\n' "$_record" | ui_store "$(chg_file "$_uuid" record.tsv)"
    if [ -n "$_record" ]; then
        printf '%s\n' "$_record" | /usr/bin/cut -f3 | ui_store "$(chg_file "$_uuid" state)"
    else
        printf 'discarded\n' | ui_store "$(chg_file "$_uuid" state)"
    fi
    local _json
    _json="$(agentvm_session_report "$_id")"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        ui_one_line "Could not compare the project with the session's snapshot: $(agentvm_last_error "$_status")" | ui_store "$(chg_file "$_uuid" error)"
        return "$_status"
    fi
    printf '%s\n' "$_json" | ui_store "$(chg_file "$_uuid" report.json)"
    printf '%s\n' "$_json" | agentvm_report_head | ui_store "$(chg_file "$_uuid" head.tsv)"
    local _rows="$(chg_file "$_uuid" rows.tsv)"
    local _ticked="$(chg_ticked "$_uuid")"
    printf '%s\n' "$_json" | agentvm_report_change_rows | CHG_TICKED="$_ticked" /usr/bin/awk -F'\t' -v OFS='\t' '
        BEGIN { n = split(ENVIRON["CHG_TICKED"], t, "\n"); for (i = 1; i <= n; i++) if (t[i] != "") was[t[i]] = 1 }
        NF { print (($1 in was) ? "true" : "false"), $0 }' | ui_store "$_rows"
    : | ui_store "$(chg_file "$_uuid" error)"
    return 0
}

# chg_ticks <uuid>  ->  the rows as they show their ticks (lib.agentvm.changes.awk): an entry under a
# ticked folder follows it. Each row gets two fields more: whether it follows a ticked folder, and
# whether the undo names it.
chg_ticks() {
    [ -f "$(chg_file "$1" rows.tsv)" ] || return 0
    /usr/bin/awk -f "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.changes.awk" "$(chg_file "$1" rows.tsv)"
}

# chg_ticked <uuid>  ->  the paths an undo names, one per line: the entries ticked that may be named
# (not inside another entry that covers them, with a plain path) and are not under a ticked folder,
# which puts them back with it.
chg_ticked() {
    chg_ticks "$1" | /usr/bin/awk -F'\t' '$14 == "true" { print $2 }'
}

# chg_kind_text <kind> <type>  ->  the Change column: "added", "deleted", "modified", "permissions",
# "type changed", with "folder" or "link" for what is not a file.
chg_kind_text() {
    local _kind="$1"
    case "$1" in
        metadata) _kind="permissions" ;;
        typeChanged) _kind="type changed" ;;
    esac
    case "$2" in
        directory) printf '%s folder\n' "$_kind" ;;
        symlink) printf '%s link\n' "$_kind" ;;
        *) printf '%s\n' "$_kind" ;;
    esac
}

# chg_size_text <kind> <type> <size> <size before> <entries inside>  ->  the Size column.
chg_size_text() {
    case "$2" in
        directory)
            [ "$1" = "deleted" ] && [ "$5" != "-" ] && { main_count_text "$5" item; return 0; }
            printf '\n'
            return 0 ;;
    esac
    case "$1" in
        added) chg_bytes_text "$3" ;;
        deleted) chg_bytes_text "$4" ;;
        *)
            if [ "$3" = "$4" ]; then
                chg_bytes_text "$3"
            else
                printf '%s -> %s\n' "$(chg_bytes_text "$4")" "$(chg_bytes_text "$3")"
            fi ;;
    esac
}

# chg_table_rows <uuid>  ->  the table's rows: the tick, what changed, the path, the size, the
# flag, then hidden the row's number in rows.tsv and whether its tick is disabled. An entry under a
# ticked folder shows its tick, disabled (chg_ticks); an entry inside a folder added or deleted as
# a whole has its tick disabled, as has an entry with a path that is not plain, and every entry of
# a window that may not undo.
chg_table_rows() {
    local _uuid="$1"
    local _editable=true
    chg_editable "$_uuid" || _editable=false
    local _n=0
    local _tick _path _kind _type _size _before _flag _reasons _covered _target _inside _plain _follows _names
    chg_ticks "$_uuid" |
    while IFS="$ui_tab" read -r _tick _path _kind _type _size _before _flag _reasons _covered _target _inside _plain _follows _names; do
        _n=$((_n + 1))
        local _disabled=false
        if [ "$_editable" = "false" ] || [ "$_covered" = "true" ] || [ "$_plain" != "true" ] || [ "$_follows" = "true" ]; then
            _disabled=true
        fi
        [ "$_flag" = "-" ] && _flag=""
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$_tick" "$(chg_kind_text "$_kind" "$_type")" "$_path" \
            "$(chg_size_text "$_kind" "$_type" "$_size" "$_before" "$_inside")" "$_flag" "$_n" "$_disabled"
    done
}

# chg_state_text <uuid>  ->  the line under the title: the project's folder, when the session
# started, and its state.
chg_state_text() {
    local _record="$(/bin/cat "$(chg_file "$1" record.tsv)" 2>/dev/null)"
    local _state="$(/bin/cat "$(chg_file "$1" state)" 2>/dev/null)"
    local _project="$(chg_project "$1")"
    local _text="$(agentvm_display_path "$_project")"
    if [ -n "$_record" ]; then
        local _started="$(chg_time_text "$(printf '%s\n' "$_record" | /usr/bin/cut -f4)")"
        local _ended="$(chg_time_text "$(ui_seconds_since_epoch "$(printf '%s\n' "$_record" | /usr/bin/cut -f5)")")"
        local _undone="$(chg_time_text "$(ui_seconds_since_epoch "$(printf '%s\n' "$_record" | /usr/bin/cut -f6)")")"
        _text="$_text - session started $_started"
        case "$_state" in
            active) _text="$_text, active" ;;
            ended) _text="$_text, ended $_ended" ;;
            undone) _text="$_text, undone $_undone" ;;
        esac
    else
        _text="$_text - session discarded"
    fi
    printf '%s\n' "$_text"
}

# chg_summary_text <uuid>  ->  how many entries changed, of which kinds, and how many are flagged.
chg_summary_text() {
    /usr/bin/awk -F'\t' '
        function part(n, one, many) { return n == 1 ? "1 " one : n " " many }
        {
            total = $5 + $6 + $7 + $8 + $9
            if (total == 0) { print "No changes."; exit }
            out = ""
            if ($5 > 0) out = out ", " $5 " added"
            if ($6 > 0) out = out ", " $6 " deleted"
            if ($7 > 0) out = out ", " $7 " modified"
            if ($8 > 0) out = out ", " part($8, "changed type", "changed type")
            if ($9 > 0) out = out ", " part($9, "permission change", "permission changes")
            text = part(total, "change", "changes") ": " substr(out, 3) "."
            if ($10 > 0 || $11 > 0) {
                flagged = ""
                if ($10 > 0) flagged = $10 " high"
                if ($11 > 0) flagged = flagged (flagged == "" ? "" : ", ") $11 " medium"
                text = text " Flagged: " flagged "."
            }
            print text
        }' "$(chg_file "$1" head.tsv)" 2>/dev/null
}

# chg_left_out_text <uuid>  ->  what changed in what the snapshot left out, which undo cannot
# restore, with up to three of the flagged entries; nothing when nothing in it changed.
chg_left_out_text() {
    local _changed="$(chg_head_field "$1" 12)"
    case "$_changed" in
        ''|-|0|*[!0123456789]*) return 0 ;;
    esac
    local _names="$(agentvm_report_left_out_rows < "$(chg_file "$1" report.json)" | /usr/bin/awk -F'\t' 'NR <= 3 { print $1 " (" $2 ")" }')"
    local _text="Can't be undone: $(main_count_text "$_changed" change) in $(chg_head_field "$1" 15), left out of the snapshot"
    if [ -n "$_names" ]; then
        _text="$_text. Flagged: $(ui_lines_text "$_names")"
    fi
    printf '%s.\n' "$_text"
}

# chg_note_text <uuid>  ->  the note under the list, for a window that only shows: why; and for a
# snapshot of the git folders only, that the working files are not compared. Nothing otherwise:
# the question before an undo says what it does.
chg_note_text() {
    local _state="$(/bin/cat "$(chg_file "$1" state)" 2>/dev/null)"
    if [ "$(chg_head_field "$1" 3)" = "true" ]; then
        printf 'Snapshot discarded. Showing the report saved when the session ended.\n'
        return 0
    fi
    local _scope=""
    [ "$(chg_head_field "$1" 4)" = "git" ] && _scope="Only the git folders were snapshotted."
    case "$_state" in
        undone)
            printf 'Session undone. These changes were made after the undo.%s\n' "${_scope:+ $_scope}" ;;
        active|ended)
            [ -n "$_scope" ] && printf '%s\n' "$_scope" ;;
        *)
            printf 'Session discarded. Nothing to compare.\n' ;;
    esac
    return 0
}

# chg_kept_folder <uuid>  ->  the session's folder when an undo kept the agent's versions in it
# (a replaced-<time> folder), or nothing.
chg_kept_folder() {
    local _snapshot="$(chg_snapshot "$1")"
    [ -n "$_snapshot" ] && [ "$_snapshot" != "-" ] || return 0
    local _folder="${_snapshot%/*}"
    [ -d "$_folder" ] || return 0
    local _kept="$(/bin/ls "$_folder" 2>/dev/null | /usr/bin/grep '^replaced-' | /usr/bin/head -n 1)"
    [ -n "$_kept" ] && printf '%s\n' "$_folder"
}

# chg_paint <uuid>  ->  the window from its caches: the head, the table, the lines under it, the
# buttons, and the selected change on the right.
chg_paint() {
    local _uuid="$1"
    local _error="$(/bin/cat "$(chg_file "$_uuid" error)" 2>/dev/null)"
    local _head="$(chg_file "$_uuid" head.tsv)"
    if [ -n "$_error" ] || [ ! -f "$_head" ]; then
        "$dialog" "$_uuid" "$CHG_HEAD_ID" "Changes of session $(chg_session "$_uuid")"
        if [ -n "$_error" ]; then
            "$dialog" "$_uuid" "$CHG_SUMMARY_ID" "$_error"
        else
            "$dialog" "$_uuid" "$CHG_SUMMARY_ID" "Comparing..."
        fi
        : | "$dialog" "$_uuid" "$CHG_TABLE_ID" omc_table_set_rows_from_stdin
        "$dialog" "$_uuid" "$CHG_LEFT_OUT_ID" ""
        "$dialog" "$_uuid" "$CHG_NOTE_ID" ""
        "$dialog" "$_uuid" "$CHG_TICKED_ID" ""
        ui_enable "$_uuid" "$CHG_UNDO_ID" 0
        ui_enable "$_uuid" "$CHG_REFRESH_ID" "$([ -n "$_error" ] && printf 1 || printf 0)"
        chg_select "$_uuid" ""
        return 0
    fi
    local _project="$(chg_project "$_uuid")"
    "$dialog" "$_uuid" "$CHG_HEAD_ID" "Changes in $(/usr/bin/basename "$_project")"
    "$dialog" "$_uuid" "$CHG_PATH_ID" "$(chg_state_text "$_uuid")"
    "$dialog" "$_uuid" "$CHG_SUMMARY_ID" "$(chg_summary_text "$_uuid")"
    chg_table_rows "$_uuid" | "$dialog" "$_uuid" "$CHG_TABLE_ID" omc_table_set_rows_from_stdin
    "$dialog" "$_uuid" "$CHG_LEFT_OUT_ID" "$(chg_left_out_text "$_uuid")"
    "$dialog" "$_uuid" "$CHG_NOTE_ID" "$(chg_note_text "$_uuid")"
    chg_paint_buttons "$_uuid"
    # The change selected before is shown again by its path: after a comparison or an undo, its
    # row may have another number, or be gone.
    local _selected="$(ui_get changes-selected-path "$_uuid")"
    local _n=""
    if [ -n "$_selected" ]; then
        _n="$(CHG_PATH="$_selected" /usr/bin/awk -F'\t' '$2 == ENVIRON["CHG_PATH"] { print NR; exit }' "$(chg_file "$_uuid" rows.tsv)" 2>/dev/null)"
    fi
    chg_select "$_uuid" "$_n"
}

# chg_paint_buttons <uuid>  ->  the count of ticked entries, Undo Ticked... on while one is ticked
# in a window that may undo, Compare Again on for a report compared with the snapshot, and Show
# Kept Versions on once an undo kept the agent's versions.
chg_paint_buttons() {
    local _uuid="$1"
    local _count="$(chg_ticked "$_uuid" | /usr/bin/awk 'END { print NR }')"
    if chg_editable "$_uuid" && [ "$_count" -gt 0 ]; then
        "$dialog" "$_uuid" "$CHG_TICKED_ID" "$_count checked"
        ui_enable "$_uuid" "$CHG_UNDO_ID" 1
    else
        "$dialog" "$_uuid" "$CHG_TICKED_ID" ""
        ui_enable "$_uuid" "$CHG_UNDO_ID" 0
    fi
    if [ "$(chg_head_field "$_uuid" 3)" = "false" ]; then
        ui_enable "$_uuid" "$CHG_REFRESH_ID" 1
    else
        ui_enable "$_uuid" "$CHG_REFRESH_ID" 0
    fi
    if [ -n "$(chg_kept_folder "$_uuid")" ]; then
        ui_enable "$_uuid" "$CHG_KEPT_ID" 1
    else
        ui_enable "$_uuid" "$CHG_KEPT_ID" 0
    fi
}

# chg_tick <uuid> <row index>  ->  that row's tick flipped, in the rows as painted (an entry whose
# tick is disabled keeps it).
chg_tick() {
    local _uuid="$1"
    case "$2" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    local _rows="$(chg_file "$_uuid" rows.tsv)"
    [ -f "$_rows" ] || return 0
    chg_editable "$_uuid" || return 0
    local _n=$(( $2 + 1 ))
    # An entry under a ticked folder follows the folder: its own tick cannot change.
    local _follows="$(chg_ticks "$_uuid" | /usr/bin/awk -F'\t' -v n="$_n" 'NR == n { print $13 }')"
    [ "$_follows" = "false" ] || return 0
    /usr/bin/awk -F'\t' -v OFS='\t' -v n="$_n" 'NR == n && $9 == "false" && $12 == "true" { $1 = ($1 == "true") ? "false" : "true" } { print }' "$_rows" | ui_store "$_rows"
    chg_paint "$_uuid"
}

# chg_inside <root> <path>  ->  the full path of that entry when it is a plain file (not a symlink)
# whose folder, followed to its real place, is the very folder the path names under the root;
# nothing otherwise. What the agent made a symlink, in place of the file or of any folder above it
# (pointing out of the root or elsewhere in it), is never read through.
chg_inside() {
    local _full="$1/$2"
    [ -f "$_full" ] && [ ! -L "$_full" ] || return 0
    local _real_root _real_parent
    _real_root="$(CDPATH= cd -P -- "$1" 2>/dev/null && pwd)"
    _real_parent="$(CDPATH= cd -P -- "${_full%/*}" 2>/dev/null && pwd)"
    [ -n "$_real_root" ] && [ -n "$_real_parent" ] || return 0
    local _expected="$_real_root"
    case "$2" in
        */*) _expected="$_real_root/${2%/*}" ;;
    esac
    [ "$_real_parent" = "$_expected" ] && printf '%s\n' "$_full"
    return 0
}

# chg_is_text <file>  ->  0 when the file can be compared line by line: at most DIFF_MAX_BYTES and
# not binary, as file(1) reads its encoding.
chg_is_text() {
    local _bytes="$(/usr/bin/stat -f %z "$1" 2>/dev/null)"
    case "$_bytes" in
        ''|*[!0123456789]*) return 1 ;;
    esac
    [ "$_bytes" -le "$DIFF_MAX_BYTES" ] || return 1
    [ "$_bytes" -eq 0 ] && return 0
    local _encoding="$(/usr/bin/file -b --mime-encoding "$1" 2>/dev/null)"
    case "$_encoding" in
        ''|binary|*error*) return 1 ;;
    esac
    return 0
}

# chg_view <uuid> <diff|previews|none>  ->  which of the compare views shows; the others are
# emptied, so nothing of an earlier selection stays.
chg_view() {
    local _uuid="$1"
    if [ "$2" != "diff" ]; then
        ui_show "$_uuid" "$CHG_DIFF_SCROLL_ID" 0
        "$dialog" "$_uuid" "$CHG_DIFF_ID" omc_set_property oldFile "$(chg_empty "$_uuid")"
        "$dialog" "$_uuid" "$CHG_DIFF_ID" omc_set_property newFile "$(chg_empty "$_uuid")"
    fi
    if [ "$2" != "previews" ]; then
        ui_show "$_uuid" "$CHG_PREVIEWS_ID" 0
        "$dialog" "$_uuid" "$CHG_OLD_PREVIEW_ID" ""
        "$dialog" "$_uuid" "$CHG_NEW_PREVIEW_ID" ""
    fi
    case "$2" in
        diff) ui_show "$_uuid" "$CHG_DIFF_SCROLL_ID" 1 ;;
        previews) ui_show "$_uuid" "$CHG_PREVIEWS_ID" 1 ;;
    esac
}

# chg_empty <uuid>  ->  the path of an empty file in the window's cache: the side of a diff that
# has no file.
chg_empty() {
    local _file="$(chg_file "$1" empty)"
    [ -f "$_file" ] || : > "$_file"
    printf '%s\n' "$_file"
}

# chg_select <uuid> <row number in rows.tsv, or nothing>  ->  that change on the right, and Show in
# Finder on for it; nothing shown for no row.
chg_select() {
    local _uuid="$1"
    local _row=""
    case "$2" in
        ''|*[!0123456789]*) ;;
        *) _row="$(/usr/bin/awk -v n="$2" 'NR == n' "$(chg_file "$_uuid" rows.tsv)" 2>/dev/null)" ;;
    esac
    if [ -z "$_row" ]; then
        ui_set changes-selected "$_uuid" ""
        ui_set changes-selected-path "$_uuid" ""
        "$dialog" "$_uuid" "$CHG_TITLE_ID" ""
        "$dialog" "$_uuid" "$CHG_WHAT_ID" "$([ -f "$(chg_file "$_uuid" head.tsv)" ] && printf 'No selection')"
        chg_view "$_uuid" none
        ui_enable "$_uuid" "$CHG_SHOW_ID" 0
        return 0
    fi
    ui_set changes-selected "$_uuid" "$2"
    local _tick _path _kind _type _size _before _flag _reasons _covered _target _inside _plain
    IFS="$ui_tab" read -r _tick _path _kind _type _size _before _flag _reasons _covered _target _inside _plain <<END
$_row
END
    ui_set changes-selected-path "$_uuid" "$_path"
    "$dialog" "$_uuid" "$CHG_TITLE_ID" "$_path"
    local _flags=""
    [ "$_flag" != "-" ] && _flags=" Flagged $_flag: $_reasons."
    if [ "$_plain" != "true" ]; then
        "$dialog" "$_uuid" "$CHG_WHAT_ID" "Not shown: the name has control characters (shown as ?).$_flags"
        chg_view "$_uuid" none
        ui_enable "$_uuid" "$CHG_SHOW_ID" 0
        return 0
    fi
    local _project="$(chg_project "$_uuid")"
    local _snapshot="$(chg_snapshot "$_uuid")"
    local _compare=true
    [ "$(chg_head_field "$_uuid" 3)" = "true" ] && _compare=false
    [ -n "$_snapshot" ] && [ "$_snapshot" != "-" ] && [ -d "$_snapshot" ] || _compare=false
    local _what=""
    local _view=none
    case "$_type" in
        symlink)
            _what="Symbolic link"
            if [ "$_kind" != "deleted" ] && [ "$_target" != "-" ]; then
                _what="$_what to $_target"
            fi
            _what="$_what."
            if [ "$_compare" = "true" ] && [ "$_kind" != "added" ] && [ -L "$_snapshot/$_path" ]; then
                local _old_target="$(/usr/bin/readlink "$_snapshot/$_path" 2>/dev/null)"
                # Shown as the report shows the target now, whatever the locale.
                _old_target="$(printf '%s' "$_old_target" | /usr/bin/jq -Rrs "$agentvm_jq_report_defs"' shown' 2>/dev/null)"
                [ -n "$_old_target" ] && _what="$_what At the start: $_old_target."
            fi
            ;;
        directory)
            local _held=""
            [ "$_inside" != "-" ] && _held="$(printf ', %s' "$(main_count_text "$_inside" item)")"
            case "$_kind" in
                added) _what="Added folder$_held." ;;
                deleted) _what="Deleted folder$_held." ;;
                metadata)
                    if [ "$_path" = "." ]; then
                        _what="Project folder permissions changed."
                    else
                        _what="Folder permissions changed."
                    fi ;;
                typeChanged) _what="Now a folder$_held; was a file or link." ;;
                *) _what="Folder couldn't be read." ;;
            esac ;;
        file)
            local _old=""
            local _new=""
            if [ "$_compare" = "true" ] && [ "$_kind" != "added" ]; then
                _old="$(chg_inside "$_snapshot" "$_path")"
            fi
            [ "$_kind" != "deleted" ] && _new="$(chg_inside "$_project" "$_path")"
            case "$_kind" in
                added) _what="Added, $(chg_bytes_text "$_size")." ;;
                deleted) _what="Deleted, $(chg_bytes_text "$_before")." ;;
                metadata)
                    local _old_mode="$([ -n "$_old" ] && /usr/bin/stat -f %Sp "$_old" 2>/dev/null)"
                    local _new_mode="$([ -n "$_new" ] && /usr/bin/stat -f %Sp "$_new" 2>/dev/null)"
                    _what="Permissions changed$([ -n "$_old_mode" ] && [ -n "$_new_mode" ] && printf ': %s -> %s' "$_old_mode" "$_new_mode")." ;;
                typeChanged) _what="Now a file; was a folder or link." ;;
                *) _what="Modified, $(chg_size_text "$_kind" "$_type" "$_size" "$_before" "-")." ;;
            esac
            if [ "$_compare" = "false" ]; then
                _what="$_what No snapshot to compare with."
            elif [ "$_kind" = "metadata" ] || [ "$_kind" = "typeChanged" ]; then
                # Said in words: the content is the same, or there is no file at the start to
                # compare with.
                :
            elif { [ "$_kind" != "added" ] && [ -z "$_old" ]; } || { [ "$_kind" != "deleted" ] && [ -z "$_new" ]; }; then
                _what="$_what Not shown: no longer a plain file."
            else
                local _text=true
                [ -n "$_old" ] && ! chg_is_text "$_old" && _text=false
                [ -n "$_new" ] && ! chg_is_text "$_new" && _text=false
                if [ "$_text" = "true" ]; then
                    "$dialog" "$_uuid" "$CHG_DIFF_ID" omc_set_property oldFile "${_old:-$(chg_empty "$_uuid")}"
                    "$dialog" "$_uuid" "$CHG_DIFF_ID" omc_set_property newFile "${_new:-$(chg_empty "$_uuid")}"
                    _view=diff
                else
                    "$dialog" "$_uuid" "$CHG_OLD_PREVIEW_ID" "$_old"
                    "$dialog" "$_uuid" "$CHG_NEW_PREVIEW_ID" "$_new"
                    ui_show "$_uuid" "$CHG_OLD_SIDE_ID" "$([ -n "$_old" ] && printf 1 || printf 0)"
                    ui_show "$_uuid" "$CHG_NEW_SIDE_ID" "$([ -n "$_new" ] && printf 1 || printf 0)"
                    _view=previews
                fi
            fi ;;
        *)
            _what="Special file (a pipe or device), not shown." ;;
    esac
    "$dialog" "$_uuid" "$CHG_WHAT_ID" "$_what$_flags"
    chg_view "$_uuid" "$_view"
    if [ -n "$(chg_reveal_path "$_uuid")" ]; then
        ui_enable "$_uuid" "$CHG_SHOW_ID" 1
    else
        ui_enable "$_uuid" "$CHG_SHOW_ID" 0
    fi
}

# chg_reveal_path <uuid>  ->  what Show in Finder selects for the selected change: the project's
# entry, or the snapshot's for one the agent deleted; nothing when neither is there.
chg_reveal_path() {
    local _n="$(ui_get changes-selected "$1")"
    case "$_n" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    local _row="$(/usr/bin/awk -v n="$_n" 'NR == n' "$(chg_file "$1" rows.tsv)" 2>/dev/null)"
    [ -n "$_row" ] || return 0
    local _path="$(printf '%s\n' "$_row" | /usr/bin/cut -f2)"
    [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f12)" = "true" ] || return 0
    local _project="$(chg_project "$1")"
    if [ -e "$_project/$_path" ] || [ -L "$_project/$_path" ]; then
        printf '%s\n' "$_project/$_path"
        return 0
    fi
    local _snapshot="$(chg_snapshot "$1")"
    [ -n "$_snapshot" ] && [ "$_snapshot" != "-" ] || return 0
    if [ -e "$_snapshot/$_path" ] || [ -L "$_snapshot/$_path" ]; then
        printf '%s\n' "$_snapshot/$_path"
    fi
}

# chg_show <uuid>  ->  the selected change in a Finder window.
chg_show() {
    local _path="$(chg_reveal_path "$1")"
    [ -n "$_path" ] || return 0
    "$open_tool" -R "$_path"
}

# chg_kept <uuid>  ->  the session's folder, where undo kept the agent's versions, in Finder.
chg_kept() {
    local _folder="$(chg_kept_folder "$1")"
    [ -n "$_folder" ] || return 0
    "$open_tool" "$_folder"
}

# chg_refresh <uuid>  ->  the window says it compares, reads, and is painted again.
chg_refresh() {
    local _uuid="$1"
    "$dialog" "$_uuid" "$CHG_SUMMARY_ID" "Comparing..."
    ui_enable "$_uuid" "$CHG_REFRESH_ID" 0
    ui_enable "$_uuid" "$CHG_UNDO_ID" 0
    chg_read "$_uuid"
    local _status=$?
    # The window closed while agent-vm compared: nothing is painted, and the cache folder painting
    # made again goes.
    if ! chg_is "$_uuid"; then
        ui_cache_clear "$_uuid"
        return 0
    fi
    chg_paint "$_uuid"
    # Painting reads the cache, which makes its folder again for a window that closed meanwhile.
    chg_is "$_uuid" || ui_cache_clear "$_uuid"
    return "$_status"
}

# chg_running_programs <uuid>  ->  the programs started for the session that have no exit status
# and whose client still runs on this Mac, one per line ("opencode in box x"); nothing when none.
# A pid can be reused, so one may be named that ended long ago: the question only warns.
chg_running_programs() {
    local _report="$(chg_file "$1" report.json)"
    [ -f "$_report" ] || return 0
    local _lines=""
    local _box _pid _command _started
    while IFS="$ui_tab" read -r _box _pid _command _started; do
        case "$_pid" in
            ''|-|0|*[!0123456789]*) continue ;;
        esac
        kill -0 "$_pid" 2>/dev/null || continue
        _lines="$_lines${_lines:+
}$(printf '%s' "$_command" | /usr/bin/cut -c1-60) in box $_box"
    done <<END
$(agentvm_report_open_programs < "$_report")
END
    [ -n "$_lines" ] || return 0
    printf '%s\n' "$_lines"
}

# chg_undo_ask <uuid>  ->  the question before an undo of the ticked entries; Undo goes on with
# AgentVM.changes.undo.confirmed, which reads the paths kept here. With a program of the session
# still running, the question says so and its button reads Undo Anyway.
chg_undo_ask() {
    local _uuid="$1"
    # A session discarded or undone elsewhere since the window compared: it compares again and
    # shows the session as it is now.
    if ! chg_editable "$_uuid"; then
        chg_refresh "$_uuid"
        return 0
    fi
    local _paths="$(chg_ticked "$_uuid")"
    [ -n "$_paths" ] || return 0
    printf '%s\n' "$_paths" | ui_store "$(chg_file "$_uuid" pending)"
    local _count="$(printf '%s\n' "$_paths" | /usr/bin/awk 'END { print NR }')"
    local _named="$(printf '%s\n' "$_paths" | /usr/bin/head -n "$CHG_QUESTION_PATHS")"
    local _more=""
    [ "$_count" -gt "$CHG_QUESTION_PATHS" ] && _more=" and $(( _count - CHG_QUESTION_PATHS )) more"
    local _project="$(chg_project "$_uuid")"
    local _what="$(main_count_text "$_count" item)"
    local _were="they were"
    [ "$_count" -eq 1 ] && _were="it was"
    local _message="$(ui_lines_text "$_named")$_more will be restored to how $_were when the session started. The agent's versions are moved to the session's folder."
    local _programs="$(chg_running_programs "$_uuid")"
    if [ -n "$_programs" ]; then
        local _running="is still running. Stop it first if you can."
        local _program_count="$(printf '%s\n' "$_programs" | /usr/bin/awk 'END { print NR }')"
        [ "$_program_count" != "1" ] && _running="are still running. Stop them first if you can."
        "$dialog" "$_uuid" omc_window omc_present_alert "An agent may still be working in $(/usr/bin/basename "$_project")" \
            "$(ui_lines_text "$_programs") $_running $_message" \
            "Cancel:cancel:" "Undo Anyway:destructive:AgentVM.changes.undo.confirmed"
        return 0
    fi
    "$dialog" "$_uuid" omc_window omc_present_alert "Undo $_what in $(/usr/bin/basename "$_project")?" "$_message" \
        "Cancel:cancel:" "Undo:destructive:AgentVM.changes.undo.confirmed"
}

# chg_undo <uuid>  ->  the entries the question was about put back: what could not be is said
# with agent-vm's reason, the window compares again, and the main window's Sessions tab reads the
# sessions again (the session may now be undone).
chg_undo() {
    local _uuid="$1"
    local _pending="$(chg_file "$_uuid" pending)"
    local _paths="$(/bin/cat "$_pending" 2>/dev/null)"
    /bin/rm -f "$_pending"
    [ -n "$_paths" ] || return 0
    if ! chg_editable "$_uuid"; then
        chg_refresh "$_uuid"
        return 0
    fi
    local _id="$(chg_session "$_uuid")"
    # The paths become arguments, one each, read line by line into the positional parameters.
    set --
    local _path
    while IFS= read -r _path; do
        [ -n "$_path" ] && set -- "$@" "$_path"
    done <<END
$_paths
END
    local _json _status
    _json="$(agentvm_session_undo "$_id" "$@")"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        main_alert "$_uuid" "Nothing was restored" "$(agentvm_last_error "$_status")"
        chg_refresh "$_uuid"
        chg_sessions_changed
        return "$_status"
    fi
    local _head="$(printf '%s\n' "$_json" | agentvm_undo_head)"
    local _restored="$(printf '%s\n' "$_head" | /usr/bin/cut -f2)"
    local _failed_rows="$(printf '%s\n' "$_json" | agentvm_undo_failed_rows)"
    local _failed="$(printf '%s\n' "$_failed_rows" | /usr/bin/awk -F'\t' 'NF { printf "%s%s (%s)", (n++ ? "; " : ""), $1, $2 }')"
    # What was restored is unchecked; what failed stays checked.
    printf '%s\n' "$_failed_rows" | /usr/bin/awk -F'\t' -v OFS='\t' '
        FNR == NR { if (NF) failed[$1] = 1; next }
        { $1 = ($2 in failed) ? "true" : "false"; print }' - "$(chg_file "$_uuid" rows.tsv)" | ui_store "$(chg_file "$_uuid" rows.tsv)"
    chg_refresh "$_uuid"
    chg_sessions_changed
    if [ -n "$_failed" ]; then
        main_alert "$_uuid" "Some items couldn't be restored" "$(main_count_text "$_restored" item) restored. Not restored: $_failed."
        return 0
    fi
    local _toast="$(main_count_text "$_restored" item) restored."
    [ "$(printf '%s\n' "$_head" | /usr/bin/cut -f1)" = "undone" ] && _toast="$_toast The session is undone."
    "$dialog" "$_uuid" omc_window omc_present_toast "$_toast" "$MAIN_TOAST_SECONDS"
    return 0
}

# chg_sessions_changed  ->  the main window, when one is open, reads the sessions again and paints
# its Sessions tab.
chg_sessions_changed() {
    local _main="$(ui_item_window main window)"
    [ -n "$_main" ] || return 0
    ses_read "$_main"
    ses_paint "$_main" force
}
