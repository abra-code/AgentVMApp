#!/bin/sh
# lib.agentvm.sessions.sh
#
# The main window's Sessions tab: what agent-vm sessions hold on disk, by project.
#
# A session is a snapshot of a project taken before an agent works on it, kept for undo until
# it is discarded. Its snapshot is a copy-on-write clone: it costs nothing until the project's
# copy changes or goes, and then the old data stays with the snapshot, often with several
# snapshots at once. So a figure per session misleads: sessions taken from one state of a
# project each hold nothing of their own and, together, all the project has deleted since.
# agent-vm measures a holder table (`session usage`): for each set of sessions, the bytes held
# by exactly those sessions and not by the project. What discarding the sessions ticked frees
# is summed from it here (agentvm_held_freed), so a tick runs no agent-vm.
#
# THE UNIT IS THE PROJECT. The sidebar's cards are projects, largest "to free" first (the order
# `session usage` gives); the detail pane lists the project's sessions with a checkbox each.
# Sessions of one project share blocks with one another, and only with one another, so the
# project is where the figures are honest. A card's first column is the project's path: a list
# keeps its selection by the first column, and the path is what the pasteboard value
# "session-project" holds.
#
# READING. `session usage` measures (seconds to tens of seconds for a large store), so it runs
# only when the tab is opened and the kept measurement is stale (older than SES_MEASURE_HOURS,
# or sessions started since), and on the Measure Again button; never in the poll loop, which
# reads only `status` (whose `sessions` say how many there are and when they were measured).
# `session list` is cheap and is read with it. Both answers stay in the window's cache.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_SESSIONS_LIB:-}" ] && return 0
__AGENTVM_APP_SESSIONS_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.ui.sh"

# The tab's index in the main window's TabView (Boxes, Images, Sessions, Settings).
SES_TAB_INDEX=2
SES_SPLIT_ID=710
SES_PROJECTS_ID=711
SES_FOOTER_ID=712
SES_NOTE_ID=713
SES_NONE_ID=718
SES_NONE_SELECTED_ID=719
SES_DETAIL_ID=720
SES_NAME_ID=721
SES_PATH_ID=722
SES_HINT_ID=723
SES_TABLE_ID=730
SES_PICKED_ID=731
SES_MEASURE_ID=741
SES_SPACE_ID=751
SES_COUNTS_ID=752
# A kept measurement older than this is taken again when the tab is opened.
SES_MEASURE_HOURS=6
# A card's color: a project with something to free, and one without (only active sessions, or
# nothing measured yet).
SES_CARD_COLOR="#5B4BB7"
SES_CARD_IDLE_COLOR="#6B7280"

# ses_cache <uuid> <name>  ->  the path of one of the tab's cache files.
ses_cache() {
    ui_cache "$1" "$2"
}

# ses_status_row <uuid>  ->  the `sessions` row of the last `status` (agentvm_status_sessions_row),
# or nothing.
ses_status_row() {
    local _file="$(ses_cache "$1" sessions.tsv)"
    [ -f "$_file" ] || return 0
    /usr/bin/awk 'NF' "$_file"
}

# ses_stale <uuid>  ->  0 when the tab should measure on opening: never measured, sessions
# started since the measurement, the measurement older than SES_MEASURE_HOURS, no measurement in
# this window yet, or a newer one than the window's (taken elsewhere).
ses_stale() {
    [ -f "$(ses_cache "$1" session-usage.json)" ] || return 0
    local _row="$(ses_status_row "$1")"
    [ -n "$_row" ] || return 0
    local _unmeasured="$(printf '%s\n' "$_row" | /usr/bin/cut -f5)"
    local _at="$(printf '%s\n' "$_row" | /usr/bin/cut -f6)"
    [ "$_unmeasured" = "0" ] || return 0
    # Measured since by someone else (another window, avm, the command line): the window's holder
    # table is older than the figures `status` gives, and lacks the sessions started in between.
    local _here="$(ses_measured_at "$1")"
    [ "$_here" = "$_at" ] || return 0
    local _seconds="$(ui_seconds_since_epoch "$_at")"
    [ -n "$_seconds" ] || return 0
    local _age=$(( $(main_now) - _seconds ))
    [ "$_age" -ge $((SES_MEASURE_HOURS * 3600)) ]
}

# ses_read <uuid> [measure]  ->  reads `session list`, and with "measure" first `session usage`,
# into the window's cache. A failed measurement is kept in session-error until a measurement
# works (a later read of the list alone does not clear it, since the figures are still the old
# ones), a failed list in session-list-error until a list read works; the tab's note shows both.
# The list is read after a failed measurement too, so the cards show the sessions, not measured.
ses_read() {
    local _uuid="$1"
    local _error="$(ses_cache "$_uuid" session-error)"
    local _json _status
    local _measure_status=0
    if [ "${2:-}" = "measure" ]; then
        _json="$(agentvm_session_usage)"
        _status=$?
        if [ "$_status" -ne 0 ]; then
            ui_one_line "Could not measure the sessions: $(agentvm_last_error "$_status")" | ui_store "$_error"
            _measure_status=$_status
        else
            printf '%s\n' "$_json" | ui_store "$(ses_cache "$_uuid" session-usage.json)"
            : | ui_store "$_error"
        fi
    fi
    local _list_error="$(ses_cache "$_uuid" session-list-error)"
    _json="$(agentvm_session_list)"
    local _list_status=$?
    if [ "$_list_status" -ne 0 ]; then
        ui_one_line "Could not list the sessions: $(agentvm_last_error "$_list_status")" | ui_store "$_list_error"
        return "$_list_status"
    fi
    printf '%s\n' "$_json" | ui_store "$(ses_cache "$_uuid" session-list.json)"
    : | ui_store "$_list_error"
    return "$_measure_status"
}

# ses_session_rows <uuid>  ->  agentvm_session_rows of the cached list.
ses_session_rows() {
    local _file="$(ses_cache "$1" session-list.json)"
    [ -f "$_file" ] || return 0
    agentvm_session_rows < "$_file"
}

# ses_held_rows <uuid>  ->  the holder table of the cached measurement.
ses_held_rows() {
    local _file="$(ses_cache "$1" session-usage.json)"
    [ -f "$_file" ] || return 0
    agentvm_usage_held_rows < "$_file"
}

# ses_measured_at <uuid>  ->  when the cached measurement was taken (ISO 8601), or nothing.
ses_measured_at() {
    local _file="$(ses_cache "$1" session-usage.json)"
    [ -f "$_file" ] || return 0
    /usr/bin/jq -r '.measuredAt // empty' "$_file" 2>/dev/null
}

# ses_card_rows <uuid>  ->  one card per project with a session that is not discarded: path,
# name, line, color. Projects the measurement has come first, in its order (most to free first);
# the others after, by path.
ses_card_rows() {
    local _uuid="$1"
    local _usage="$(ses_cache "$_uuid" session-usage.json)"
    local _held="$(ses_held_rows "$_uuid")"
    # The rows are read from the list once, not once per project.
    local _rows="$(ses_session_rows "$_uuid")"
    printf '%s\n' "$_rows" | /usr/bin/awk -F'\t' -v OFS='\t' '
        NF == 0 { next }
        { count[$2]++; if ($3 == "active") active[$2]++; if (!($2 in seen)) { seen[$2] = 1; order[++n] = $2 } }
        END { for (i = 1; i <= n; i++) print order[i], count[order[i]] - active[order[i]], active[order[i]] + 0 }' > "$(ses_cache "$_uuid" projects.tsv)"
    local _measured=""
    [ -f "$_usage" ] && _measured="$(agentvm_usage_project_rows < "$_usage" | /usr/bin/cut -f1)"
    local _project _ended _active
    {
        printf '%s\n' "$_measured"
        /usr/bin/cut -f1 "$(ses_cache "$_uuid" projects.tsv)" | /usr/bin/sort
    } | /usr/bin/awk 'NF && !seen[$0]++' | while IFS= read -r _project; do
        local _row="$(/usr/bin/awk -F'\t' -v p="$_project" '$1 == p' "$(ses_cache "$_uuid" projects.tsv)")"
        [ -n "$_row" ] || continue
        _ended="$(printf '%s\n' "$_row" | /usr/bin/cut -f2)"
        _active="$(printf '%s\n' "$_row" | /usr/bin/cut -f3)"
        local _ids="$(printf '%s\n' "$_rows" | /usr/bin/awk -F'\t' -v p="$_project" '$2 == p && $3 != "active" { print $1 }' | /usr/bin/paste -sd ' ' -)"
        local _freed=""
        [ -n "$_held" ] && [ -n "$_ids" ] && _freed="$(printf '%s\n' "$_held" | agentvm_held_freed "$_ids")"
        printf '%s\t%s\t%s\t%s\n' "$_project" "$(/usr/bin/basename "$_project")" "$(ses_card_line "$_ended" "$_active" "$_freed")" \
            "$(if [ -n "$_freed" ] && [ "$_freed" != "0" ]; then printf '%s' "$SES_CARD_COLOR"; else printf '%s' "$SES_CARD_IDLE_COLOR"; fi)"
    done
}

# ses_card_line <ended and undone> <active> <bytes to free, or nothing when not measured>  ->
# "2 sessions, about 1 MB to free", "1 active", "3 sessions, 1 active, not measured".
ses_card_line() {
    local _line=""
    [ "$1" -gt 0 ] && _line="$(main_count_text "$1" session)"
    if [ "$2" -gt 0 ]; then
        [ -n "$_line" ] && _line="$_line, "
        _line="${_line}$2 active"
    fi
    if [ "$1" -gt 0 ]; then
        if [ -z "$3" ]; then
            _line="$_line, not measured"
        elif [ "$3" = "0" ]; then
            _line="$_line, nothing to free"
        else
            _line="$_line, about $(ui_size_text "$3") to free"
        fi
    fi
    printf '%s\n' "$_line"
}

# ses_ticked <uuid>  ->  the ids ticked in the table, one per line.
ses_ticked() {
    local _file="$(ses_cache "$1" session-ticks)"
    [ -f "$_file" ] || return 0
    /usr/bin/awk 'NF' "$_file"
}

# ses_table_rows <uuid> <project>  ->  the table's rows for that project's sessions, oldest first:
# the tick, started, state, ended, its own, shared, on disk, then hidden the id and whether the
# tick is disabled (an active session cannot be discarded).
ses_table_rows() {
    local _uuid="$1"
    local _held="$(ses_held_rows "$_uuid")"
    local _ticked="$(ses_ticked "$_uuid" | /usr/bin/paste -sd ' ' -)"
    local _id _project _state _started _ended _undone _scope _bytes _own _at
    ses_session_rows "$_uuid" | /usr/bin/awk -F'\t' -v p="$2" '$2 == p' |
    while IFS="$ui_tab" read -r _id _project _state _started _ended _undone _scope _bytes _own _at; do
        local _tick=false
        case " $_ticked " in *" $_id "*) [ "$_state" != "active" ] && _tick=true ;; esac
        local _started_text="-"
        case "$_started" in
            ''|*[!0123456789]*) ;;
            *) _started_text="$(/bin/date -r "$_started" '+%b %e, %H:%M' | /usr/bin/sed 's/  / /')" ;;
        esac
        local _ended_text="-"
        local _ended_seconds="$(ui_seconds_since_epoch "$_ended")"
        [ -n "$_ended_seconds" ] && _ended_text="$(/bin/date -r "$_ended_seconds" '+%b %e, %H:%M' | /usr/bin/sed 's/  / /')"
        local _state_text="$_state"
        [ "$_scope" = "git" ] && _state_text="$_state (git only)"
        local _own_text="-"
        [ "$_own" != "-" ] && _own_text="$(ui_size_text "$_own")"
        [ "$_own" = "0" ] && _own_text="0 bytes"
        local _shared_text="-"
        if [ -n "$_held" ]; then
            local _shared="$(printf '%s\n' "$_held" | agentvm_held_shared "$_id")"
            local _shared_bytes="${_shared% *}"
            local _others="${_shared#* }"
            if [ "$_shared_bytes" != "0" ]; then
                _shared_text="$(ui_size_text "$_shared_bytes") with $_others other$( [ "$_others" = "1" ] || printf 's')"
            else
                _shared_text="none"
            fi
        fi
        local _disk_text="-"
        [ "$_bytes" != "-" ] && _disk_text="$(ui_size_text "$_bytes")"
        local _disabled=false
        [ "$_state" = "active" ] && _disabled=true
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$_tick" "$_started_text" "$_state_text" "$_ended_text" \
            "$_own_text" "$_shared_text" "$_disk_text" "$_id" "$_disabled"
    done
}

# ses_picked_text <uuid>  ->  what the ticked sessions of the table as painted (session-table.tsv,
# ses_paint_detail) come to: "2 sessions ticked: about 1 MB to free", or how to tick when none is.
ses_picked_text() {
    local _uuid="$1"
    local _ids="$(/usr/bin/awk -F'\t' '$1 == "true" { print $8 }' "$(ses_cache "$_uuid" session-table.tsv)" 2>/dev/null | /usr/bin/paste -sd ' ' -)"
    if [ -z "$_ids" ]; then
        printf 'Tick the sessions to discard; what they free together is shown here.\n'
        return 0
    fi
    local _count="$(printf '%s\n' "$_ids" | /usr/bin/awk '{ print NF }')"
    local _held="$(ses_held_rows "$_uuid")"
    if [ -z "$_held" ] && [ ! -f "$(ses_cache "$_uuid" session-usage.json)" ]; then
        printf '%s ticked: not measured yet.\n' "$(main_count_text "$_count" session)"
        return 0
    fi
    local _freed="$(printf '%s\n' "$_held" | agentvm_held_freed "$_ids")"
    if [ "$_freed" = "0" ]; then
        printf '%s ticked: discarding them frees nothing now; what they hold is held by other sessions or by the project too.\n' "$(main_count_text "$_count" session)"
    else
        printf '%s ticked: about %s to free.\n' "$(main_count_text "$_count" session)" "$(ui_size_text "$_freed")"
    fi
}

# ses_footer_text <uuid>  ->  the line under the project cards: how many sessions are kept, what
# discarding all the ended and undone ones frees, and when that was measured.
ses_footer_text() {
    local _row="$(ses_status_row "$1")"
    [ -n "$_row" ] || return 0
    local _active _ended _undone _discarded _unmeasured _at _bytes _freed _days
    IFS="$ui_tab" read -r _active _ended _undone _discarded _unmeasured _at _bytes _freed _days <<EOF
$_row
EOF
    local _kept=$((_active + _ended + _undone))
    if [ "$_kept" -eq 0 ]; then
        printf 'No sessions kept.\n'
        return 0
    fi
    local _text="$(main_count_text "$_kept" session) kept"
    if [ "$_freed" != "-" ]; then
        _text="$_text, about $(ui_size_text "$_freed") to free"
        [ "$_freed" = "0" ] && _text="$(main_count_text "$_kept" session) kept, nothing to free"
        _text="$_text (measured $(main_time_text_of "$_at"))"
    else
        _text="$_text, not measured yet"
    fi
    [ "$_discarded" -gt 0 ] && _text="$_text. $(main_count_text "$_discarded" "discarded session") keep only their reports"
    printf '%s.\n' "$_text"
}

# main_time_text_of <ISO 8601 time>  ->  "today 14:02", "Nov 24 09:10", or the text as it is.
main_time_text_of() {
    local _seconds="$(ui_seconds_since_epoch "$1")"
    [ -n "$_seconds" ] || { printf '%s\n' "$1"; return 0; }
    local _day="$(/bin/date -r "$_seconds" '+%Y-%m-%d')"
    local _today="$(/bin/date -r "$(main_now)" '+%Y-%m-%d')"
    if [ "$_day" = "$_today" ]; then
        /bin/date -r "$_seconds" '+today %H:%M'
    else
        /bin/date -r "$_seconds" '+%b %e %H:%M' | /usr/bin/sed 's/  / /'
    fi
}

# ses_paint <uuid>  ->  the tab from the caches: the cards, the selection, the detail pane, the
# footer and the note.
ses_paint() {
    local _uuid="$1"
    ses_card_rows "$_uuid" | ui_store "$(ses_cache "$_uuid" session-cards.tsv)"
    "$dialog" "$_uuid" "$SES_PROJECTS_ID" omc_table_set_rows_from_stdin < "$(ses_cache "$_uuid" session-cards.tsv)"
    local _project="$(ui_get session-project "$_uuid")"
    if [ -n "$_project" ]; then
        if [ -n "$(/usr/bin/awk -F'\t' -v p="$_project" '$1 == p' "$(ses_cache "$_uuid" session-cards.tsv)")" ]; then
            "$dialog" "$_uuid" "$SES_PROJECTS_ID" omc_select_row_with_content "$_project" 1
        else
            ui_set session-project "$_uuid" ""
        fi
    fi
    "$dialog" "$_uuid" "$SES_FOOTER_ID" "$(ses_footer_text "$_uuid")"
    "$dialog" "$_uuid" "$SES_NOTE_ID" "$(/bin/cat "$(ses_cache "$_uuid" session-error)" "$(ses_cache "$_uuid" session-list-error)" 2>/dev/null | /usr/bin/awk 'NF')"
    ses_paint_detail "$_uuid"
}

# ses_paint_detail <uuid>  ->  the selected project's pane, or the placeholder: "No Sessions" when
# there is no project at all, "No Project Selected" otherwise.
ses_paint_detail() {
    local _uuid="$1"
    local _project="$(ui_get session-project "$_uuid")"
    local _cards="$(/usr/bin/awk 'NF' "$(ses_cache "$_uuid" session-cards.tsv)" 2>/dev/null)"
    if [ -z "$_project" ]; then
        ui_show "$_uuid" "$SES_DETAIL_ID" 0
        if [ -z "$_cards" ]; then
            ui_show "$_uuid" "$SES_NONE_SELECTED_ID" 0
            ui_show "$_uuid" "$SES_NONE_ID" 1
        else
            ui_show "$_uuid" "$SES_NONE_ID" 0
            ui_show "$_uuid" "$SES_NONE_SELECTED_ID" 1
        fi
        return 0
    fi
    ui_show "$_uuid" "$SES_NONE_ID" 0
    ui_show "$_uuid" "$SES_NONE_SELECTED_ID" 0
    ui_show "$_uuid" "$SES_DETAIL_ID" 1
    local _card="$(printf '%s\n' "$_cards" | /usr/bin/awk -F'\t' -v p="$_project" '$1 == p')"
    "$dialog" "$_uuid" "$SES_NAME_ID" "$(/usr/bin/basename "$_project")"
    "$dialog" "$_uuid" "$SES_PATH_ID" "$_project"
    "$dialog" "$_uuid" "$SES_COUNTS_ID" "$(printf '%s\n' "$_card" | /usr/bin/cut -f3)"
    "$dialog" "$_uuid" "$SES_SPACE_ID" "$(ses_space_text "$_uuid" "$_project")"
    ses_table_rows "$_uuid" "$_project" | ui_store "$(ses_cache "$_uuid" session-table.tsv)"
    "$dialog" "$_uuid" "$SES_TABLE_ID" omc_table_set_rows_from_stdin < "$(ses_cache "$_uuid" session-table.tsv)"
    "$dialog" "$_uuid" "$SES_PICKED_ID" "$(ses_picked_text "$_uuid")"
    "$dialog" "$_uuid" "$SES_HINT_ID" "$(ses_hint_text "$_uuid")"
}

# ses_space_text <uuid> <project>  ->  what discarding all its ended and undone sessions frees.
ses_space_text() {
    local _ids="$(ses_session_rows "$1" | /usr/bin/awk -F'\t' -v p="$2" '$2 == p && $3 != "active" { print $1 }' | /usr/bin/paste -sd ' ' -)"
    if [ -z "$_ids" ]; then
        printf 'nothing to discard: its only session is active\n'
        return 0
    fi
    if [ ! -f "$(ses_cache "$1" session-usage.json)" ]; then
        printf 'not measured yet\n'
        return 0
    fi
    local _freed="$(ses_held_rows "$1" | agentvm_held_freed "$_ids")"
    if [ "$_freed" = "0" ]; then
        printf 'nothing to free by discarding its ended and undone sessions\n'
    else
        printf 'about %s if all its ended and undone sessions are discarded\n' "$(ui_size_text "$_freed")"
    fi
}

# ses_hint_text <uuid>  ->  the note under the table: what the figures mean.
ses_hint_text() {
    local _at="$(ses_measured_at "$1")"
    local _measured=""
    [ -n "$_at" ] && _measured=" Measured $(main_time_text_of "$_at")."
    printf '%s\n' "Deleting files from a project frees nothing while a session still holds them. The figures count what is freed once macOS has removed its local Time Machine snapshots, which keep deleted data for up to a day.$_measured"
}

# ses_open <uuid>  ->  the tab was opened: measure when the kept measurement is stale, else read
# the list only, then paint. While it measures, the footer says so.
ses_open() {
    local _uuid="$1"
    if ses_stale "$_uuid"; then
        "$dialog" "$_uuid" "$SES_FOOTER_ID" "Measuring what the sessions hold..."
        ui_enable "$_uuid" "$SES_MEASURE_ID" 0
        ses_read "$_uuid" measure
        ui_enable "$_uuid" "$SES_MEASURE_ID" 1
        main_read_status "$_uuid"
    else
        ses_read "$_uuid"
    fi
    ses_paint "$_uuid"
}

# ses_tick <uuid> <row index>  ->  the tick of that row of the table changed: the ids ticked are
# taken from the rows as painted, with that one flipped, and the figure follows. An active
# session's tick is disabled and stays off.
ses_tick() {
    local _uuid="$1"
    case "$2" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    local _row="$(/usr/bin/awk -F'\t' -v n="$(( $2 + 1 ))" 'NR == n' "$(ses_cache "$_uuid" session-table.tsv)" 2>/dev/null)"
    [ -n "$_row" ] || return 0
    local _id="$(printf '%s\n' "$_row" | /usr/bin/cut -f8)"
    local _was="$(printf '%s\n' "$_row" | /usr/bin/cut -f1)"
    local _disabled="$(printf '%s\n' "$_row" | /usr/bin/cut -f9)"
    agentvm_valid_session_id "$_id" || return 0
    # An active session's checkbox is disabled; were it fired anyway, its tick is not kept.
    [ "$_disabled" = "true" ] && return 0
    {
        ses_ticked "$_uuid" | /usr/bin/awk -v id="$_id" '$0 != id'
        [ "$_was" = "true" ] || printf '%s\n' "$_id"
    } | ui_store "$(ses_cache "$_uuid" session-ticks)"
    ses_paint_detail "$_uuid"
}
