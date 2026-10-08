#!/bin/sh
# Tests/22-kept-logs.test.sh - the Logs of deleted boxes part of the main window's Settings: what
# agent-vm keeps now (how many deleted boxes' logs, and their size), Show in Finder, Remove All...
# with its question, and for how long a deleted box's logs are kept: the picker at the store's
# time, the question before a change that removes logs, and what reaches agent-vm.
#
# agent-vm is the fake: status from a jq edit of fixtures/agentvm/status-variety.json. The folder
# of the kept logs is made here, since the fixtures' is not on this Mac.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_KEPT_NOW_ID" ] && [ -n "$MAIN_KEPT_SHOW_ID" ] && [ -n "$MAIN_KEPT_REMOVE_ID" ] && [ -n "$MAIN_KEPT_HOLD_ID" ] && [ -n "$MAIN_KEPT_HOLD_TEXT_ID" ] || {
    printf '22-kept-logs: no view ids imported from the library\n' >&2
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
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
UUID="$OMC_ACTIONUI_WINDOW_UUID"
KEPT_FOLDER="$OMCTEST_WORK/the store/Logs"

# kept <count> <bytes> <days>  ->  the fake answers status with that said of the logs of deleted
# boxes, in $KEPT_FOLDER; "nothing" for an agent-vm that says nothing of them.
kept() {
    if [ "$1" = "nothing" ]; then
        /usr/bin/jq 'del(.keptLogs)' "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
        return 0
    fi
    /usr/bin/jq --argjson count "$1" --argjson bytes "$2" --argjson days "$3" --arg folder "$KEPT_FOLDER" \
        '.keptLogs = {count: $count, bytes: $bytes, holdDays: $days, directory: $folder}' \
        "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

open_window() {
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

# part  ->  the part as painted: what is kept now, Show in Finder and Remove All... on or off, the
# picker's time and whether it is on, and the line beside it.
part() {
    printf '%s|%s%s|%s %s|%s\n' "$(ui_value "$MAIN_KEPT_NOW_ID")" "$(enabled "$MAIN_KEPT_SHOW_ID")" "$(enabled "$MAIN_KEPT_REMOVE_ID")" \
        "$(ui_value "$MAIN_KEPT_HOLD_ID")" "$(enabled "$MAIN_KEPT_HOLD_ID")" "$(ui_value "$MAIN_KEPT_HOLD_TEXT_ID")"
}

# pick <days>  ->  that segment of the picker clicked.
pick() {
    omc_control "$MAIN_KEPT_HOLD_ID" "$1"
    omc_trigger "$MAIN_KEPT_HOLD_ID"
    omc_run AgentVM.main.logs.hold
}

# asked_agentvm  ->  what the fake was asked that changes the store.
asked_agentvm() {
    fake_log | /usr/bin/grep '^store ' | /usr/bin/paste -sd '|' -
}

pending() {
    "$PB" "agentvm_logs_${1}_$UUID" get
}

# clear_alerts  ->  no pending alert on the window (it lives in the virtual window, which ui_reset
# wipes), and none recorded. The handlers that run next repaint what the checks read.
clear_alerts() {
    alerts_reset
    ui_reset
}

fake_reset
/bin/mkdir -p "$KEPT_FOLDER"

# -----------------------------------------------------------------------------------------------
section "the library: removing the kept logs, and the time they are kept for"
check "remove all: what reaches agent-vm, and how many deleted boxes' logs it says went" "0|3|store logs --remove-older-than 0 --json" \
    "$(printf '3\n' > "$FAKE_AGENTVM_DIR/kept-logs-count"; removed="$(with_fake agentvm_store_logs_remove_all)"; echo "$?|$removed|$(fake_log | /usr/bin/tail -1)")"
/bin/rm -f "$FAKE_AGENTVM_DIR/kept-logs-count"
check "  none kept: none went"       "0|0" "$(removed="$(with_fake agentvm_store_logs_remove_all)"; echo "$?|$removed")"
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-store"
check "  a refusal is agent-vm's status, and its words" "1||the store is locked" \
    "$(removed="$(with_fake agentvm_store_logs_remove_all)"; echo "$?|$removed|$(lib agentvm_last_error 1)")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-store"
: > "$FAKE_AGENTVM_DIR/log"
with_fake agentvm_store_hold_days 7
check "a new time: what reaches agent-vm" "0|store logs --hold-days 7 --json|7" "$?|$(fake_log)|$(/bin/cat "$FAKE_AGENTVM_DIR/hold-days")"
with_fake agentvm_store_hold_days 0
check "  never is 0 days"            "0|0" "$?|$(/bin/cat "$FAKE_AGENTVM_DIR/hold-days")"
: > "$FAKE_AGENTVM_DIR/log"
refused=""
for days in "" -1 "7 --remove-older-than 0" 7.5 seven 12345; do
    with_fake agentvm_store_hold_days "$days" 2>/dev/null
    refused="$refused$?"
done
check "what is not a number of days, of four digits at most, never reaches agent-vm" "222222|" "$refused|$(fake_log)"
check "  and the refusal says so"    "\"seven\" is not a number of days." "$(with_fake agentvm_store_hold_days seven; lib agentvm_last_error 2)"

section "sizes, as the part writes them"
sizes() {
    ( . "$APP_SCRIPTS/lib.agentvm.main.sh" >/dev/null 2>&1
      for bytes in "$@"; do printf '%s|' "$(main_kept_size_text "$bytes")"; done )
}
check "bytes, KB, MB and GB, in decimal units; nothing for what is not a number" "1 byte|512 bytes|35 KB|3.2 MB|1.5 GB|||" "$(sizes 1 512 35200 3200000 1500000000 "" lots)"

# -----------------------------------------------------------------------------------------------
section "Settings: what is kept, and for how long"
kept 14 3200000 30
open_window
check "fourteen deleted boxes' logs and their size; both buttons on; the picker at 30 days" \
    "14 deleted boxes, 3.2 MB|11|30 1|after a box is deleted or recreated" "$(part)"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.main.box.logs.kept
check "Show in Finder opens their folder" "$KEPT_FOLDER" "$(/bin/cat "$FAKE_OPEN_LOG")"
kept 1 512 7
omc_run AgentVM.main.activated
check "one deleted box, a week" "1 deleted box, 512 bytes|11|7 1|after a box is deleted or recreated" "$(part)"
kept 0 0 90
omc_run AgentVM.main.activated
check "none kept: nothing to show or remove" "none|00|90 1|after a box is deleted or recreated" "$(part)"
kept 2 9000 0
omc_run AgentVM.main.activated
check "a store that keeps none, with logs from before: Never, and what that means" "2 deleted boxes, 9 KB|11|0 1|A box deleted from now on leaves no logs." "$(part)"
kept 3 4096 14
omc_run AgentVM.main.activated
check "a time that is none of the picker's: the line says it, and where it was set" \
    "3 deleted boxes, 4 KB|11|14 1|Now 14 days, set with agent-vm store logs --hold-days." "$(part)"
kept nothing
omc_run AgentVM.main.activated
check "an agent-vm that says nothing of kept logs: none is kept as far as it says, and the time is not known and cannot be changed" "none|00| 0|-" "$(part)"
check "the picker's segments are the times offered, with Never as 0 days" "7 days=7 30 days=30 90 days=90 Never=0" \
    "$(/usr/bin/jq -r --argjson id "$MAIN_KEPT_HOLD_ID" '[.. | objects | select(.id? == $id) | .properties.options[] | "\(.title)=\(.tag)"] | join(" ")' "$APP_RESOURCES/Base.lproj/AgentVM.json")"
check "  and they are the ones the handler takes" "7 30 90 0" "$(/usr/bin/sed -n 's/^MAIN_KEPT_HOLD_CHOICES="\(.*\)"$/\1/p' "$APP_SCRIPTS/lib.agentvm.main.sh")"

# -----------------------------------------------------------------------------------------------
section "Remove All...: the question"
kept 14 3200000 30
omc_run AgentVM.main.activated
clear_alerts
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.logs.remove
check_status "exits cleanly" 0
check "reads status again first, and changes nothing" "status --json|" "$(fake_log | /usr/bin/paste -sd '|' -)|$(asked_agentvm)"
check "asks, naming how many"        "Remove the logs of 14 deleted boxes?" "$(ui_alert_title)"
check "  what goes, and what does not" \
    "What they ran and what they contacted is deleted from this Mac (3.2 MB). The logs of boxes that exist are not touched. This cannot be undone." "$(ui_alert_message)"
check "  Remove All confirms, and the question is kept as asked" "AgentVM.main.logs.remove.confirmed|1" "$(ui_alert_action "Remove All")|$(pending remove)"

section "Remove All: done, refused, and nothing to ask about"
printf '14\n' > "$FAKE_AGENTVM_DIR/kept-logs-count"
kept 0 0 30
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.logs.remove.confirmed
check "agent-vm removes them all, and status is read again" "store logs --remove-older-than 0 --json|status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "  a toast says how many went" "1" "$(ui_calls 'omc_present_toast.The logs of 14 deleted boxes are removed\..5')"
check "  and the part follows"       "none|00" "$(part | /usr/bin/cut -d'|' -f1-2)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.logs.remove.confirmed
check "a second confirmation removes nothing" "" "$(asked_agentvm)"
clear_alerts
omc_run AgentVM.main.logs.remove
check "with none kept, Remove All... asks nothing" "|" "$(ui_alert_title)|$(pending remove)"
kept 2 9000 30
omc_run AgentVM.main.logs.remove
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-store"
clear_alerts
toasts="$(ui_calls omc_present_toast)"
omc_run AgentVM.main.logs.remove.confirmed
check "agent-vm refuses: its reason is shown, and no toast" "The logs were not removed|the store is locked|$toasts" \
    "$(ui_alert_title)|$(ui_alert_message)|$(ui_calls omc_present_toast)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-store"
printf 'no status today\n' > "$FAKE_AGENTVM_DIR/fail-status"
clear_alerts
omc_run AgentVM.main.logs.remove
check "status fails: nothing is asked about a count that may be old" "|" "$(ui_alert_title)|$(pending remove)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"

# -----------------------------------------------------------------------------------------------
section "the time: a change that removes nothing is made at once"
kept 0 0 30
omc_run AgentVM.main.activated
clear_alerts
: > "$FAKE_AGENTVM_DIR/log"
pick 7
check "no logs are kept: a shorter time is not asked about" "store logs --hold-days 7 --json||" "$(asked_agentvm)|$(ui_alert_title)|$(pending hold)"
kept 5 100000 30
omc_run AgentVM.main.activated
: > "$FAKE_AGENTVM_DIR/log"
pick 90
check "logs are kept, and the time grows: not asked about either" "store logs --hold-days 90 --json|" "$(asked_agentvm)|$(ui_alert_title)"
: > "$FAKE_AGENTVM_DIR/log"
pick 30
check "the store's own time, picked again, changes nothing" "" "$(asked_agentvm)"
kept 5 100000 0
omc_run AgentVM.main.activated
: > "$FAKE_AGENTVM_DIR/log"
pick 7
check "from Never to a time: nothing is removed by it, so it is not asked about" "store logs --hold-days 7 --json|" "$(asked_agentvm)|$(ui_alert_title)"
: > "$FAKE_AGENTVM_DIR/log"
for stray in 14 "" "7 --remove-older-than 0" -1 x; do
    pick "$stray"
done
check "a value that is none of the picker's times reaches agent-vm as nothing" "" "$(fake_log)"

section "the time: a change that removes logs is asked about"
kept 5 100000 30
omc_run AgentVM.main.activated
clear_alerts
: > "$FAKE_AGENTVM_DIR/log"
pick 7
check "a shorter time, with logs kept: nothing is changed yet" "|7" "$(asked_agentvm)|$(pending hold)"
check "  the question says what goes, and when" \
    "Keep the logs of deleted boxes for 7 days?|The logs of 5 deleted boxes are kept now: agent-vm removes the ones of boxes deleted more than 7 days ago the next time it tidies the store." \
    "$(ui_alert_title)|$(ui_alert_message)"
check "  Change confirms, and Cancel puts the picker back" "AgentVM.main.logs.hold.confirmed|AgentVM.main.logs.hold.canceled" \
    "$(ui_alert_action Change)|$(ui_alert_action Cancel)"
omc_run AgentVM.main.logs.hold.canceled
check "Cancel: nothing reaches agent-vm, the change is forgotten, and the picker shows the store's time again" "||30" \
    "$(asked_agentvm)|$(pending hold)|$(ui_value "$MAIN_KEPT_HOLD_ID")"
omc_run AgentVM.main.logs.hold.confirmed
check "  a confirmation after it changes nothing" "" "$(asked_agentvm)"
clear_alerts
pick 0
check "Never, with logs kept: the question says they all go" \
    "Keep no logs of deleted boxes?|The logs of 5 deleted boxes are kept now: agent-vm removes them the next time it tidies the store, and a box deleted from now on leaves none.|0" \
    "$(ui_alert_title)|$(ui_alert_message)|$(pending hold)"
# The picker moves on while the question is open: the time asked about is the one applied.
omc_control "$MAIN_KEPT_HOLD_ID" "90"
kept 5 100000 0
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.logs.hold.confirmed
check "Change: the time asked about reaches agent-vm, whatever the picker shows by then, and status is read again" \
    "store logs --hold-days 0 --json|status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "  the part follows what agent-vm then says" "0 1|A box deleted from now on leaves no logs." "$(part | /usr/bin/cut -d'|' -f3-4)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.logs.hold.confirmed
check "  a second confirmation changes nothing" "" "$(asked_agentvm)"
"$PB" "agentvm_logs_hold_$UUID" set "14"
omc_run AgentVM.main.logs.hold.confirmed
check "a pending time that is none of the picker's is not applied" "" "$(asked_agentvm)"

section "the time: agent-vm refuses, and status fails"
kept 0 0 30
omc_run AgentVM.main.activated
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-store"
clear_alerts
pick 7
check "its reason is shown, and the picker goes back to the store's time" "The time was not changed|the store is locked|30" \
    "$(ui_alert_title)|$(ui_alert_message)|$(ui_value "$MAIN_KEPT_HOLD_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-store"
printf 'no status today\n' > "$FAKE_AGENTVM_DIR/fail-status"
clear_alerts
: > "$FAKE_AGENTVM_DIR/log"
pick 90
check "status fails: nothing is changed on a time that may be old" "|" "$(asked_agentvm)|$(ui_alert_title)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"

section "closing the window forgets the pending questions"
kept 5 100000 30
omc_run AgentVM.main.activated
omc_run AgentVM.main.logs.remove
pick 7
check "guard: both are pending"     "1|7" "$(pending remove)|$(pending hold)"
omc_run AgentVM.main.close
check "closed: neither is"          "|" "$(pending remove)|$(pending hold)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.logs.remove.confirmed
omc_run AgentVM.main.logs.hold.confirmed
check "  and a confirmation after it does nothing" "" "$(asked_agentvm)"

section "no writes to views the window does not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
