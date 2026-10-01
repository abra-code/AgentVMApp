#!/bin/sh
# Tests/31-box-detail.test.sh - the box detail pane's actions: the space (`box info`) and when it
# is read, which buttons each state enables, View and View and Control, Open Shell and Run an
# Agent in Terminal... (their .command files), and Recreate and Delete with their questions.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json (s3 running, try1
# unresponsive, cadabra-spike stopped and disposable), and `box info` from
# fixtures/agentvm/box-info.json, which describes cadabra-spike. Finder and Terminal are
# fake_open.sh.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_BOX_SPACE_ID" ] && [ -n "$MAIN_BOX_VIEW_ID" ] && [ -n "$MAIN_BOX_AGENT_ID" ] \
    && [ -n "$MAIN_BOX_RECREATE_ID" ] && [ -n "$MAIN_BOX_DELETE_ID" ] && [ -n "$MAIN_BOX_NONE_ID" ] || {
    printf '31-box-detail: no view ids imported from lib.agentvm.main.sh\n' >&2
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
KEPT='(.boxes[] | select(.box.name == "cadabra-spike")).box.disposable = false'

# store <jq edit of status-variety.json>  ->  the fake answers status with that.
store() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

open_window() {
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}

poll() {
    ( AGENTVM_APP_POLL_PASSES="$1"; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
}

# select_box <name>  ->  a click on that card (an empty name deselects).
select_box() {
    omc_table_cell "$MAIN_BOXES_ID" 1 "$1"
    omc_trigger "$MAIN_BOXES_ID"
    omc_run AgentVM.main.box.selected
}

# asks  ->  how many times the fake was asked to measure a box.
asks() {
    fake_log | /usr/bin/grep -c '^box info'
}

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

# buttons  ->  the pane's buttons, enabled (1) or not: View, View and Control, Open Shell, Run an
# Agent, Recreate, Delete.
buttons() {
    printf '%s %s %s %s %s %s\n' "$(enabled "$MAIN_BOX_VIEW_ID")" "$(enabled "$MAIN_BOX_CONTROL_ID")" \
        "$(enabled "$MAIN_BOX_SHELL_ID")" "$(enabled "$MAIN_BOX_AGENT_ID")" \
        "$(enabled "$MAIN_BOX_RECREATE_ID")" "$(enabled "$MAIN_BOX_DELETE_ID")"
}

# clear_alerts  ->  no pending alert on the window (it lives in the virtual window, which ui_reset
# wipes), and none recorded. The handlers that run next repaint what the checks read.
clear_alerts() {
    alerts_reset
    ui_reset
}

pending() {
    "$PB" "agentvm_box_$1_$UUID" get
}

# opened_file  ->  the .command file the last `open -a Terminal` was given.
opened_file() {
    /usr/bin/tail -1 "$FAKE_OPEN_LOG" | /usr/bin/sed -n 's/^-a Terminal //p'
}

fake_reset
store '.'
open_window

# -----------------------------------------------------------------------------------------------
section "a box's space, read when it is selected"
check "nothing selected at opening: nothing measured" "0" "$(asks)"
select_box cadabra-spike
check_status "the handler exits cleanly" 0
check "agent-vm measures the selected box once" "box info cadabra-spike --json" "$(fake_log | /usr/bin/grep '^box info')"
check "its space, and its own"  "40.2 GB; 2.0 GB its own (what Delete frees)" "$(ui_value "$MAIN_BOX_SPACE_ID")"

section "the poll loop does not measure again; activation does"
: > "$FAKE_AGENTVM_DIR/log"
poll 2
check "status only"             "0" "$(asks)"
check "the space is still shown" "40.2 GB" "$(ui_value "$MAIN_BOX_SPACE_ID" | /usr/bin/cut -d';' -f1)"
/usr/bin/jq '.diskUsage.bytes = 41000000000' "$FIXTURES_AGENTVM/box-info.json" > "$FAKE_AGENTVM_DIR/box-info-cadabra-spike.json"
omc_run AgentVM.main.activated
check "activation: once"        "1" "$(asks)"
check "  with the new size"     "41.0 GB" "$(ui_value "$MAIN_BOX_SPACE_ID" | /usr/bin/cut -d';' -f1)"
/bin/rm -f "$FAKE_AGENTVM_DIR/box-info-cadabra-spike.json"

section "measurements belong to the box they were read for"
"$PB" "agentvm_box_$UUID" set s3
poll 1
check "s3, with cadabra-spike's row in the cache: no size shown" "not measured" "$(ui_value "$MAIN_BOX_SPACE_ID")"
select_box s3
check "a box agent-vm cannot measure says why" "not measured: no box s3; \`agent-vm box list\` shows the existing ones" \
    "$(ui_value "$MAIN_BOX_SPACE_ID")"
"$PB" "agentvm_box_$UUID" set cadabra-spike
poll 1
check "cadabra-spike after s3's failure: its own last measurement, not s3's reason" "41.0 GB" "$(ui_value "$MAIN_BOX_SPACE_ID" | /usr/bin/cut -d';' -f1)"
select_box try1
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.activated
check "activation with a box that does not answer selected: not measured, so not waited for" "0" "$(asks)"
select_box try1
check "  selecting it measures it, after painting" "1" "$(asks)"
/usr/bin/jq 'del(.diskUsage.unsharedBytes)' "$FIXTURES_AGENTVM/box-info.json" > "$FAKE_AGENTVM_DIR/box-info-cadabra-spike.json"
select_box cadabra-spike
check "a volume that does not report the box's own part: all of it only" "40.2 GB" "$(ui_value "$MAIN_BOX_SPACE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/box-info-cadabra-spike.json"

# -----------------------------------------------------------------------------------------------
section "which buttons each state enables"
select_box s3
check "running: the screen, a shell and avm; not Recreate or Delete" "1 1 1 1 0 0" "$(buttons)"
select_box try1
check "not responding: nothing (it may still hold its virtual machine)" "0 0 0 0 0 0" "$(buttons)"
select_box cadabra-spike
check "stopped and disposable: only Delete" "0 0 0 0 0 1" "$(buttons)"
store "$KEPT"
poll 1
check "stopped and kept: avm, Recreate and Delete" "0 0 0 1 1 1" "$(buttons)"
store "$KEPT"' | (.images[] | select(.name == "dev-agents")).state = "provisioning"'
poll 1
check "  its image not ready: no Recreate" "0 0 0 1 0 1" "$(buttons)"
store "$KEPT"' | del(.images[] | select(.name == "dev-agents"))'
poll 1
check "  its image deleted: no Recreate" "0 0 0 1 0 1" "$(buttons)"
store '(.boxes[] | select(.box.name == "s3")).box.disposable = true'
poll 1
select_box s3
check "running and disposable: the screen and a shell, no avm" "1 1 1 0 0 0" "$(buttons)"
store '(.boxes[] | select(.box.name == "s3")).state = "starting"'
poll 1
check "starting: nothing yet" "0 0 0 0 0 0" "$(buttons)"
store '.'
poll 1

# -----------------------------------------------------------------------------------------------
section "View and View and Control"
select_box s3
alerts_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.view
check_status "View exits cleanly" 0
omc_run AgentVM.main.box.control
check "the screen, then the screen with control" "box view s3 --json|box view s3 --interactive --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "  no alert"              "" "$(ui_alert_title)"
printf 'box s3 is not running\n' > "$FAKE_AGENTVM_DIR/fail-box-view"
omc_run AgentVM.main.box.view
check "a refusal is shown"      "Could not show box s3" "$(ui_alert_title)"
check "  in agent-vm's words"   "box s3 is not running" "$(ui_alert_message)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-box-view"
select_box ""
alerts_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.control
check "no box selected: agent-vm is not asked" "" "$(fake_log)"

# -----------------------------------------------------------------------------------------------
section "Open Shell"
select_box s3
: > "$FAKE_OPEN_LOG"
clear_alerts
omc_run AgentVM.main.box.shell
check_status "exits cleanly" 0
file="$(opened_file)"
check "Terminal is asked to open a .command file" "yes" "$(case "$file" in (*/AgentVM/Terminal/s3-shell-*.command) echo yes ;; esac)"
check "  which runs agent-vm's shell in s3" "exec '$FAKE_AGENTVM' box shell s3" "$(/usr/bin/tail -1 "$file")"
check "  no alert"              "" "$(ui_alert_title)"
FAKE_OPEN_STATUS=1
export FAKE_OPEN_STATUS
omc_run AgentVM.main.box.shell
unset FAKE_OPEN_STATUS
file="$(opened_file)"
check "Terminal cannot open it: an alert" "Could not open Terminal for box s3" "$(ui_alert_title)"
check "  and the file is not left behind" "no" "$([ -e "$file" ] && echo yes || echo no)"

section "Run an Agent in Terminal..."
project="$OMCTEST_WORK/src/app"
/bin/mkdir -p "$project"
: > "$FAKE_OPEN_LOG"
alerts_reset
omc_dialog_answer choose_folder "$project"
omc_run AgentVM.main.box.agent
check_status "exits cleanly" 0
file="$(opened_file)"
check "Terminal runs avm on the box from the chosen folder" \
    "cd '$project' && exec '$HOME/Library/Application Support/AgentVM/bin/avm' --box s3" "$(/usr/bin/tail -1 "$file")"
: > "$FAKE_OPEN_LOG"
omc_dialog_answer choose_folder ""
omc_run AgentVM.main.box.agent
check "Cancel in the chooser: nothing opens" "" "$(/bin/cat "$FAKE_OPEN_LOG")"
omc_dialog_answer choose_folder "$OMCTEST_WORK/gone"
omc_run AgentVM.main.box.agent
check "a folder that is gone: nothing opens" "" "$(/bin/cat "$FAKE_OPEN_LOG")"
check "  an alert says why"     "Could not open Terminal for box s3|There is no folder at $OMCTEST_WORK/gone." \
    "$(ui_alert_title)|$(ui_alert_message)"

# -----------------------------------------------------------------------------------------------
section "Recreate: the question"
store "$KEPT"
poll 1
select_box cadabra-spike
alerts_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.recreate
check_status "exits cleanly" 0
check "reads status again first, and recreates nothing yet" "status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "asks"                    "Recreate box cadabra-spike?" "$(ui_alert_title)"
check "  what stays and what goes" \
    "It is made again from image dev-agents as the image is now, with the same name, processors, memory and network rules. Everything installed or saved in the box, logins included, is deleted. This cannot be undone." \
    "$(ui_alert_message)"
check "  Recreate confirms"     "AgentVM.main.box.recreate.confirmed" "$(ui_alert_action Recreate)"
check "  Cancel does nothing"   "" "$(ui_alert_action Cancel)"
check "  the box asked about is kept" "cadabra-spike" "$(pending recreate)"

section "Recreate: the box asked about is the one recreated"
select_box s3
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.recreate.confirmed
check "a selection changed after the question does not change what is recreated" \
    "box recreate cadabra-spike --json|status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "  the other box stays selected, and is not measured for it" "s3" "$("$PB" "agentvm_box_$UUID" get)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.recreate.confirmed
check "a second confirmation recreates nothing" "" "$(fake_log)"
select_box cadabra-spike
omc_run AgentVM.main.box.recreate
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.recreate.confirmed
check "the selected box, recreated: the lists, then its space, are read again" \
    "box recreate cadabra-spike --json|status --json|box info cadabra-spike --json" "$(fake_log | /usr/bin/paste -sd '|' -)"

section "Recreate: agent-vm fails"
omc_run AgentVM.main.box.recreate
printf 'deleted the old box but could not make the new one; run agent-vm box create cadabra-spike --image dev-agents\n' \
    > "$FAKE_AGENTVM_DIR/fail-box-recreate"
store "$KEPT"' | del(.boxes[] | select(.box.name == "cadabra-spike"))'
alerts_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.recreate.confirmed
check_status "exits cleanly" 0
check "the failure is shown"    "Box cadabra-spike was not recreated" "$(ui_alert_title)"
check "  in agent-vm's words"   "deleted the old box but could not make the new one; run agent-vm box create cadabra-spike --image dev-agents" \
    "$(ui_alert_message)"
check "  the lists are read again, so a box that is gone goes" "" "$(ui_rows "$MAIN_BOXES_ID" | row_named cadabra-spike)"
check "  and the pane shows it is gone" "1" "$(ui_visible "$MAIN_BOX_NONE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-box-recreate"

section "Recreate: nothing to ask about"
for edit in "." "$KEPT"' | (.boxes[] | select(.box.name == "cadabra-spike")).state = "running"' \
        "$KEPT"' | del(.images[] | select(.name == "dev-agents"))'; do
    store "$KEPT"
    poll 1
    select_box cadabra-spike
    store "$edit"
    clear_alerts
    omc_run AgentVM.main.box.recreate
    check "no question ($edit)" "|" "$(ui_alert_title)|$(pending recreate)"
done
check "  the pane follows what was read: Recreate disabled" "0" "$(enabled "$MAIN_BOX_RECREATE_ID")"

# -----------------------------------------------------------------------------------------------
section "Delete: the question"
store '.'
poll 1
select_box cadabra-spike
alerts_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.delete
check_status "exits cleanly" 0
check "reads status and measures the box again first" "status --json|box info cadabra-spike --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "asks"                    "Delete box cadabra-spike?" "$(ui_alert_title)"
check "  what it frees, and that its image stays" \
    "The box's folder and disk are deleted, with everything installed or saved in it, which frees about 2.0 GB. The image it was made from, dev-agents, is kept. This cannot be undone." \
    "$(ui_alert_message)"
check "  Delete confirms"       "AgentVM.main.box.delete.confirmed" "$(ui_alert_action Delete)"
check "  the box asked about is kept" "cadabra-spike" "$(pending delete)"

section "Delete: the box asked about is the one deleted"
select_box s3
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.delete.confirmed
check "a selection changed after the question does not change what is deleted" \
    "1" "$(fake_log | /usr/bin/grep -c -x 'box delete cadabra-spike --json')"
check "  the other box stays selected" "s3" "$("$PB" "agentvm_box_$UUID" get)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.delete.confirmed
check "a second confirmation deletes nothing" "0" "$(fake_log | /usr/bin/grep -c '^box delete')"

section "Delete: agent-vm refuses"
select_box cadabra-spike
omc_run AgentVM.main.box.delete
printf 'box cadabra-spike is running; stop it first\n' > "$FAKE_AGENTVM_DIR/fail-box-delete"
alerts_reset
omc_run AgentVM.main.box.delete.confirmed
check "the reason is shown"     "Box cadabra-spike was not deleted|box cadabra-spike is running; stop it first" \
    "$(ui_alert_title)|$(ui_alert_message)"
check "  and the box stays selected" "cadabra-spike" "$("$PB" "agentvm_box_$UUID" get)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-box-delete"

section "Delete: done"
omc_run AgentVM.main.box.delete
store 'del(.boxes[] | select(.box.name == "cadabra-spike"))'
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.delete.confirmed
check "agent-vm deletes it, and the lists are read again" "box delete cadabra-spike --json|status --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "  the selection is gone" "" "$("$PB" "agentvm_box_$UUID" get)"
check "  the placeholder is back" "1" "$(ui_visible "$MAIN_BOX_NONE_ID")"
check "  and its card"          "" "$(ui_rows "$MAIN_BOXES_ID" | row_named cadabra-spike)"

section "Delete: nothing to ask about"
store '.'
poll 1
select_box cadabra-spike
store '(.boxes[] | select(.box.name == "cadabra-spike")).state = "running"'
clear_alerts
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.delete
check "a box started meanwhile: no question, and not measured" "|status --json" \
    "$(ui_alert_title)|$(fake_log | /usr/bin/paste -sd '|' -)"
check "  Delete is disabled now" "0" "$(enabled "$MAIN_BOX_DELETE_ID")"
store '.'
poll 1
select_box cadabra-spike
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-status"
clear_alerts
omc_run AgentVM.main.box.delete
check "status fails: no question about rows that may be old" "" "$(ui_alert_title)"
check "  the note says why"     "the store is locked" "$(ui_value "$MAIN_BOXES_NOTE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
"$PB" "agentvm_box_delete_$UUID" set "-rf"
"$PB" "agentvm_box_recreate_$UUID" set "-rf"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.delete.confirmed
omc_run AgentVM.main.box.recreate.confirmed
check "a pending name agent-vm would refuse is not passed on" "" "$(fake_log)"

section "closing the window forgets the pending questions"
store "$KEPT"
poll 1
select_box cadabra-spike
omc_run AgentVM.main.box.recreate
omc_run AgentVM.main.box.delete
check "two questions were asked" "cadabra-spike cadabra-spike" "$(pending recreate) $(pending delete)"
omc_run AgentVM.main.close
check "  closing forgets both" " " "$(pending recreate) $(pending delete)"

section "no writes to views the window does not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
