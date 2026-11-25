#!/bin/sh
# Tests/67-session-discard.test.sh - discarding sessions from the Sessions tab: Discard Ticked...
# and Discard All Ended... (on only when there is something to discard), the question (how many,
# what it frees, that undo ends), the discard itself (one call with the ids, the free space before
# and after, the ticks and the window's measurement without them), the Time Machine sentence when
# the free space rose much less than expected, a refusal, and Discard Older Than... with its ages.
#
# agent-vm is the fake, as in 34-sessions.test.sh; df is fake_df.sh.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.sessions.sh"
[ -n "$SES_DISCARD_ID" ] && [ -n "$SES_DISCARD_ALL_ID" ] && [ -n "$SES_OLDER_ID" ] && [ -n "$SES_TABLE_ID" ] || {
    printf '67-session-discard: no view ids imported from the libraries\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
AGENTVM_APP_DF="$TEST_HELPERS/fake_df.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
FAKE_DF_FILE="$OMCTEST_WORK/df"
FAKE_DF_LOG="$OMCTEST_WORK/df.log"
TZ=UTC
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN AGENTVM_APP_DF FAKE_SLEEP_LOG FAKE_OPEN_LOG FAKE_DF_FILE FAKE_DF_LOG TZ
PROJECT="/Users/you/src/myapp"
MEASURED="$(/usr/bin/jq -r '.sessions.measuredAt' "$FIXTURES_AGENTVM/status-sessions.json")"
MEASURED_SECONDS="$(/bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$MEASURED" +%s)"
AGENTVM_APP_NOW=$((MEASURED_SECONDS + 3600))
export AGENTVM_APP_NOW
ROWS="$(lib agentvm_session_rows < "$FIXTURES_AGENTVM/session-list.json")"
ENDED1="$(printf '%s\n' "$ROWS" | /usr/bin/awk -F'\t' 'NR == 1 { print $1 }')"
ENDED2="$(printf '%s\n' "$ROWS" | /usr/bin/awk -F'\t' 'NR == 2 { print $1 }')"

# open_project  ->  a fresh window, the Sessions tab opened, the project selected, nothing ticked.
open_project() {
    omc_run AgentVM.main.close
    fake_reset
    /usr/bin/jq --slurpfile s "$FIXTURES_AGENTVM/status-sessions.json" '.sessions = $s[0].sessions' \
        "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
    alerts_reset
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
    omc_trigger "$MAIN_STATUS_ID" "" 2
    omc_run AgentVM.main.tab
    omc_table_cell "$SES_PROJECTS_ID" 1 "$PROJECT"
    omc_trigger "$SES_PROJECTS_ID"
    omc_run AgentVM.main.session.project.selected
}

tick() {
    omc_trigger "$SES_TABLE_ID" 0 "$1"
    omc_run AgentVM.main.session.tick
}

on() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

discards() {
    fake_log | /usr/bin/grep '^session discard' | /usr/bin/paste -sd '|' -
}

section "the buttons"
open_project
check "nothing ticked: Discard Ticked... off; the project has ended sessions: Discard All Ended... and Discard Older Than... on" "0|1|1" \
    "$(on "$SES_DISCARD_ID")|$(on "$SES_DISCARD_ALL_ID")|$(on "$SES_OLDER_ID")"
tick 0
check "one ticked: Discard Ticked... on" "1" "$(on "$SES_DISCARD_ID")"

section "Discard Ticked...: one ended session alone"
omc_run AgentVM.main.session.discard
check "asks, naming how many" "Discard 1 session?" "$(ui_alert_title)"
check "  and says it frees nothing now, and that undo ends" \
    "1 session of myapp: their snapshots, and what an undo kept, are deleted; this frees nothing now: what they hold is held by other sessions or by the project too. Undo is no longer possible for them; their records and reports stay in agent-vm session list." \
    "$(ui_alert_message)"
check "  Discard goes on, and nothing is discarded yet" "AgentVM.main.session.discard.confirmed|" "$(ui_alert_action Discard)|$(discards)"

section "Discard All Ended...: both, which free 1 MB together"
open_project
printf '20000000\n21024000\n' > "$FAKE_DF_FILE"
: > "$FAKE_DF_LOG"
omc_run AgentVM.main.session.discard.all
check "asks about the two ended sessions, which free about 1 MB" "Discard 2 sessions?|1" \
    "$(ui_alert_title)|$(ui_alert_message | /usr/bin/grep -c 'this frees about 1 MB once macOS')"
omc_run AgentVM.main.session.discard.confirmed
check "one call with both ids" "session discard $ENDED1 $ENDED2 --json" "$(discards)"
check "  the free space read before and after, on the store's volume" "2" "$(/usr/bin/awk 'END { print NR }' "$FAKE_DF_LOG")"
check "  a toast says what the volume gained" "1" \
    "$(ui_calls 'omc_present_toast.The sessions are discarded. Free space was 20.5 GB, now 21.5 GB..5')"
# The fake still lists both (it changes no list): ticked again, they free nothing, since the
# window's measurement no longer holds them.
tick 0
tick 1
check "  the window's measurement no longer has them" "1" "$(ui_value "$SES_PICKED_ID" | /usr/bin/grep -c 'frees nothing now')"
check "  nothing measured again for it; the list and status are read again" "1|1" \
    "$(fake_log | /usr/bin/grep -c '^session usage')|$(fake_log | /usr/bin/sed -n '/^session discard/,$p' | /usr/bin/grep -c '^session list --json$')"
check "  the question's ids are forgotten: a second Discard does nothing" "1" \
    "$(omc_run AgentVM.main.session.discard.confirmed; discards | /usr/bin/tr '|' '\n' | /usr/bin/grep -c .)"

section "when the free space could not be read before"
open_project
printf '21024000\n' > "$FAKE_DF_FILE"
"$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_session-discard_$OMC_ACTIONUI_WINDOW_UUID" set "$ENDED1"
omc_run AgentVM.main.session.discard.confirmed
check "the toast says only that they are discarded" "1|0" \
    "$(ui_calls 'omc_present_toast.The sessions are discarded..5')|$(ui_calls 'omc_present_toast.The sessions are discarded. The sessions are discarded..5')"

section "when the free space rose much less than expected"
open_project
printf '%s\n' '{"formatVersion": 1, "held": [{"bytes": 30000000000, "sessions": ["'"$ENDED1"'", "'"$ENDED2"'"]}], "measuredAt": "'"$MEASURED"'", "notes": [], "projects": [], "sessions": [], "totals": {"bytes": 0, "freedIfAllDiscardedBytes": 30000000000, "sessions": 2}}' > "$FAKE_AGENTVM_DIR/session-usage.json"
omc_trigger "$SES_MEASURE_ID"
omc_run AgentVM.main.session.measure
alerts_reset
printf '20000000\n20001000\n' > "$FAKE_DF_FILE"
omc_run AgentVM.main.session.discard.all
check "the question says about 30 GB" "1" "$(ui_alert_message | /usr/bin/grep -c 'this frees about 30.0 GB')"
alerts_reset
omc_run AgentVM.main.session.discard.confirmed
check "an alert explains: local Time Machine snapshots keep deleted data" "The sessions are discarded|1" \
    "$(ui_alert_title)|$(ui_alert_message | /usr/bin/grep -c 'local Time Machine snapshots keep deleted data for up to a day')"

section "a refusal"
open_project
alerts_reset
"$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_session-discard_$OMC_ACTIONUI_WINDOW_UUID" set "20990101-000000-abcd"
omc_run AgentVM.main.session.discard.confirmed
check "an id agent-vm does not have: the alert says why" "Not every session was discarded|1" \
    "$(ui_alert_title)|$(ui_alert_message | /usr/bin/grep -c 'no session 20990101-000000-abcd')"
tick 0
tick 1
alerts_reset
"$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_session-discard_$OMC_ACTIONUI_WINDOW_UUID" set "$ENDED1 $ENDED2 20990101-000000-abcd"
omc_run AgentVM.main.session.discard.confirmed
check "  refused with sessions it has: they keep their ticks and their part of the measurement" "Not every session was discarded|1" \
    "$(ui_alert_title)|$(ui_value "$SES_PICKED_ID" | /usr/bin/grep -c '2 sessions ticked: about 1 MB to free')"
alerts_reset
"$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_session-discard_$OMC_ACTIONUI_WINDOW_UUID" set "--older-than 0"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.session.discard.confirmed
check "what is not a session id never reaches agent-vm" "" "$(discards)"
ACTIVE="$(printf '%s\n' "$ROWS" | /usr/bin/awk -F'\t' 'NR == 3 { print $1 }')"
: > "$FAKE_AGENTVM_DIR/log"
"$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_session-discard_$OMC_ACTIONUI_WINDOW_UUID" set "$ACTIVE $ENDED1"
omc_run AgentVM.main.session.discard.confirmed
check "an active session is never sent to agent-vm, whatever named it" "session discard $ENDED1 --json" "$(discards)"

section "Discard Older Than..."
open_project
alerts_reset
AGENTVM_APP_NOW=$((MEASURED_SECONDS + 10 * 86400))
export AGENTVM_APP_NOW
omc_run AgentVM.main.session.older
check "ten days on: both ended sessions ended 7 days ago or earlier, none 30" "Discard the sessions that ended long ago?|1|1" \
    "$(ui_alert_title)|$(ui_alert_message | /usr/bin/grep -c 'Sessions ended 7 days ago or earlier: 2 sessions, about 1 MB to free; ended 30 days ago or earlier: 0 sessions. Their')|$(ui_alert_message | /usr/bin/grep -c 'Active sessions are never discarded.')"
check "  a button for 7 days only" "AgentVM.main.session.older.7|" \
    "$(ui_alert_action 'Older Than 7 Days')|$(ui_alert_action 'Older Than 30 Days')"
printf '20000000\n21024000\n' > "$FAKE_DF_FILE"
omc_run AgentVM.main.session.older.7
check "  Older Than 7 Days discards both, never the active one" "session discard $ENDED1 $ENDED2 --json" "$(discards)"
omc_run AgentVM.main.session.older.7
check "  pressed again: the question's ids are forgotten, nothing more is discarded" "1" "$(discards | /usr/bin/tr '|' '\n' | /usr/bin/grep -c .)"
open_project
alerts_reset
AGENTVM_APP_NOW=$((MEASURED_SECONDS + 3600))
export AGENTVM_APP_NOW
omc_run AgentVM.main.session.older
check "an hour on: no session ended that long ago, so nothing to choose" "No session ended that long ago|" \
    "$(ui_alert_title)|$(ui_alert_action 'Older Than 7 Days')"

omctest_end
