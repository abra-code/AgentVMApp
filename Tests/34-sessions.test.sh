#!/bin/sh
# Tests/34-sessions.test.sh - the main window's Sessions tab: opening it measures when the kept
# measurement is stale (and only then), the project cards, the footer, a project's sessions with
# their checkboxes (an active one's disabled), what the sessions ticked free together, Measure
# Again, a measurement taken elsewhere, a failed measurement, and a project value the cards do not
# hold.
#
# agent-vm is the fake: status is status-variety.json with the `sessions` of
# status-sessions.json (a project ~/src/myapp: two ended sessions that hold a deleted 1 MiB file
# together and neither alone, and one active session), and `session usage` and `session list`
# answer the fixtures captured with it.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.sessions.sh"
[ -n "$SES_PROJECTS_ID" ] && [ -n "$SES_TABLE_ID" ] && [ -n "$SES_FOOTER_ID" ] && [ -n "$MAIN_STATUS_ID" ] || {
    printf '34-sessions: no view ids imported from the libraries\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
TZ=UTC
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG TZ
PROJECT="/Users/you/src/myapp"
MEASURED="$(/usr/bin/jq -r '.sessions.measuredAt' "$FIXTURES_AGENTVM/status-sessions.json")"
MEASURED_SECONDS="$(/bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$MEASURED" +%s)"

# now_after <hours>  ->  the clock that many hours after the fixture's measurement.
now_after() {
    AGENTVM_APP_NOW=$((MEASURED_SECONDS + $1 * 3600))
    export AGENTVM_APP_NOW
}

# open_window  ->  a new main window: the one before is closed, so none of its cache is left.
open_window() {
    omc_run AgentVM.main.close
    fake_reset
    /usr/bin/jq --slurpfile s "$FIXTURES_AGENTVM/status-sessions.json" '.sessions = $s[0].sessions' \
        "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}

# open_tab <index>  ->  that tab chosen.
open_tab() {
    omc_trigger "$MAIN_STATUS_ID" "" "$1"
    omc_run AgentVM.main.tab
}

measured_count() {
    /bin/cat "$FAKE_AGENTVM_DIR/session-usage-count" 2>/dev/null || echo 0
}

select_project() {
    omc_table_cell "$SES_PROJECTS_ID" 1 "$1"
    omc_trigger "$SES_PROJECTS_ID"
    omc_run AgentVM.main.session.project.selected
}

tick() {
    omc_trigger "$SES_TABLE_ID" 0 "$1"
    omc_run AgentVM.main.session.tick
}

shown() {
    [ "$(ui_visible "$1")" = "1" ] && echo 1 || echo 0
}

ENDED1="$(lib agentvm_session_rows < "$FIXTURES_AGENTVM/session-list.json" | /usr/bin/awk -F'\t' 'NR == 1 { print $1 }')"
ACTIVE="$(lib agentvm_session_rows < "$FIXTURES_AGENTVM/session-list.json" | /usr/bin/awk -F'\t' 'NR == 3 { print $1 }')"

section "opening the tab"
now_after 1
open_window
check "the window opened on the Status face, and measured nothing" "1|0" "$(shown "$MAIN_STATUS_ID")|$(measured_count)"
open_tab 0
check "choosing Boxes reads nothing about sessions" "0|" "$(measured_count)|$(fake_log | /usr/bin/grep '^session ')"
open_tab 2
check "opening Sessions the first time measures, lists the sessions and reads what each project leaves out" "1|session usage --json|session list --json|session exclusions --json" \
    "$(measured_count)|$(fake_log | /usr/bin/grep '^session ' | /usr/bin/paste -sd '|' -)"
check "one card: the project's path, its name, two sessions and one active with 1 MB to free" \
    "$PROJECT${TAB}myapp${TAB}2 sessions, 1 active, about 1 MB to free" "$(ui_rows "$SES_PROJECTS_ID" | col 1-3)"
check "the footer: three kept, 1 MB to free, and when it was measured" \
    "3 sessions kept, about 1 MB to free (measured today $(/bin/date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$MEASURED" '+%H:%M'))." \
    "$(ui_value "$SES_FOOTER_ID")"
check "no project selected yet: its placeholder, not the one for no sessions" "1|0|0" \
    "$(shown "$SES_NONE_SELECTED_ID")|$(shown "$SES_NONE_ID")|$(shown "$SES_DETAIL_ID")"
open_tab 2
check "opening it again within the hours a measurement holds measures nothing more" "1" "$(measured_count)"

section "a project's sessions"
select_project "$PROJECT"
check "its pane: the name, the path, what all its ended sessions free" \
    "1|myapp|$PROJECT|about 1 MB to free" \
    "$(shown "$SES_DETAIL_ID")|$(ui_value "$SES_NAME_ID")|$(ui_value "$SES_PATH_ID")|$(ui_value "$SES_SPACE_ID")"
rows="$(ui_rows "$SES_TABLE_ID")"
check "a row per session, none ticked: two ended, one active" "false ended|false ended|false active" \
    "$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' '{ print $1, $3 }' | /usr/bin/paste -sd '|' -)"
check "  each holds nothing of its own, and the ended ones 1 MB with one other" "0 bytes${TAB}1 MB with 1 other|0 bytes${TAB}1 MB with 1 other|0 bytes${TAB}none" \
    "$(printf '%s\n' "$rows" | col 5-6 | /usr/bin/paste -sd '|' -)"
check "  the active session's checkbox is disabled; the hidden column has the id" "false|false|true|$ACTIVE" \
    "$(printf '%s\n' "$rows" | col 9 | /usr/bin/paste -sd '|' -)|$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' 'NR == 3 { print $8 }')"
check "  nothing ticked yet" "Check sessions to see what discarding them frees." "$(ui_value "$SES_PICKED_ID")"

section "ticking sessions"
tick 0
check "one ended session alone frees nothing: the other holds the same data" \
    "1 session checked: nothing to free (shared with other sessions or the project)." \
    "$(ui_value "$SES_PICKED_ID")"
check "  its row is ticked" "true" "$(ui_rows "$SES_TABLE_ID" | /usr/bin/awk -F'\t' 'NR == 1 { print $1 }')"
tick 1
check "both together free 1 MB" "2 sessions checked: about 1 MB to free." "$(ui_value "$SES_PICKED_ID")"
check "  and no agent-vm ran for it" "1" "$(measured_count)"
tick 2
check "the active one cannot be ticked" "false|2 sessions checked: about 1 MB to free." \
    "$(ui_rows "$SES_TABLE_ID" | /usr/bin/awk -F'\t' 'NR == 3 { print $1 }')|$(ui_value "$SES_PICKED_ID")"
tick 0
check "unticking one leaves the other" "true|1 session checked: nothing to free (shared with other sessions or the project)." \
    "$(ui_rows "$SES_TABLE_ID" | /usr/bin/awk -F'\t' 'NR == 2 { print $1 }')|$(ui_value "$SES_PICKED_ID")"
tick 99
check "a row the table does not have changes nothing" "true" "$(ui_rows "$SES_TABLE_ID" | /usr/bin/awk -F'\t' 'NR == 2 { print $1 }')"

section "measuring again, and a stale measurement"
omc_trigger "$SES_MEASURE_ID"
omc_run AgentVM.main.session.measure
check "Measure Again measures, and keeps the project selected" "2|1" "$(measured_count)|$(shown "$SES_DETAIL_ID")"
now_after 7
open_tab 2
check "opening the tab when the measurement is 7 hours old measures again" "3" "$(measured_count)"

section "a project the cards do not hold"
select_project "/Users/you/src/other"
check "is not selected: the placeholder" "1|0" "$(shown "$SES_NONE_SELECTED_ID")|$(shown "$SES_DETAIL_ID")"

section "measured elsewhere"
now_after 1
open_window
open_tab 2
LATER="$(/bin/date -u -r $((MEASURED_SECONDS + 1800)) '+%Y-%m-%dT%H:%M:%SZ')"
/usr/bin/jq --arg at "$LATER" '.sessions.measuredAt = $at' "$FAKE_AGENTVM_DIR/status.json" > "$FAKE_AGENTVM_DIR/status.json.new"
/bin/mv -f "$FAKE_AGENTVM_DIR/status.json.new" "$FAKE_AGENTVM_DIR/status.json"
omc_run AgentVM.main.activated
open_tab 2
check "a measurement newer than the window's (another window, the command line) is taken again on opening" "2" "$(measured_count)"

section "a failed measurement"
now_after 1
open_window
printf 'the store is busy\n' > "$FAKE_AGENTVM_DIR/fail-session-usage"
open_tab 2
check "the note says why, and the cards still list the project, not measured" \
    "1|$PROJECT${TAB}myapp${TAB}2 sessions, 1 active, not measured" \
    "$(ui_value "$SES_NOTE_ID" | /usr/bin/grep -c '^Could not measure the sessions: .*the store is busy')|$(ui_rows "$SES_PROJECTS_ID" | col 1-3)"

section "no sessions"
now_after 1
open_window
printf '[]\n' > "$FAKE_AGENTVM_DIR/session-list.json"
printf '{"projects": []}\n' > "$FAKE_AGENTVM_DIR/session-exclusions.json"
printf '{"formatVersion": 1, "held": [], "measuredAt": "%s", "notes": [], "projects": [], "sessions": [], "totals": {"bytes": 0, "freedIfAllDiscardedBytes": 0, "sessions": 0}}\n' "$MEASURED" > "$FAKE_AGENTVM_DIR/session-usage.json"
open_tab 2
check "no card, and the placeholder that says what sessions are" "|1|0" \
    "$(ui_rows "$SES_PROJECTS_ID")|$(shown "$SES_NONE_ID")|$(shown "$SES_NONE_SELECTED_ID")"

section "the banner below the tabs"
now_after 1
open_window
check "1 MB to free: no banner, and it takes no space" "0|{\"maxWidth\":\"infinity\",\"maxHeight\":0}" "$(shown "$SES_NUDGE_ID")|$(ui_prop "$SES_NUDGE_ID" frame)"
"$OMC_OMC_SUPPORT_PATH/pasteboard" agentvm_sessions_nudge_dismissed set ""
/usr/bin/jq '.sessions.freedIfAllDiscardedBytes = 31700000000' "$FAKE_AGENTVM_DIR/status.json" > "$FAKE_AGENTVM_DIR/status.new" && /bin/mv "$FAKE_AGENTVM_DIR/status.new" "$FAKE_AGENTVM_DIR/status.json"
omc_run AgentVM.main.activated
check "31.7 GB to free: the banner says so" "1|{\"maxWidth\":\"infinity\"}|Sessions hold about 31.7 GB you can free." \
    "$(shown "$SES_NUDGE_ID")|$(ui_prop "$SES_NUDGE_ID" frame)|$(ui_value "$SES_NUDGE_TEXT_ID")"
omc_run AgentVM.main.session.nudge.dismiss
check "  Not Now hides it" "0" "$(shown "$SES_NUDGE_ID")"
omc_run AgentVM.main.activated
check "  and it stays hidden while the figure is the same" "0" "$(shown "$SES_NUDGE_ID")"
/usr/bin/jq '.sessions.freedIfAllDiscardedBytes = 42000000000' "$FAKE_AGENTVM_DIR/status.json" > "$FAKE_AGENTVM_DIR/status.new" && /bin/mv "$FAKE_AGENTVM_DIR/status.new" "$FAKE_AGENTVM_DIR/status.json"
omc_run AgentVM.main.activated
check "  10 GB more: it is back" "1" "$(shown "$SES_NUDGE_ID")"
omc_run AgentVM.main.session.nudge.dismiss
/usr/bin/jq '.sessions.freedIfAllDiscardedBytes = 1000000000' "$FAKE_AGENTVM_DIR/status.json" > "$FAKE_AGENTVM_DIR/status.new" && /bin/mv "$FAKE_AGENTVM_DIR/status.new" "$FAKE_AGENTVM_DIR/status.json"
omc_run AgentVM.main.activated
/usr/bin/jq '.sessions.freedIfAllDiscardedBytes = 12000000000' "$FAKE_AGENTVM_DIR/status.json" > "$FAKE_AGENTVM_DIR/status.new" && /bin/mv "$FAKE_AGENTVM_DIR/status.new" "$FAKE_AGENTVM_DIR/status.json"
omc_run AgentVM.main.activated
check "  dismissed at 42 GB, then discarded down to 1 GB: it is back at 12 GB, not 52" "1" "$(shown "$SES_NUDGE_ID")"
"$OMC_OMC_SUPPORT_PATH/pasteboard" agentvm_sessions_nudge_dismissed set ""

section "the project cards: when the last session ended, and the sort menu"
# Besides myapp: zeta, whose session ended later the same day; old, ended a year earlier; and
# alpha, with no session and a saved list of exclusions. Only myapp is in the measurement.
# sort_by <date|size> <true|false>  ->  that item of the sort menu picked: its toggle as the click
# leaves it (false: it was checked already).
sort_by() {
    local _id="$SES_SORT_SIZE_ID"
    [ "$1" = "date" ] && _id="$SES_SORT_DATE_ID"
    omc_control "$_id" "$2"
    omc_trigger "$_id"
    omc_run "AgentVM.main.session.sort.$1"
}
# checked  ->  the sort menu's check marks: Sort by Date, Sort by Size.
checked() {
    printf '%s,%s\n' "$(ui_value "$SES_SORT_DATE_ID")" "$(ui_value "$SES_SORT_SIZE_ID")"
}
cards() {
    ui_rows "$SES_PROJECTS_ID" | /usr/bin/awk -F'\t' '{ print $2 "=" $5 }' | /usr/bin/paste -sd '|' -
}
selected() {
    "$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_session-project_$OMC_ACTIONUI_WINDOW_UUID" get
}
enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}
write_projects() {
    /usr/bin/jq '. + [
        {"endedAt": "2026-11-25T09:00:00Z", "formatVersion": 1, "id": "20261125-040000-aaaa", "project": "/Users/you/src/zeta", "startSeconds": 1795595000, "state": "ended"},
        {"endedAt": "2025-03-01T10:00:00Z", "formatVersion": 1, "id": "20250301-050000-bbbb", "project": "/Users/you/src/old", "startSeconds": 1740800000, "state": "ended"}]' \
        "$FIXTURES_AGENTVM/session-list.json" > "$FAKE_AGENTVM_DIR/session-list.json"
    printf '{"projects": [{"project": "/Users/you/src/alpha", "paths": [".build"]}, {"project": "%s", "paths": [".build"]}]}\n' "$PROJECT" > "$FAKE_AGENTVM_DIR/session-exclusions.json"
}
now_after 1
"$OMC_OMC_SUPPORT_PATH/pasteboard" agentvm_sessions_sort set ""
open_window
write_projects
open_tab 2
check "by size, the default: the measured project first, then the others by path; each with when its last session ended" \
    "myapp=Today 08:22|alpha=|old=Mar 1 2025|zeta=Today 09:00" "$(cards)"
check "  the menu checks Sort by Size" "false,true" "$(checked)"
check "  a project with no session: no time, and the card says so" "no sessions yet" \
    "$(ui_rows "$SES_PROJECTS_ID" | /usr/bin/awk -F'\t' '$2 == "alpha" { print $3 }')"
select_project "/Users/you/src/zeta"
sort_by date true
check "by date: the latest end first, a project with none at the end" "zeta=Today 09:00|myapp=Today 08:22|old=Mar 1 2025|alpha=" "$(cards)"
check "  the choice is kept for the app, the menu checks it alone, and the selection stays on the project" "date|true,false|/Users/you/src/zeta|0" \
    "$("$OMC_OMC_SUPPORT_PATH/pasteboard" agentvm_sessions_sort get)|$(checked)|$(selected)|$(ui_selection "$SES_PROJECTS_ID")"
sort_by date false
check "  picking the checked item again keeps the order and its check mark" "date|true,false|zeta=Today 09:00|myapp=Today 08:22|old=Mar 1 2025|alpha=" \
    "$("$OMC_OMC_SUPPORT_PATH/pasteboard" agentvm_sessions_sort get)|$(checked)|$(cards)"
open_window
write_projects
open_tab 2
check "  a new window sorts as chosen" "true,false|zeta" "$(checked)|$(cards | /usr/bin/cut -d= -f1)"
/usr/bin/jq '[.[] | if .state == "active" then . else empty end]' "$FIXTURES_AGENTVM/session-list.json" > "$FAKE_AGENTVM_DIR/session-list.json"
omc_run AgentVM.main.session.measure
check "a project whose only sessions are active: on top by date, said on its card" "myapp=Active|alpha=" "$(cards)"

section "adding a project, and opening its folder"
ADDED="$OMCTEST_WORK/projects/newapp"
/bin/mkdir -p "$ADDED"
: > "$FAKE_OPEN_LOG"
check "nothing selected: the folder button is off" "0" "$(enabled "$SES_REVEAL_ID")"
omc_dialog_answer choose_folder ""
omc_run AgentVM.main.session.project.add
check "Cancel in the folder panel adds nothing" "myapp|alpha" "$(cards | /usr/bin/sed 's/=[^|]*//g')"
omc_dialog_answer choose_folder "$ADDED/"
omc_run AgentVM.main.session.project.add
check "the folder chosen becomes a card, without its trailing slash, and is selected" "1|$ADDED" \
    "$(ui_rows "$SES_PROJECTS_ID" | /usr/bin/awk -F'\t' -v p="$ADDED" '$1 == p' | /usr/bin/grep -c .)|$(selected)"
check "  its pane: no sessions, nothing to discard, nothing left out yet" \
    "1|newapp|no sessions yet|nothing to discard: no session yet|none|0|0" \
    "$(shown "$SES_DETAIL_ID")|$(ui_value "$SES_NAME_ID")|$(ui_value "$SES_COUNTS_ID")|$(ui_value "$SES_SPACE_ID")|$(ui_value "$SES_EXCLUSIONS_ID")|$(enabled "$SES_DISCARD_ID")|$(enabled "$SES_DISCARD_ALL_ID")"
omc_dialog_answer choose_folder "$ADDED"
omc_run AgentVM.main.session.project.add
check "  added again: still one card" "1" "$(ui_rows "$SES_PROJECTS_ID" | /usr/bin/awk -F'\t' -v p="$ADDED" '$1 == p' | /usr/bin/grep -c .)"
check "the folder button is on for a folder that exists" "1" "$(enabled "$SES_REVEAL_ID")"
omc_run AgentVM.main.session.reveal
check "  and opens the folder in Finder, not its parent" "$ADDED" "$(/bin/cat "$FAKE_OPEN_LOG")"
select_project "/Users/you/src/alpha"
check "a project folder this Mac does not have: the folder button is off" "0" "$(enabled "$SES_REVEAL_ID")"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.main.session.reveal
check "  and its handler opens nothing" "" "$(/bin/cat "$FAKE_OPEN_LOG")"
SLASHED="$OMCTEST_WORK/projects/new\\app"
/bin/mkdir -p "$SLASHED"
omc_dialog_answer choose_folder "$SLASHED"
omc_run AgentVM.main.session.project.add
check "a folder with a backslash in its path: selected, with its pane" "$SLASHED|no sessions yet" \
    "$(selected)|$(ui_value "$SES_COUNTS_ID")"
select_project "/Users/you/src/alpha"
select_project "$SLASHED"
check "  and selected again from its card" "$SLASHED" "$(selected)"
open_window
open_tab 2
check "a new window does not keep the projects added in the one before" "0" \
    "$(ui_rows "$SES_PROJECTS_ID" | /usr/bin/awk -F'\t' -v p="$ADDED" '$1 == p' | /usr/bin/grep -c .)"

section "removing a project from the list"
# pending  ->  the project the question of Remove named, kept for its confirmation.
pending() {
    "$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_session-remove_$OMC_ACTIONUI_WINDOW_UUID" get
}
remove_project() {
    alerts_reset
    select_project "$1"
    omc_run AgentVM.main.session.remove
}
discards() {
    fake_log | /usr/bin/grep '^session discard' | /usr/bin/paste -sd '|' -
}
# The free space cannot be read, so the toast after a discard is the plain one.
AGENTVM_APP_DF="$TEST_HELPERS/fake_df.sh"
FAKE_DF_FILE="$OMCTEST_WORK/df"
FAKE_DF_LOG="$OMCTEST_WORK/df.log"
: > "$FAKE_DF_FILE"
export AGENTVM_APP_DF FAKE_DF_FILE FAKE_DF_LOG
now_after 1
"$OMC_OMC_SUPPORT_PATH/pasteboard" agentvm_sessions_sort set date
open_window
write_projects
open_tab 2
check "nothing selected: Remove is off" "0" "$(enabled "$SES_REMOVE_ID")"
remove_project "$PROJECT"
check "  on for a selected project" "1" "$(enabled "$SES_REMOVE_ID")"
check "a project with an active session is not removed: an alert says why, and nothing is asked" \
    "myapp cannot be removed while a session is active|1||" \
    "$(ui_alert_title)|$(ui_alert_message | /usr/bin/grep -c 'Remove it once no session is active')|$(pending)|$(discards)"
remove_project "/Users/you/src/zeta"
check "a project with an ended session: asks, saying the sessions are discarded and the folder stays" \
    "Remove zeta from the list?|1 session of zeta is discarded and can no longer be undone. How much this frees is not known (not measured yet). The project folder is not touched." \
    "$(ui_alert_title)|$(ui_alert_message)"
check "  Remove goes on; nothing is discarded yet" "AgentVM.main.session.remove.confirmed|/Users/you/src/zeta|" \
    "$(ui_alert_action Remove)|$(pending)|$(discards)"
omc_run AgentVM.main.session.remove.confirmed
check "  Remove discards its session, and leaves the exclusions alone" "session discard 20261125-040000-aaaa --json||" \
    "$(discards)|$(pending)|$(/bin/cat "$FAKE_AGENTVM_DIR/exclusions-project" 2>/dev/null)"
check "  a toast says so" "1" "$(ui_calls 'omc_present_toast.The sessions are discarded..5')"
remove_project "/Users/you/src/old"
/usr/bin/jq '[.[] | if .project == "/Users/you/src/old" then .state = "active" | del(.endedAt) else . end]' "$FAKE_AGENTVM_DIR/session-list.json" > "$FAKE_AGENTVM_DIR/session-list.new" && /bin/mv "$FAKE_AGENTVM_DIR/session-list.new" "$FAKE_AGENTVM_DIR/session-list.json"
alerts_reset
omc_run AgentVM.main.session.remove.confirmed
check "a session that started between the question and Remove: refused then, and nothing is discarded" \
    "old cannot be removed while a session is active|session discard 20261125-040000-aaaa --json|" \
    "$(ui_alert_title)|$(discards)|$(pending)"
write_projects
omc_run AgentVM.main.session.remove.confirmed
check "  a second Remove without a question does nothing" "session discard 20261125-040000-aaaa --json" "$(discards)"
remove_project "/Users/you/src/alpha"
check "a project with only a saved list: the question says the list is cleared" \
    "Remove alpha from the list?|Its exclusions are cleared. The project folder is not touched." \
    "$(ui_alert_title)|$(ui_alert_message)"
omc_run AgentVM.main.session.remove.confirmed
check "  Remove clears the list, and its card goes, with the selection" \
    "/Users/you/src/alpha||session discard 20261125-040000-aaaa --json|0|" \
    "$(/bin/cat "$FAKE_AGENTVM_DIR/exclusions-project")|$(/bin/cat "$FAKE_AGENTVM_DIR/exclusions-set")|$(discards)|$(cards | /usr/bin/grep -c 'alpha=')|$(selected)"
check "  a toast says it is removed" "1" "$(ui_calls 'omc_present_toast.alpha is removed from the list..5')"
omc_dialog_answer choose_folder "$ADDED"
omc_run AgentVM.main.session.project.add
remove_project "$ADDED"
check "a project added with the plus button: the question says only that the folder stays" \
    "Remove newapp from the list?|The project folder is not touched." "$(ui_alert_title)|$(ui_alert_message)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.session.remove.confirmed
check "  Remove takes its card off, and runs no agent-vm but to read the list again" \
    "0||session list --json|session exclusions --json" \
    "$(ui_rows "$SES_PROJECTS_ID" | /usr/bin/awk -F'\t' -v p="$ADDED" '$1 == p' | /usr/bin/grep -c .)|$(selected)|$(fake_log | /usr/bin/paste -sd '|' -)"

section "a project whose sessions are all discarded"
KEPT="$OMCTEST_WORK/projects/keptapp"
/bin/mkdir -p "$KEPT"
# write_discarded [later start]  ->  keptapp (its folder is there) and gone (it is not) have only
# discarded sessions; with a start, keptapp has another one, started then.
write_discarded() {
    /usr/bin/jq --arg kept "$KEPT" --arg later "${1:-}" '. + [
        {"endedAt": "2026-11-20T10:00:00Z", "formatVersion": 1, "id": "20261120-050000-cccc", "project": $kept, "startSeconds": 1795150000, "state": "discarded"},
        {"endedAt": "2026-11-21T10:00:00Z", "formatVersion": 1, "id": "20261121-050000-dddd", "project": "/Users/you/src/gone", "startSeconds": 1795236000, "state": "discarded"}]
        + (if $later == "" then [] else [{"endedAt": "2026-11-26T10:00:00Z", "formatVersion": 1, "id": "20261126-050000-eeee", "project": $kept, "startSeconds": ($later | tonumber), "state": "discarded"}] end)' \
        "$FIXTURES_AGENTVM/session-list.json" > "$FAKE_AGENTVM_DIR/session-list.json"
}
now_after 1
open_window
write_discarded
open_tab 2
check "its folder is there: it keeps its card, with when its last session ended; one whose folder is gone has none" \
    "1|Nov 20 10:00|all sessions discarded|0" \
    "$(ui_rows "$SES_PROJECTS_ID" | /usr/bin/awk -F'\t' -v p="$KEPT" '$1 == p' | /usr/bin/grep -c .)|$(ui_rows "$SES_PROJECTS_ID" | /usr/bin/awk -F'\t' -v p="$KEPT" '$1 == p { print $5 "|" $3 }')|$(cards | /usr/bin/grep -c 'gone=')"
remove_project "$KEPT"
check "  its pane: nothing to discard" "nothing to discard: its sessions are discarded" "$(ui_value "$SES_SPACE_ID")"
check "  Remove asks, with nothing to discard" "Remove keptapp from the list?|The project folder is not touched." \
    "$(ui_alert_title)|$(ui_alert_message)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.session.remove.confirmed
check "  Remove: its card goes, for good, kept in the app's list with the time; nothing is discarded" \
    "0|$AGENTVM_APP_NOW${TAB}$KEPT|" \
    "$(ui_rows "$SES_PROJECTS_ID" | /usr/bin/awk -F'\t' -v p="$KEPT" '$1 == p' | /usr/bin/grep -c .)|$(/usr/bin/grep "keptapp$" "$HOME/Library/Application Support/AgentVM/sessions-removed")|$(discards)"
open_window
write_discarded
open_tab 2
check "  a new window does not show it either" "0" "$(ui_rows "$SES_PROJECTS_ID" | /usr/bin/awk -F'\t' -v p="$KEPT" '$1 == p' | /usr/bin/grep -c .)"
omc_dialog_answer choose_folder "$KEPT"
omc_run AgentVM.main.session.project.add
open_window
write_discarded
open_tab 2
check "  added again with the plus button: no longer kept as removed, so a new window shows it" "1|" \
    "$(ui_rows "$SES_PROJECTS_ID" | /usr/bin/awk -F'\t' -v p="$KEPT" '$1 == p' | /usr/bin/grep -c .)|$(/usr/bin/grep "keptapp$" "$HOME/Library/Application Support/AgentVM/sessions-removed")"
remove_project "$KEPT"
omc_run AgentVM.main.session.remove.confirmed
write_discarded $((AGENTVM_APP_NOW + 60))
omc_run AgentVM.main.session.measure
check "  a session started after Remove brings it back" "1" "$(ui_rows "$SES_PROJECTS_ID" | /usr/bin/awk -F'\t' -v p="$KEPT" '$1 == p' | /usr/bin/grep -c .)"
"$OMC_OMC_SUPPORT_PATH/pasteboard" agentvm_sessions_sort set ""

omctest_end
