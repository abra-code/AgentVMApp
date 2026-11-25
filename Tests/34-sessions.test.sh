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
    "1|myapp|$PROJECT|about 1 MB if all its ended and undone sessions are discarded" \
    "$(shown "$SES_DETAIL_ID")|$(ui_value "$SES_NAME_ID")|$(ui_value "$SES_PATH_ID")|$(ui_value "$SES_SPACE_ID")"
rows="$(ui_rows "$SES_TABLE_ID")"
check "a row per session, none ticked: two ended, one active" "false ended|false ended|false active" \
    "$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' '{ print $1, $3 }' | /usr/bin/paste -sd '|' -)"
check "  each holds nothing of its own, and the ended ones 1 MB with one other" "0 bytes${TAB}1 MB with 1 other|0 bytes${TAB}1 MB with 1 other|0 bytes${TAB}none" \
    "$(printf '%s\n' "$rows" | col 5-6 | /usr/bin/paste -sd '|' -)"
check "  the active session's checkbox is disabled; the hidden column has the id" "false|false|true|$ACTIVE" \
    "$(printf '%s\n' "$rows" | col 9 | /usr/bin/paste -sd '|' -)|$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' 'NR == 3 { print $8 }')"
check "  nothing ticked yet" "Tick the sessions to discard; what they free together is shown here." "$(ui_value "$SES_PICKED_ID")"

section "ticking sessions"
tick 0
check "one ended session alone frees nothing: the other holds the same data" \
    "1 session ticked: discarding them frees nothing now; what they hold is held by other sessions or by the project too." \
    "$(ui_value "$SES_PICKED_ID")"
check "  its row is ticked" "true" "$(ui_rows "$SES_TABLE_ID" | /usr/bin/awk -F'\t' 'NR == 1 { print $1 }')"
tick 1
check "both together free 1 MB" "2 sessions ticked: about 1 MB to free." "$(ui_value "$SES_PICKED_ID")"
check "  and no agent-vm ran for it" "1" "$(measured_count)"
tick 2
check "the active one cannot be ticked" "false|2 sessions ticked: about 1 MB to free." \
    "$(ui_rows "$SES_TABLE_ID" | /usr/bin/awk -F'\t' 'NR == 3 { print $1 }')|$(ui_value "$SES_PICKED_ID")"
tick 0
check "unticking one leaves the other" "true|1 session ticked: discarding them frees nothing now; what they hold is held by other sessions or by the project too." \
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
check "31.7 GB to free: the banner says so" "1|{\"maxWidth\":\"infinity\"}|agent-vm sessions hold about 31.7 GB that only their undo needs; discarding them frees it." \
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

omctest_end
