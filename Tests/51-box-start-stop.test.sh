#!/bin/sh
# Tests/51-box-start-stop.test.sh - Start and Stop in the box detail pane: the job each starts,
# what the card, the pane and its buttons show while a job holds the box, the question Stop asks
# for a box in use, and what the window says when a job it saw running has failed.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json (s3 running, started by
# process 812 with two programs in it; cadabra-spike stopped; try1 not responding, with no owner).
# The fake keeps the jobs it is asked to start and carries them in `status`; a job never ends by
# itself, so the test edits it (job_edit) and the store (store) to move things on. The clock is
# fixed at 12 seconds after the fake's jobs start.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_BOX_START_ID" ] && [ -n "$MAIN_BOX_STOP_ID" ] && [ -n "$MAIN_BOX_STATE_ID" ] \
    && [ -n "$MAIN_BOX_DELETE_ID" ] || {
    printf '51-box-start-stop: no view ids imported from lib.agentvm.main.sh\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
TZ=UTC
# 2026-09-30T12:00:12Z: the fake's jobs start at 12:00:00.
AGENTVM_APP_NOW=1790769612
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG TZ AGENTVM_APP_NOW
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
UUID="$OMC_ACTIONUI_WINDOW_UUID"
JOBS="$FAKE_AGENTVM_DIR/jobs.json"

# store <jq edit of status-variety.json>  ->  the fake answers status with that.
store() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

# box_state <name> <state>  ->  a jq edit for store: that box in that state.
box_state() {
    printf '(.boxes[] | select(.box.name == "%s")).state = "%s"' "$1" "$2"
}

# job_edit <jq filter over the fake's jobs>  ->  the jobs moved on, as agent-vm would record it.
job_edit() {
    /usr/bin/jq "$1" "$JOBS" > "$JOBS.new" && /bin/mv "$JOBS.new" "$JOBS"
}

# job_end <state> [error]  ->  the newest job ended that way.
job_end() {
    job_edit "(.[-1]) |= (. + {state: \"$1\", endedAt: \"2026-09-30T12:00:20Z\"} | if \"$1\" == \"done\" then .status = 0 elif \"$1\" == \"failed\" then .status = 75 else . end | if \"${2:-}\" != \"\" then .error = \"${2:-}\" else . end)"
}

open_window() {
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}

poll() {
    ( AGENTVM_APP_POLL_PASSES="$1"; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
}

select_box() {
    omc_table_cell "$MAIN_BOXES_ID" 1 "$1"
    omc_trigger "$MAIN_BOXES_ID"
    omc_run AgentVM.main.box.selected
}

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

# buttons  ->  the box's buttons, enabled (1) or not: Start, Stop, View, Open Shell, Run an Agent,
# Recreate, Delete.
buttons() {
    printf '%s %s %s %s %s %s %s\n' "$(enabled "$MAIN_BOX_START_ID")" "$(enabled "$MAIN_BOX_STOP_ID")" \
        "$(enabled "$MAIN_BOX_VIEW_ID")" "$(enabled "$MAIN_BOX_SHELL_ID")" \
        "$(enabled "$MAIN_BOX_AGENT_ID")" "$(enabled "$MAIN_BOX_RECREATE_ID")" "$(enabled "$MAIN_BOX_DELETE_ID")"
}

# card <name>  ->  that box's card: its symbol and its caption.
card() {
    ui_rows "$MAIN_BOXES_ID" | /usr/bin/awk -F'\t' -v n="$1" '$1 == n { print $2 "|" $3 }'
}

# started  ->  the jobs the fake was asked to start, as agent-vm was called.
started() {
    fake_log | /usr/bin/grep '^job start' | /usr/bin/paste -sd '|' -
}

clear_alerts() {
    alerts_reset
    ui_reset
}

KEPT='(.boxes[] | select(.box.name == "cadabra-spike")).box.disposable = false'

fake_reset
store "$KEPT"
: > "$FAKE_SLEEP_LOG"
open_window

# -----------------------------------------------------------------------------------------------
section "which of Start and Stop a box offers"
select_box cadabra-spike
check "a stopped box: Start"     "1 0" "$(enabled "$MAIN_BOX_START_ID") $(enabled "$MAIN_BOX_STOP_ID")"
select_box s3
check "a running box: Stop"      "0 1" "$(enabled "$MAIN_BOX_START_ID") $(enabled "$MAIN_BOX_STOP_ID")"
select_box try1
check "a box that does not respond: Stop" "0 1" "$(enabled "$MAIN_BOX_START_ID") $(enabled "$MAIN_BOX_STOP_ID")"
store "$KEPT | $(box_state cadabra-spike starting)"
poll 1
select_box cadabra-spike
check "a box starting by itself: neither" "0 0" "$(enabled "$MAIN_BOX_START_ID") $(enabled "$MAIN_BOX_STOP_ID")"
store "$KEPT"
poll 1

# -----------------------------------------------------------------------------------------------
section "Start"
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.start
check_status "the handler exits cleanly" 0
check "status is read, the job started with no owner, and status read again" \
    "status --json|job start --json -- box start cadabra-spike|status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "the poll loop is begun anew" "1" "$(chain_asked AgentVM.main.poll)"
check "the pane says what the job does, and for how long" "Starting, 12 s so far" "$(ui_value "$MAIN_BOX_STATE_ID")"
check "the card too, drawn as a box in between" "circle.dotted|yes" \
    "$(card cadabra-spike | /usr/bin/cut -d'|' -f1)|$(card cadabra-spike | /usr/bin/grep -q '|Starting - dev-agents' && echo yes)"
check "every button of the pane is off while the job holds the box" "0 0 0 0 0 0 0" "$(buttons)"
check "another box's card is as it was" "play.circle.fill" "$(card s3 | /usr/bin/cut -d'|' -f1)"
: > "$FAKE_SLEEP_LOG"
poll 1
check "the poll loop looks every 2 seconds while the job runs" "2" "$(/bin/cat "$FAKE_SLEEP_LOG")"

section "a second Start while the job holds the box"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.start
check "starts nothing"           "" "$(started)"
omc_run AgentVM.main.box.stop
check "nor does Stop"            "" "$(started)"
"$PB" "agentvm_box_delete_$UUID" set ""
omc_run AgentVM.main.box.delete
check "nor is Delete asked"      "" "$("$PB" "agentvm_box_delete_$UUID" get)"

section "the job ends well"
job_end done
store "$KEPT | $(box_state cadabra-spike running)"
clear_alerts
poll 1
check "the pane shows the box running" "yes" "$(ui_value "$MAIN_BOX_STATE_ID" | /usr/bin/grep -q '^Running' && echo yes)"
check "  with Stop"              "0 1" "$(enabled "$MAIN_BOX_START_ID") $(enabled "$MAIN_BOX_STOP_ID")"
check "  the card no longer says Starting" "play.circle.fill|no" \
    "$(card cadabra-spike | /usr/bin/cut -d'|' -f1)|$(card cadabra-spike | /usr/bin/grep -q 'Starting' && echo yes || echo no)"
check "a toast says the box is running, and goes by itself" "1|1" \
    "$(ui_calls 'omc_present_toast.*Box cadabra-spike is running\.')|$(ui_calls 'omc_present_toast.Box cadabra-spike is running\..5')"
check "  no alert"               "" "$(ui_alert_title)"
clear_alerts
poll 1
check "  said once"              "0" "$(ui_calls omc_present_toast)"
: > "$FAKE_SLEEP_LOG"
poll 1
check "the poll loop is back to its idle pace" "15" "$(/bin/cat "$FAKE_SLEEP_LOG")"

# -----------------------------------------------------------------------------------------------
section "a start that fails"
store "$KEPT"
poll 1
omc_run AgentVM.main.box.start
job_end failed "box cadabra-spike cannot start: two virtual machines are running already (s3, try1); stop one first"
clear_alerts
poll 1
check "is said when the job ends, in agent-vm's words" \
    "Box cadabra-spike did not start|box cadabra-spike cannot start: two virtual machines are running already (s3, try1); stop one first" \
    "$(ui_alert_title)|$(ui_alert_message)"
check "  in an alert, not a toast" "0" "$(ui_calls omc_present_toast)"
check "  the box is stopped, with Start again" "Stopped|1 0" "$(ui_value "$MAIN_BOX_STATE_ID")|$(enabled "$MAIN_BOX_START_ID") $(enabled "$MAIN_BOX_STOP_ID")"
clear_alerts
poll 1
omc_run AgentVM.main.activated
check "  and said once"          "" "$(ui_alert_title)"

section "a job whose runner was stopped, and one that was canceled"
omc_run AgentVM.main.box.start
job_end lost "the job ended without recording a result: its runner was stopped"
clear_alerts
poll 1
check "lost: said, in agent-vm's words" "Box cadabra-spike did not start|the job ended without recording a result: its runner was stopped" \
    "$(ui_alert_title)|$(ui_alert_message)"
omc_run AgentVM.main.box.start
job_end canceled canceled
clear_alerts
poll 1
check "canceled: nothing is said" "" "$(ui_alert_title)"
check "  not in a toast either"  "0" "$(ui_calls omc_present_toast)"
omc_run AgentVM.main.box.start
job_end failed ""
clear_alerts
poll 1
check "failed with no reason: says that" "agent-vm gave no reason." "$(ui_alert_message)"

section "a start that fails within the moment, before the window reads again"
printf 'failed\n' > "$FAKE_AGENTVM_DIR/job-start-state"
printf 'no box cadabra-spike\n' > "$FAKE_AGENTVM_DIR/job-start-error"
clear_alerts
omc_run AgentVM.main.box.start
/bin/rm -f "$FAKE_AGENTVM_DIR/job-start-state" "$FAKE_AGENTVM_DIR/job-start-error"
check "is said too, though the window never saw it running" "Box cadabra-spike did not start|no box cadabra-spike" "$(ui_alert_title)|$(ui_alert_message)"
clear_alerts
poll 1
check "  once"                  "" "$(ui_alert_title)"

section "agent-vm refuses to start the job"
printf 'the store is locked by another agent-vm\n' > "$FAKE_AGENTVM_DIR/fail-job-start"
clear_alerts
chains_reset
omc_run AgentVM.main.box.start
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-job-start"
check "its reason is shown"      "Box cadabra-spike was not started|the store is locked by another agent-vm" "$(ui_alert_title)|$(ui_alert_message)"
check "  and no poll loop is begun for it" "0" "$(chain_asked AgentVM.main.poll)"
check "  Start is still offered" "1" "$(enabled "$MAIN_BOX_START_ID")"

section "status fails"
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-status"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.start
check "nothing is started from rows that may be old" "" "$(started)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
poll 1

# -----------------------------------------------------------------------------------------------
section "Stop: a box nobody uses"
select_box try1
clear_alerts
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.stop
check "is stopped at once, as a job" "job start --json -- box stop try1" "$(started)"
check "  with no question"       "" "$(ui_alert_title)"
check "the pane and the card say Stopping" "Stopping, 12 s so far|circle.dotted|yes" \
    "$(ui_value "$MAIN_BOX_STATE_ID")|$(card try1 | /usr/bin/cut -d'|' -f1)|$(card try1 | /usr/bin/grep -q '|Stopping - ' && echo yes)"
check "  every button off"       "0 0 0 0 0 0 0" "$(buttons)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.stop
check "a second Stop while the job holds the box stops nothing more" "" "$(started)"
job_end failed "box try1 did not stop within 120 s"
clear_alerts
poll 1
check "a stop that fails is said" "Box try1 did not stop|box try1 did not stop within 120 s" "$(ui_alert_title)|$(ui_alert_message)"

section "Stop: a box another program started, with programs in it"
select_box s3
clear_alerts
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.stop
check "asks first"               "Stop box s3?" "$(ui_alert_title)"
check "  saying who started it and what runs in it" \
    "Cadabra (process 812) started this box and may be using it. 2 programs are running in it and will be ended." "$(ui_alert_message)"
check "  Stop confirms"          "AgentVM.main.box.stop.confirmed" "$(ui_alert_action Stop)"
check "  nothing is stopped yet" "" "$(started)"
check "  the box asked about is kept" "s3" "$("$PB" "agentvm_box_stop_$UUID" get)"
select_box try1
omc_run AgentVM.main.box.stop.confirmed
check "confirmed: the box asked about is stopped, whatever is selected by then" "job start --json -- box stop s3" "$(started)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.stop.confirmed
check "a second confirmation stops nothing" "" "$(started)"
job_end done
store "$KEPT | $(box_state s3 stopped)"
clear_alerts
poll 1
check "the stop done: a toast says the box is stopped" "1" "$(ui_calls 'omc_present_toast.*Box s3 is stopped\.')"

section "Stop: the question's other shapes"
store "$KEPT | (.boxes[] | select(.box.name == \"s3\")).activeExecs = 1 | (.boxes[] | select(.box.name == \"s3\")).ownerPid = null"
poll 1
select_box s3
clear_alerts
omc_run AgentVM.main.box.stop
check "one program, no owner"    "One program is running in it and will be ended." "$(ui_alert_message)"
store "$KEPT | (.boxes[] | select(.box.name == \"s3\")).activeExecs = 0 | (.boxes[] | select(.box.name == \"s3\")).ownerPid = 4242"
poll 1
clear_alerts
omc_run AgentVM.main.box.stop
check "an owner whose name cannot be read, no program" "Another program (process 4242) started this box and may be using it." "$(ui_alert_message)"

section "Stop: the box stopped before the question was answered"
store "$KEPT | $(box_state s3 stopped)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.stop.confirmed
check "nothing is stopped"       "" "$(started)"
"$PB" "agentvm_box_stop_$UUID" set "-rf"
omc_run AgentVM.main.box.stop.confirmed
check "a pending name agent-vm would refuse is not passed on" "" "$(started)"

# -----------------------------------------------------------------------------------------------
section "jobs started elsewhere"
/bin/cp "$FIXTURES_AGENTVM/jobs-variety.json" "$JOBS"
store "$KEPT"
/usr/bin/jq '. + [.[-1] | .id = "20260930-115955-000108" | .command[2] = "s3" | .targets = ["box:s3"] | .after = "20260930-115950-000107" | .state = "queued" | del(.startedAt, .progress)]' \
    "$JOBS" > "$JOBS.new" && /bin/mv "$JOBS.new" "$JOBS"
clear_alerts
omc_run AgentVM.main.close
open_window
check "a job that had failed before the window opened is not reported" "" "$(ui_alert_title)"
select_box cadabra-spike
check "a box being started in Terminal or Cadabra: the pane says so" "Starting, 22 s so far" "$(ui_value "$MAIN_BOX_STATE_ID")"
check "  its card too, and its buttons are off" "yes|0 0 0 0 0 0 0" \
    "$(card cadabra-spike | /usr/bin/grep -q '|Starting - ' && echo yes)|$(buttons)"
select_box s3
check "a job that waits for another" "Waiting to start" "$(ui_value "$MAIN_BOX_STATE_ID")"
check "  its card says it waits" "yes" "$(card s3 | /usr/bin/grep -q '|Waiting - ' && echo yes)"
job_edit '(.[] | select(.id == "20260930-115950-000107")) |= (. + {state: "failed", status: 1, endedAt: "2026-09-30T12:00:20Z", error: "the box has no disk"})
    | (.[] | select(.id == "20260930-115955-000108")) |= (. + {state: "failed", status: 1, endedAt: "2026-09-30T12:00:21Z", error: "it never ran"})'
clear_alerts
poll 1
check "two jobs the window saw running fail in one reading: one alert" "2 jobs failed" "$(ui_alert_title)"
# ui_alert_message gives a message's first line; the second is read from the alert as recorded.
check "  naming each, with its reason" "Box cadabra-spike did not start: the box has no disk|1" \
    "$(ui_alert_message)|$(/usr/bin/grep -c -x 'Box s3 did not start: it never ran' "$(omctest_win_dir)/pending_alert")"

section "closing forgets a pending stop"
"$PB" "agentvm_box_stop_$UUID" set s3
omc_run AgentVM.main.close
check "forgotten"                "" "$("$PB" "agentvm_box_stop_$UUID" get)"

section "no writes to views the window does not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no rows written as a value" "" "$(ui_suspect_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
