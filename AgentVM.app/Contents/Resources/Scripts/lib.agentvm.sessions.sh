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
# `session list` is cheap and is read with it, and so is `session exclusions`, every project's
# list of what its snapshots leave out, for the pane's Exclusions row. The answers stay in the
# window's cache.
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
SES_EXCLUSIONS_ID=753
SES_EXCLUSIONS_CHOOSE_ID=754
SES_FOLDER_EXCLUSIONS_ID=743
SES_DISCARD_ID=732
SES_DISCARD_ALL_ID=733
SES_OLDER_ID=742
SES_RESTORE_ID=761
SES_RESTORE_SHOW_ID=762
SES_RESTORE_REMOVE_ID=763
SES_KEPT_ID=771
SES_SHOW_ID=772
SES_EXPIRY_ID=773
SES_EXPIRY_TEXT_ID=774
SES_NUDGE_ID=790
SES_NUDGE_TEXT_ID=791
# The banner below the tabs shows when sessions hold this much that can be freed, and again after
# Not Now once they hold this much more.
SES_NUDGE_BYTES=10000000000
# The ages the expiry picker in Settings offers, in days; 0: never.
SES_EXPIRY_CHOICES="14 30 60 0"
# The two ages Discard Older Than... offers, in days.
SES_OLDER_DAYS="7 30"
# Free space before and after a discard (a seam for the tests).
ses_df_tool="${AGENTVM_APP_DF:-/bin/df}"
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
    ses_read_exclusions "$_uuid"
    return "$_measure_status"
}

# ses_read_exclusions <uuid>  ->  every project's saved exclusions (`session exclusions`) into the
# window's cache, as rows (agentvm_exclusions_rows); when agent-vm cannot say, the file holds
# "-" alone, and the Exclusions row says the list could not be read. Read with the session list,
# and again when the Exclusions window saved a list.
ses_read_exclusions() {
    local _json _status
    _json="$(agentvm_session_exclusions)"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        agentvm_last_error "$_status" >/dev/null
        printf -- '-\n' | ui_store "$(ses_cache "$1" session-exclusions.tsv)"
        return "$_status"
    fi
    printf '%s\n' "$_json" | agentvm_exclusions_rows | ui_store "$(ses_cache "$1" session-exclusions.tsv)"
    return 0
}

# ses_exclusions_text <uuid> <project>  ->  the pane's Exclusions row: "none", the paths saved
# (the first three, then how many more), or why it cannot say.
ses_exclusions_text() {
    local _file="$(ses_cache "$1" session-exclusions.tsv)"
    if [ ! -f "$_file" ]; then
        printf 'not read yet\n'
        return 0
    fi
    if [ "$(/usr/bin/head -n 1 "$_file")" = "-" ]; then
        printf 'could not be read\n'
        return 0
    fi
    # The project through the environment: awk -v would read a backslash in it as an escape.
    local _row="$(SES_PROJECT="$2" /usr/bin/awk -F'\t' '$1 == ENVIRON["SES_PROJECT"]' "$_file")"
    if [ -z "$_row" ]; then
        printf 'none: the snapshots take the whole project\n'
        return 0
    fi
    printf '%s\n' "$_row" | /usr/bin/awk -F'\t' '{
        # How many from agent-vm itself: a path may hold ", ", which the split below cuts.
        n = $2 + 0
        split($3, paths, ", ")
        text = ""
        for (i = 1; i <= n && i <= 3; i++) text = text (i > 1 ? ", " : "") paths[i]
        if (n > 3) text = text " and " (n - 3) " more"
        printf "%s left out of the snapshots\n", text
    }'
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
            *) _started_text="$(/bin/date -r "$_started" '+%b %e %H:%M' | /usr/bin/sed 's/  / /')" ;;
        esac
        local _ended_text="-"
        local _ended_seconds="$(ui_seconds_since_epoch "$_ended")"
        [ -n "$_ended_seconds" ] && _ended_text="$(/bin/date -r "$_ended_seconds" '+%b %e %H:%M' | /usr/bin/sed 's/  / /')"
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
    # The poll loop paints the window on every change of `status`: the tab is painted again only
    # when something it is painted from changed (or a handler wrote into it: "force"). The day is
    # among them, since the footer says "today".
    local _key="$( { /bin/cat "$(ses_cache "$_uuid" session-list.json)" "$(ses_cache "$_uuid" session-usage.json)" \
        "$(ses_cache "$_uuid" sessions.tsv)" "$(ses_cache "$_uuid" session-ticks)" "$(ses_cache "$_uuid" session-error)" \
        "$(ses_cache "$_uuid" session-list-error)" "$(ses_cache "$_uuid" session-exclusions.tsv)" 2>/dev/null
        printf '%s\n%s\n' "$(ui_get session-project "$_uuid")" "$(/bin/date -r "$(main_now)" '+%Y-%m-%d')"; } | /usr/bin/cksum)"
    local _painted="$(ses_cache "$_uuid" session-painted)"
    local _was="$(/bin/cat "$_painted" 2>/dev/null)"
    if [ "${2:-}" != "force" ] && [ "$_key" = "$_was" ]; then
        return 0
    fi
    printf '%s\n' "$_key" | ui_store "$_painted"
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
    local _ended="$(ses_status_row "$_uuid" | /usr/bin/awk -F'\t' '{ print $2 + $3 }')"
    if [ "${_ended:-0}" -gt 0 ]; then
        ui_enable "$_uuid" "$SES_OLDER_ID" 1
    else
        ui_enable "$_uuid" "$SES_OLDER_ID" 0
    fi
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
    "$dialog" "$_uuid" "$SES_EXCLUSIONS_ID" "$(ses_exclusions_text "$_uuid" "$_project")"
    ses_table_rows "$_uuid" "$_project" | ui_store "$(ses_cache "$_uuid" session-table.tsv)"
    "$dialog" "$_uuid" "$SES_TABLE_ID" omc_table_set_rows_from_stdin < "$(ses_cache "$_uuid" session-table.tsv)"
    "$dialog" "$_uuid" "$SES_PICKED_ID" "$(ses_picked_text "$_uuid")"
    "$dialog" "$_uuid" "$SES_HINT_ID" "$(ses_hint_text "$_uuid")"
    ses_paint_buttons "$_uuid" "$_project"
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
    ses_paint "$_uuid" force
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

# ses_paint_buttons <uuid> <project>  ->  Discard Ticked... on while a session of the project is
# ticked, Discard All Ended... while it has an ended or undone session.
ses_paint_buttons() {
    if [ -n "$(ses_ticked_ids "$1")" ]; then
        ui_enable "$1" "$SES_DISCARD_ID" 1
    else
        ui_enable "$1" "$SES_DISCARD_ID" 0
    fi
    if [ -n "$(ses_ended_ids "$1" "$2")" ]; then
        ui_enable "$1" "$SES_DISCARD_ALL_ID" 1
    else
        ui_enable "$1" "$SES_DISCARD_ALL_ID" 0
    fi
}

# ses_ticked_ids <uuid>  ->  the ids ticked in the table as painted, separated by spaces.
ses_ticked_ids() {
    /usr/bin/awk -F'\t' '$1 == "true" && $9 != "true" { print $8 }' "$(ses_cache "$1" session-table.tsv)" 2>/dev/null | /usr/bin/paste -sd ' ' -
}

# ses_ended_ids <uuid> <project>  ->  the ids of the project's ended and undone sessions.
ses_ended_ids() {
    ses_session_rows "$1" | /usr/bin/awk -F'\t' -v p="$2" '$2 == p && $3 != "active" { print $1 }' | /usr/bin/paste -sd ' ' -
}

# ses_store_root <uuid>  ->  the store's folder, from where `status` says it keeps restore images
# (<store>/Cache/ipsw); the home folder when it does not say. Where the free space is read: the
# sessions are on that volume.
ses_store_root() {
    local _directory="$(/usr/bin/awk -F'\t' '{ print $4 }' "$(ses_cache "$1" restore.tsv)" 2>/dev/null)"
    case "$_directory" in
        */Cache/ipsw) printf '%s\n' "${_directory%/Cache/ipsw}" ;;
        *) printf '%s\n' "$HOME" ;;
    esac
}

# ses_free_bytes <uuid>  ->  the free space of the store's volume, in bytes, or nothing.
ses_free_bytes() {
    local _root="$(ses_store_root "$1")"
    "$ses_df_tool" -k "$_root" 2>/dev/null | /usr/bin/awk 'NR == 2 && $4 ~ /^[0123456789]+$/ { printf "%.0f\n", $4 * 1024 }'
}

# ses_question <uuid> <ids> <whose>  ->  the message of the question before a discard: how many,
# what it frees, and that undo ends for them.
ses_question() {
    local _count="$(printf '%s\n' "$2" | /usr/bin/awk '{ print NF }')"
    local _freed="$(ses_held_rows "$1" | agentvm_held_freed "$2")"
    local _space="what they hold only together is not known: they were not measured"
    local _usage="$(ses_cache "$1" session-usage.json)"
    if [ -f "$_usage" ]; then
        if [ "$_freed" = "0" ]; then
            _space="this frees nothing now: what they hold is held by other sessions or by the project too"
        else
            _space="this frees about $(ui_size_text "$_freed") once macOS has removed its local Time Machine snapshots"
        fi
    fi
    printf '%s of %s: their snapshots, and what an undo kept, are deleted; %s. Undo is no longer possible for them; their records and reports stay in agent-vm session list.\n' \
        "$(main_count_text "$_count" session)" "$3" "$_space"
}

# ses_ask <uuid> <ids> <whose>  ->  the question before discarding those sessions; Discard goes on
# with AgentVM.main.session.discard.confirmed, which reads the ids kept here.
ses_ask() {
    local _count="$(printf '%s\n' "$2" | /usr/bin/awk '{ print NF }')"
    ui_set session-discard "$1" "$2"
    "$dialog" "$1" omc_window omc_present_alert "Discard $(main_count_text "$_count" session)?" \
        "$(ses_question "$1" "$2" "$3")" \
        "Cancel:cancel:" "Discard:destructive:AgentVM.main.session.discard.confirmed"
}

# ses_freed_text <before> <after> <expected>  ->  what the discard freed, as the volume's free space
# says it; when that is much less than expected, why (local Time Machine snapshots). Nothing when
# the free space was not read both times.
ses_freed_text() {
    case "$1" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    case "$2" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    local _gained=$(( $2 - $1 ))
    [ "$_gained" -lt 0 ] && _gained=0
    local _text="Free space was $(ui_size_text "$1"), now $(ui_size_text "$2")."
    case "$3" in
        ''|*[!0123456789]*) ;;
        *)
            if [ "$3" -gt 100000000 ] && [ "$_gained" -lt $(( $3 / 2 )) ]; then
                _text="$_text macOS has not given all of it back yet: local Time Machine snapshots keep deleted data for up to a day, and macOS removes them sooner when it needs the space."
            fi ;;
    esac
    printf '%s\n' "$_text"
}

# ses_forget <uuid> <ids>  ->  the window's measurement without those sessions, as agent-vm keeps
# its own after a discard: their part of each holder set goes, and an entry no session holds any
# more was freed. The figures of the others stay right without measuring again.
ses_forget() {
    local _file="$(ses_cache "$1" session-usage.json)"
    [ -f "$_file" ] || return 0
    /usr/bin/jq --arg ids "$2" '($ids | split(" ") | map(select(. != ""))) as $gone
        | .sessions |= map(select(.id as $id | $gone | index($id) | not))
        | .held |= (map(.sessions -= $gone) | map(select(.sessions | length > 0)))' "$_file" > "$_file.new"
    local _status=$?
    if [ "$_status" -eq 0 ]; then
        ui_store "$_file" < "$_file.new"
    else
        /bin/rm -f "$_file"
    fi
    /bin/rm -f "$_file.new"
}

# ses_discard <uuid> <ids>  ->  discards those sessions: the free space before and after, the ticks
# and the window's measurement without them, the list and status read again, and what it freed
# said (or why it failed). The ids are checked here: they came back through the pasteboard.
ses_discard() {
    local _uuid="$1"
    local _id
    for _id in $2; do
        agentvm_valid_session_id "$_id" || return 0
    done
    # agent-vm discards an active session when asked by id: one the list shows as active is left
    # out here, whatever brought its id (an agent may still be working on its project).
    local _active=" $(ses_session_rows "$_uuid" | /usr/bin/awk -F'\t' '$3 == "active" { print $1 }' | /usr/bin/paste -sd ' ' -) "
    local _ids=""
    for _id in $2; do
        case "$_active" in
            *" $_id "*) ;;
            *) _ids="$_ids $_id" ;;
        esac
    done
    _ids="${_ids# }"
    [ -n "$_ids" ] || return 0
    local _expected="$(ses_held_rows "$_uuid" | agentvm_held_freed "$_ids")"
    local _before="$(ses_free_bytes "$_uuid")"
    # shellcheck disable=SC2086 # the ids are words
    agentvm_session_discard $_ids > /dev/null
    local _status=$?
    local _after="$(ses_free_bytes "$_uuid")"
    if [ "$_status" -ne 0 ]; then
        main_alert "$_uuid" "Not every session was discarded" "$(agentvm_last_error "$_status")"
    fi
    ses_read "$_uuid"
    # A refusal leaves all as they were, and a failure partway discards some: then only the ids
    # the list read again no longer has are gone (none when it could not be read).
    local _gone="$_ids"
    if [ "$_status" -ne 0 ]; then
        local _listed=" $(ses_session_rows "$_uuid" | /usr/bin/cut -f1 | /usr/bin/paste -sd ' ' -) "
        _gone=""
        for _id in $_ids; do
            case "$_listed" in
                *" $_id "*) ;;
                *) _gone="$_gone $_id" ;;
            esac
        done
    fi
    ses_forget "$_uuid" "$_gone"
    ses_ticked "$_uuid" | /usr/bin/awk -v gone=" $_gone " 'index(gone, " " $0 " ") == 0' | ui_store "$(ses_cache "$_uuid" session-ticks)"
    main_read_status "$_uuid"
    ses_paint "$_uuid" force
    [ "$_status" -eq 0 ] || return "$_status"
    local _text="$(ses_freed_text "$_before" "$_after" "$_expected")"
    case "$_text" in
        *"Time Machine"*) main_alert "$_uuid" "The sessions are discarded" "$_text" ;;
        '') "$dialog" "$_uuid" omc_window omc_present_toast "The sessions are discarded." "$MAIN_TOAST_SECONDS" ;;
        *) "$dialog" "$_uuid" omc_window omc_present_toast "The sessions are discarded. $_text" "$MAIN_TOAST_SECONDS" ;;
    esac
    return 0
}

# ses_older_ids <uuid> <days> [undo]  ->  the ended and undone sessions, of every project, that
# ended that many days ago or earlier (a session with no end counts from its start), as agent-vm's
# `session discard --older-than` takes them. With "undo", an undone session counts from its undo
# when that is later, as the store's expiry (`store sessions --discard-after`) takes them.
ses_older_ids() {
    local _cutoff=$(( $(main_now) - $2 * 86400 ))
    local _from_undo="${3:-}"
    local _id _project _state _started _ended _undone _rest
    ses_session_rows "$1" | while IFS="$ui_tab" read -r _id _project _state _started _ended _undone _rest; do
        [ "$_state" = "active" ] && continue
        local _when="$(ui_seconds_since_epoch "$_ended")"
        [ -n "$_when" ] || _when="$_started"
        if [ "$_from_undo" = "undo" ]; then
            local _undo_when="$(ui_seconds_since_epoch "$_undone")"
            case "$_undo_when:$_when" in
                *[!0123456789:]*|:*|*:) ;;
                *) [ "$_undo_when" -gt "$_when" ] && _when="$_undo_when" ;;
            esac
        fi
        case "$_when" in
            ''|*[!0123456789]*) continue ;;
        esac
        [ "$_when" -le "$_cutoff" ] && printf '%s\n' "$_id"
    done | /usr/bin/paste -sd ' ' -
}

# ses_older_ask <uuid>  ->  the question of Discard Older Than...: for each age offered, how many
# sessions ended that long ago and what discarding them frees; a button per age that has any.
ses_older_ask() {
    local _uuid="$1"
    local _text="" _buttons="" _days
    local _usage="$(ses_cache "$_uuid" session-usage.json)"
    for _days in $SES_OLDER_DAYS; do
        local _ids="$(ses_older_ids "$_uuid" "$_days")"
        local _count="$(printf '%s\n' "$_ids" | /usr/bin/awk '{ print NF }')"
        local _part="ended $_days days ago or earlier: $(main_count_text "$_count" session)"
        if [ "$_count" -gt 0 ] && [ -f "$_usage" ]; then
            _part="$_part, about $(ui_size_text "$(ses_held_rows "$_uuid" | agentvm_held_freed "$_ids")") to free"
        fi
        [ -n "$_text" ] && _text="$_text; "
        _text="$_text$_part"
        [ "$_count" -gt 0 ] && _buttons="$_buttons $_days"
        # What the question names for this age is what its button discards (ses_older).
        ui_set "session-older-$_days" "$_uuid" "$_ids"
    done
    if [ -z "$_buttons" ]; then
        main_alert "$_uuid" "No session ended that long ago" "Sessions $_text."
        return 0
    fi
    # One button per age with sessions, each with its own action: the alert passes no value. The
    # actions are spelled out, so the wiring test sees each one with its script.
    set -- "Cancel:cancel:"
    for _days in $_buttons; do
        case "$_days" in
            7) set -- "$@" "Older Than 7 Days:destructive:AgentVM.main.session.older.7" ;;
            30) set -- "$@" "Older Than 30 Days:destructive:AgentVM.main.session.older.30" ;;
        esac
    done
    "$dialog" "$_uuid" omc_window omc_present_alert "Discard the sessions that ended long ago?" \
        "Sessions $_text. Their snapshots are deleted; undo is no longer possible for them, and their records and reports stay. Active sessions are never discarded." "$@"
}

# ses_older <uuid> <days>  ->  discards the sessions the question of Discard Older Than... named for
# that age (kept when it asked: sessions that crossed the line since, or were listed since, are
# not taken), through ses_discard; the ids of every age are then forgotten.
ses_older() {
    local _ids="$(ui_get "session-older-$2" "$1")"
    local _days
    for _days in $SES_OLDER_DAYS; do
        ui_set "session-older-$_days" "$1" ""
    done
    [ -n "$_ids" ] || return 0
    ses_discard "$1" "$_ids"
}

# -- Settings: the Sessions group and the macOS restore images row ----------------------------

# ses_status_field <uuid> <column>  ->  that column of the `sessions` row of `status`.
ses_status_field() {
    ses_status_row "$1" | /usr/bin/cut -f"$2"
}

# ses_kept_text <uuid>  ->  Settings' "Kept now" of the sessions: "23 sessions, about 31.7 GB to
# free", "3 sessions, not measured yet", "none".
ses_kept_text() {
    local _row="$(ses_status_row "$1")"
    [ -n "$_row" ] || { printf -- '-\n'; return 0; }
    local _kept="$(printf '%s\n' "$_row" | /usr/bin/awk -F'\t' '{ print $1 + $2 + $3 }')"
    if [ "$_kept" = "0" ]; then
        printf 'none\n'
        return 0
    fi
    local _freed="$(printf '%s\n' "$_row" | /usr/bin/cut -f8)"
    case "$_freed" in
        ''|-) printf '%s, not measured yet\n' "$(main_count_text "$_kept" session)" ;;
        0) printf '%s, nothing to free\n' "$(main_count_text "$_kept" session)" ;;
        *) printf '%s, about %s to free\n' "$(main_count_text "$_kept" session)" "$(ui_size_text "$_freed")" ;;
    esac
}

# ses_expiry_text <days>  ->  what the store's expiry means, beside the picker.
ses_expiry_text() {
    case "$1" in
        0) printf 'kept until discarded\n' ;;
        ''|-) printf '\n' ;;
        *) printf 'an ended session goes %s days after it ends, at the end of a later session\n' "$1" ;;
    esac
}

# ses_disk_text <uuid>  ->  what follows the free disk space in This Mac: what sessions hold that
# can be freed, when it is 1 GB or more; nothing otherwise.
ses_disk_text() {
    local _freed="$(ses_status_field "$1" 8)"
    case "$_freed" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    [ "$_freed" -ge 1000000000 ] || return 0
    printf '; agent-vm sessions hold about %s you can free\n' "$(ui_size_text "$_freed")"
}

# ses_restore_text <uuid>  ->  the macOS restore images kept: "1, 25.6 GB", with an interrupted
# download's size, or "none".
ses_restore_text() {
    local _row="$(/usr/bin/awk 'NF' "$(ses_cache "$1" restore.tsv)" 2>/dev/null)"
    [ -n "$_row" ] || { printf -- '-\n'; return 0; }
    local _count="$(printf '%s\n' "$_row" | /usr/bin/cut -f1)"
    local _bytes="$(printf '%s\n' "$_row" | /usr/bin/cut -f2)"
    local _partial="$(printf '%s\n' "$_row" | /usr/bin/cut -f3)"
    local _text="none"
    [ "$_count" != "0" ] && _text="$_count, $(ui_size_text "$_bytes")"
    case "$_partial" in
        ''|0|*[!0123456789]*) ;;
        *) _text="$_text, and $(ui_size_text "$_partial") of an interrupted download" ;;
    esac
    printf '%s\n' "$_text"
}

# ses_paint_settings <uuid>  ->  Settings' Sessions group and restore images row, from `status`.
ses_paint_settings() {
    local _uuid="$1"
    "$dialog" "$_uuid" "$SES_KEPT_ID" "$(ses_kept_text "$_uuid")"
    local _days="$(ses_status_field "$_uuid" 9)"
    case " $SES_EXPIRY_CHOICES " in
        *" $_days "*) "$dialog" "$_uuid" "$SES_EXPIRY_ID" "$_days" ;;
        *) "$dialog" "$_uuid" "$SES_EXPIRY_ID" "" ;;
    esac
    if [ -n "$_days" ]; then
        ui_enable "$_uuid" "$SES_EXPIRY_ID" 1
    else
        ui_enable "$_uuid" "$SES_EXPIRY_ID" 0
    fi
    "$dialog" "$_uuid" "$SES_EXPIRY_TEXT_ID" "$(ses_expiry_text "$_days")"
    "$dialog" "$_uuid" "$SES_RESTORE_ID" "$(ses_restore_text "$_uuid")"
    local _count="$(/usr/bin/cut -f1 "$(ses_cache "$_uuid" restore.tsv)" 2>/dev/null)"
    local _folder="$(/usr/bin/cut -f4 "$(ses_cache "$_uuid" restore.tsv)" 2>/dev/null)"
    if [ -n "$_folder" ] && [ -d "$_folder" ]; then
        ui_enable "$_uuid" "$SES_RESTORE_SHOW_ID" 1
    else
        ui_enable "$_uuid" "$SES_RESTORE_SHOW_ID" 0
    fi
    case "$_count" in
        ''|0|*[!0123456789]*) ui_enable "$_uuid" "$SES_RESTORE_REMOVE_ID" 0 ;;
        *) ui_enable "$_uuid" "$SES_RESTORE_REMOVE_ID" 1 ;;
    esac
}

# ses_expiry_question <uuid> <days>  ->  the question before an expiry that would discard sessions: how many ended
# sessions it would discard at the end of the next session, and what that frees; nothing when
# none would go (then nothing is asked).
ses_expiry_question() {
    local _ids="$(ses_older_ids "$1" "$2" undo)"
    [ -n "$_ids" ] || return 0
    local _count="$(printf '%s\n' "$_ids" | /usr/bin/awk '{ print NF }')"
    local _were="were"
    [ "$_count" = "1" ] && _were="was"
    local _text="At the end of the next session, agent-vm discards the $(main_count_text "$_count" session) that ended, or $_were undone, $2 days ago or earlier"
    local _usage="$(ses_cache "$1" session-usage.json)"
    if [ -f "$_usage" ]; then
        _text="$_text (about $(ui_size_text "$(ses_held_rows "$1" | agentvm_held_freed "$_ids")") to free)"
    fi
    printf '%s, and from then on each one %s days after it ends. Undo is then no longer possible for them. It is a setting of the store, for Terminal and Cadabra too.\n' "$_text" "$2"
}

# ses_expiry_apply <uuid> <days>  ->  the store's expiry set, status read again, Settings painted;
# a refusal is said in an alert.
ses_expiry_apply() {
    agentvm_store_discard_after "$2"
    local _status=$?
    [ "$_status" -eq 0 ] || main_alert "$1" "The expiry was not changed" "$(agentvm_last_error "$_status")"
    main_read_status "$1"
    ses_paint_settings "$1"
}

# ses_restore_question <uuid> <names>  ->  the question before removing the restore images named.
ses_restore_question() {
    local _count="$(printf '%s\n' "$2" | /usr/bin/awk '{ print NF }')"
    local _what="it"
    [ "$_count" = "1" ] || _what="them"
    printf '%s. A new macOS image needs a restore image again: Get macOS... downloads one (about 27 GB). Images and boxes made from %s are not touched.\n' \
        "$(printf '%s\n' "$2" | /usr/bin/tr ' ' '\n' | /usr/bin/paste -sd ',' - | /usr/bin/sed 's/,/, /g')" "$_what"
}

# -- The banner below the tabs ------------------------------------------------------------------
# One line below the main window's tabs when the sessions hold SES_NUDGE_BYTES or more that
# discarding them would free (from the last measurement, as `status` gives it): nothing else in
# the window says so while another tab is shown. Not Now hides it until they hold SES_NUDGE_BYTES
# more than when it was dismissed; that figure is the app's pasteboard value
# "agentvm_sessions_nudge_dismissed", kept while the app runs.

# ses_nudge_bytes <uuid>  ->  what the banner would name, or nothing when it is not to be shown.
ses_nudge_bytes() {
    local _freed="$(ses_status_field "$1" 8)"
    case "$_freed" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    local _dismissed="$("$pasteboard" agentvm_sessions_nudge_dismissed get)"
    case "$_dismissed" in
        ''|*[!0123456789]*) ;;
        *)
            # Less than when Not Now was chosen (sessions were discarded): forgotten, so the
            # banner comes back at the usual figure, not 10 GB above the old one.
            if [ "$_freed" -lt "$_dismissed" ]; then
                "$pasteboard" agentvm_sessions_nudge_dismissed set ""
            elif [ "$_freed" -lt $((_dismissed + SES_NUDGE_BYTES)) ]; then
                return 0
            fi ;;
    esac
    [ "$_freed" -ge "$SES_NUDGE_BYTES" ] || return 0
    printf '%s\n' "$_freed"
}

# ses_nudge_show <uuid> <0|1>  ->  the banner shown, or hidden and collapsed. A hidden view keeps
# its space in ActionUI, so a hidden banner would leave an empty strip below the tabs: hidden, its
# frame is 0 high (as in AgentVM.json); shown, the frame is set back first.
ses_nudge_show() {
    if [ "$2" = "1" ]; then
        "$dialog" "$1" "$SES_NUDGE_ID" omc_set_property frame '{"maxWidth":"infinity"}'
        ui_show "$1" "$SES_NUDGE_ID" 1
    else
        ui_show "$1" "$SES_NUDGE_ID" 0
        "$dialog" "$1" "$SES_NUDGE_ID" omc_set_property frame '{"maxWidth":"infinity","maxHeight":0}'
    fi
}

# ses_paint_nudge <uuid> <face>  ->  the banner shown, with its text, or hidden (always on the Get
# started face).
ses_paint_nudge() {
    local _bytes=""
    [ "$2" = "status" ] && _bytes="$(ses_nudge_bytes "$1")"
    if [ -z "$_bytes" ]; then
        ses_nudge_show "$1" 0
        return 0
    fi
    "$dialog" "$1" "$SES_NUDGE_TEXT_ID" "agent-vm sessions hold about $(ui_size_text "$_bytes") that only their undo needs; discarding them frees it."
    ses_nudge_show "$1" 1
}

# ses_nudge_dismiss <uuid>  ->  Not Now: the figure kept, the banner hidden.
ses_nudge_dismiss() {
    local _freed="$(ses_status_field "$1" 8)"
    case "$_freed" in
        ''|*[!0123456789]*) ;;
        *) "$pasteboard" agentvm_sessions_nudge_dismissed set "$_freed" ;;
    esac
    ses_nudge_show "$1" 0
}
