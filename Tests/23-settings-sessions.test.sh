#!/bin/sh
# Tests/23-settings-sessions.test.sh - Settings: the Sessions group (what is kept and what can be
# freed, Show, the store's expiry with its question), the free disk space line, and the macOS
# restore images row (Show in Finder, Remove... with its question).
#
# agent-vm is the fake: status is status-variety.json with the `sessions` of status-sessions.json
# and a restore image of 25.6 GB in a folder made here; `session list` is the fixture (two ended
# sessions and an active one of ~/src/myapp); `image fetch-ipsw --list` is ipsw-list.json.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.sessions.sh"
[ -n "$SES_KEPT_ID" ] && [ -n "$SES_EXPIRY_ID" ] && [ -n "$SES_RESTORE_ID" ] && [ -n "$MAIN_DISK_ID" ] || {
    printf '23-settings-sessions: no view ids imported from the libraries\n' >&2
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
MEASURED="$(/usr/bin/jq -r '.sessions.measuredAt' "$FIXTURES_AGENTVM/status-sessions.json")"
MEASURED_SECONDS="$(/bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$MEASURED" +%s)"
IPSW_FOLDER="$OMCTEST_WORK/store/Cache/ipsw"
/bin/mkdir -p "$IPSW_FOLDER"
RESTORE="$(/usr/bin/jq -r '.[0].name' "$FIXTURES_AGENTVM/ipsw-list.json")"

# status_with <freed bytes or null> <discardAfterDays> <restore count>  ->  the fake's status.
status_with() {
    /usr/bin/jq --slurpfile s "$FIXTURES_AGENTVM/status-sessions.json" --argjson freed "$1" --argjson days "$2" \
        --argjson count "$3" --arg folder "$IPSW_FOLDER" \
        '.sessions = ($s[0].sessions | .freedIfAllDiscardedBytes = $freed | .discardAfterDays = $days)
         | .restoreImages = {count: $count, bytes: ($count * 25595670528), partialBytes: 0, directory: $folder}' \
        "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

open_window() {
    omc_run AgentVM.main.close
    alerts_reset
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}

on() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

pick() {
    omc_control "$SES_EXPIRY_ID" "$1"
    omc_trigger "$SES_EXPIRY_ID"
    omc_run AgentVM.main.session.expiry
}

section "the Sessions group and the free disk space"
fake_reset
status_with 31700000000 0 1
AGENTVM_APP_NOW=$((MEASURED_SECONDS + 3600))
export AGENTVM_APP_NOW
open_window
check "kept now: three sessions, 31.7 GB to free" "3 sessions, about 31.7 GB to free" "$(ui_value "$SES_KEPT_ID")"
check "  the expiry picker at Never, on, and what it means" "0|1|kept until discarded" \
    "$(ui_value "$SES_EXPIRY_ID")|$(on "$SES_EXPIRY_ID")|$(ui_value "$SES_EXPIRY_TEXT_ID")"
check "the free disk space says what sessions hold that can be freed" "1" \
    "$(ui_value "$MAIN_DISK_ID" | /usr/bin/grep -c '; sessions hold about 31.7 GB you can free$')"
fake_reset
status_with 1048576 0 1
open_window
check "  not under 1 GB" "0|3 sessions, about 1 MB to free" \
    "$(ui_value "$MAIN_DISK_ID" | /usr/bin/grep -c 'sessions hold')|$(ui_value "$SES_KEPT_ID")"
fake_reset
status_with null 30 1
open_window
check "never measured: said so; an expiry of 30 days shown" "3 sessions, not measured yet|30|30 days after a session ends" \
    "$(ui_value "$SES_KEPT_ID")|$(ui_value "$SES_EXPIRY_ID")|$(ui_value "$SES_EXPIRY_TEXT_ID")"

section "Show"
omc_trigger "$SES_SHOW_ID"
omc_run AgentVM.main.session.show
check "opens the Sessions tab and reads it (measuring: never measured here)" "2|1" \
    "$(ui_value "$MAIN_STATUS_ID")|$(/bin/cat "$FAKE_AGENTVM_DIR/session-usage-count" 2>/dev/null)"

section "the expiry picker"
fake_reset
status_with 1048576 0 1
AGENTVM_APP_NOW=$((MEASURED_SECONDS + 20 * 86400))
export AGENTVM_APP_NOW
open_window
pick 14
check "14 days, with two sessions ended 20 days ago: asks, saying what goes (no size: this window never measured)" "Discard ended sessions 14 days after they end?|1|" \
    "$(ui_alert_title)|$(ui_alert_message | /usr/bin/grep -c 'At the end of the next session, agent-vm discards 2 sessions older than 14 days, then each session 14 days after it ends')|$(/bin/cat "$FAKE_AGENTVM_DIR/discard-after" 2>/dev/null)"
check "  Set confirms, Cancel puts the picker back" "AgentVM.main.session.expiry.confirmed|AgentVM.main.session.expiry.canceled" \
    "$(ui_alert_action Set)|$(ui_alert_action Cancel)"
omc_run AgentVM.main.session.expiry.confirmed
check "  Set: the store's expiry is 14 days" "14|store sessions --discard-after 14 --json" \
    "$(/bin/cat "$FAKE_AGENTVM_DIR/discard-after")|$(fake_log | /usr/bin/grep '^store sessions' | /usr/bin/tail -1)"
fake_reset
status_with 1048576 0 1
UNDONE_AT="$(/bin/date -j -u -r "$((MEASURED_SECONDS + 10 * 86400))" '+%Y-%m-%dT%H:%M:%SZ')"
/usr/bin/jq --arg at "$UNDONE_AT" '.[0].state = "undone" | .[0].undoneAt = $at' \
    "$FIXTURES_AGENTVM/session-list.json" > "$FAKE_AGENTVM_DIR/session-list.json"
open_window
alerts_reset
pick 14
check "  an undone session counts from its undo, as agent-vm's expiry does: one of the two goes" "1" \
    "$(ui_alert_message | /usr/bin/grep -c 'agent-vm discards 1 session older than 14 days')"
fake_reset
status_with 1048576 0 1
open_window
alerts_reset
printf 'no store\n' > "$FAKE_AGENTVM_DIR/fail-session-list"
pick 14
check "  the sessions not listed: nothing set, and the alert says so" "The expiry was not changed|" \
    "$(ui_alert_title)|$(/bin/cat "$FAKE_AGENTVM_DIR/discard-after" 2>/dev/null)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-session-list"
fake_reset
status_with 1048576 14 1
open_window
alerts_reset
pick 0
check "Never is set at once, with no question" "|0" "$(ui_alert_title)|$(/bin/cat "$FAKE_AGENTVM_DIR/discard-after")"
fake_reset
status_with 1048576 0 1
AGENTVM_APP_NOW=$((MEASURED_SECONDS + 3600))
export AGENTVM_APP_NOW
open_window
alerts_reset
pick 60
check "60 days when no session ended that long ago: set at once" "|60" "$(ui_alert_title)|$(/bin/cat "$FAKE_AGENTVM_DIR/discard-after")"
alerts_reset
omc_control "$SES_EXPIRY_ID" "7"
omc_trigger "$SES_EXPIRY_ID"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.session.expiry
check "a value the picker does not offer is ignored" "" "$(fake_log | /usr/bin/grep '^store sessions')"

section "macOS restore images"
fake_reset
status_with 1048576 0 1
open_window
check "one of 25.6 GB; Show in Finder and Remove... on" "1, 25.6 GB|1|1" \
    "$(ui_value "$SES_RESTORE_ID")|$(on "$SES_RESTORE_SHOW_ID")|$(on "$SES_RESTORE_REMOVE_ID")"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.main.restore.show
check "Show in Finder opens their folder" "$IPSW_FOLDER" "$(/bin/cat "$FAKE_OPEN_LOG")"
alerts_reset
omc_run AgentVM.main.restore.remove
check "Remove... asks, naming them and the download a new image then needs" "1|1" \
    "$(ui_alert_title | /usr/bin/grep -c '^Remove [0-9]* restore image')|$(ui_alert_message | /usr/bin/grep -c "^$RESTORE.*a new macOS image needs another download (about 27 GB)")"
omc_run AgentVM.main.restore.remove.confirmed
check "  Remove: each one removed through agent-vm" "1" "$(fake_log | /usr/bin/grep -c "^image fetch-ipsw --remove $RESTORE --json$")"
fake_reset
status_with 1048576 0 0
open_window
check "none: Remove... off" "none|0" "$(ui_value "$SES_RESTORE_ID")|$(on "$SES_RESTORE_REMOVE_ID")"

omctest_end
