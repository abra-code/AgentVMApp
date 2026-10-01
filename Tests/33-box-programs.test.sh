#!/bin/sh
# Tests/33-box-programs.test.sh - a box's programs window: how it opens (Details... on the box
# pane's Programs running row), one window per box, the program log, newest first, each program's
# status (running, no end recorded, stopped at a prompt), the prompt notices with the Full Disk
# Access line, and when the window reads.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json (s3 running, made from
# dev-acp; cadabra-spike stopped) and the program log from the hand-made box-execlog.json. Dates
# are read in UTC.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.programs.sh"
[ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_BOX_PROGRAMS_DETAILS_ID" ] && [ -n "$PROG_TABLE_ID" ] \
    && [ -n "$PROG_NOTICES_ID" ] && [ -n "$PROG_NOTE_ID" ] || {
    printf '33-box-programs: no view ids imported from the libraries\n' >&2
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
MAIN_UUID="$OMC_ACTIONUI_WINDOW_UUID"
# The app's pid, as the engine exports it: every window entry and open request carries it.
APP_PID="${OMC_APP_PROCESS_ID:?33-box-programs: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-programs-window-$$"
OTHER_UUID="OMCTEST-other-programs-window-$$"

# in_window <uuid>  ->  the handlers that follow run in that window.
in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

store() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

# request  ->  the open request a Details... left for the window it chained.
request() {
    "$PB" agentvm_open_request_programs get
}

# registered <box>  ->  the pasteboard entry naming that box's programs window: "<app pid> <uuid>".
registered() {
    "$PB" "agentvm_window_programs_$1" get
}

select_box() {
    omc_table_cell "$MAIN_BOXES_ID" 1 "$1"
    omc_trigger "$MAIN_BOXES_ID"
    omc_run AgentVM.main.box.selected
}

# open_programs <box> [uuid]  ->  that box's programs window opened the way Details... opens it:
# the request, then the window's init handler, in a window of its own.
open_programs() {
    "$PB" agentvm_open_request_programs set "$APP_PID programs:$1"
    in_window "${2:-$UUID}"
    omc_control_defaults AgentVM.programs
    omc_run AgentVM.programs.init
}

# program <command>  ->  the table's row of that command: started, command, status, took, user.
program() {
    ui_rows "$PROG_TABLE_ID" | /usr/bin/awk -F'\t' -v c="$1" '$2 == c'
}

fake_reset
store '.'
"$PB" agentvm_window_programs_s3 set ""
"$PB" agentvm_window_programs_cadabra-spike set ""
"$PB" agentvm_open_request_programs set ""

# -----------------------------------------------------------------------------------------------
section "Details... on the box pane's Programs running row"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
select_box s3
check "selecting a box reads no program log" "0" "$(fake_log | /usr/bin/grep -c '^box execlog')"
chains_reset
omc_trigger "$MAIN_BOX_PROGRAMS_DETAILS_ID"
omc_run AgentVM.main.box.programs
check "asks for a programs window" "1" "$(chain_asked AgentVM.programs)"
check "  for the selected box, from this run of the app" "$APP_PID programs:s3" "$(request)"

section "the window opens"
# The program with no end gets a client known to be gone: the fixture's pid may belong to any
# process on the Mac that runs the tests, and s3 runs, so it could read as running.
/usr/bin/true &
gone_pid=$!
wait "$gone_pid"
/usr/bin/jq --argjson pid "$gone_pid" '(.[] | select(.argv == ["claude"])).hostPid = $pid' "$FIXTURES_AGENTVM/box-execlog.json" \
    > "$FAKE_AGENTVM_DIR/box-execlog-s3.json"
: > "$FAKE_AGENTVM_DIR/log"
open_programs s3
check_status "the init handler exits cleanly" 0
check "takes the request, once"  "" "$(request)"
check "becomes the box's programs window" "$APP_PID $UUID" "$(registered s3)"
check "the title names the box"  "Programs in box s3" "$(ui_title)"
check "reads the box's state and its last programs" "status --json|box execlog s3 --last 200 --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "one row per program"      "6" "$(ui_row_count "$PROG_TABLE_ID")"
check "newest first"             "claude" "$(ui_rows "$PROG_TABLE_ID" | /usr/bin/sed -n '1p' | col 2)"
check "a program that ended: when, its status, how long, who" \
    "Sep 30 09:01:00${TAB}1${TAB}47 s${TAB}agent" "$(program "/bin/sh -lc 'npm test'" | /usr/bin/cut -f1,3-5)"
check "  a long one, in minutes" "0, done${TAB}9 min" "$(program "/bin/sh -c 'exec \"\$SHELL\" -l'" | col 3-4)"
check "  a quick one"            "0, done${TAB}under 1 s" "$(program /usr/bin/true | col 3-4)"
check "  exec's own failure, named" "127, not found" "$(program nosuchtool | col 3)"
check "  stopped at a prompt, and the signal" "143, signal 15, stopped at a prompt" "$(program "/usr/bin/open /Users/agent/Documents" | col 3)"
check "no end, and its client gone: no end recorded" "no end recorded${TAB}-" "$(program claude | col 3-4)"
check "the prompts, newest first" \
    "Sep 30 09:20:00  /usr/bin/open /Users/agent/Documents waited on a permission prompt: the Documents folder.|Sep 30 09:03:00  /bin/sh -c 'exec \"\$SHELL\" -l' waited on a permission prompt: the Downloads folder; the Desktop folder." \
    "$(ui_value "$PROG_NOTICES_ID" | /usr/bin/paste -sd '|' -)"
check "the note says what the window shows" \
    "The last 200 programs that agent-vm exec and box shell ran. The log stays on this Mac, out of the box's reach." \
    "$(ui_value "$PROG_NOTE_ID")"

section "a second Details... on the same box, and windows nobody asked for"
in_window "$MAIN_UUID"
chains_reset
omc_run AgentVM.main.box.programs
check "opens no second window"   "0" "$(chain_asked AgentVM.programs)"
check "  and brings the open one to the front" "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select" "$UUID")"
open_programs s3 "$OTHER_UUID"
check "a second window for the same box: the first stays the box's, the second closes" "$APP_PID $UUID|1" \
    "$(registered s3)|$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
ui_reset
"$PB" agentvm_open_request_programs set "$APP_PID network:cadabra-spike"
in_window "$OTHER_UUID"
omc_control_defaults AgentVM.programs
omc_run AgentVM.programs.init
check "a request for another kind of window: closes, and takes no box" "1|" \
    "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(registered cadabra-spike)"
check "  saying why, in case it stays" "No box was named for this window." "$(ui_value "$PROG_NOTE_ID")"
"$PB" agentvm_open_request_programs set "1 programs:cadabra-spike"
omc_run AgentVM.programs.init
check "a request another run of the app left: takes no box either" "" "$(registered cadabra-spike)"
in_window "$UUID"

section "a program with no end, while the box runs and its client exists: running"
# This test's own shell stands in for the client.
/usr/bin/jq --argjson pid "$$" '(.[] | select(.argv == ["claude"])).hostPid = $pid' "$FIXTURES_AGENTVM/box-execlog.json" \
    > "$FAKE_AGENTVM_DIR/box-execlog-s3.json"
omc_run AgentVM.programs.refresh
check "running"                  "running${TAB}-" "$(program claude | col 3-4)"
store '(.boxes[] | select(.box.name == "s3")).activeExecs = 0'
omc_run AgentVM.programs.refresh
check "agent-vm counts no program running in the box: no end recorded, whatever the pid" "no end recorded" "$(program claude | col 3)"
store '(.boxes[] | select(.box.name == "s3")).state = "stopped"'
omc_run AgentVM.programs.refresh
check "the box stopped: no end recorded, whatever the pid" "no end recorded" "$(program claude | col 3)"
store '.'
/bin/rm -f "$FAKE_AGENTVM_DIR/box-execlog-s3.json"

section "the Full Disk Access line"
store '(.images[] | select(.name == "dev-acp")).needs = [{kind: "full-disk-access", reason: "not-granted"}]'
omc_run AgentVM.programs.refresh
check "the box's image needs it: said under the prompts" \
    "Image dev-acp needs Full Disk Access: until it has it, programs in its boxes are asked before they open Desktop, Documents or Downloads." \
    "$(ui_value "$PROG_NOTICES_ID" | /usr/bin/tail -1)"
printf '[]\n' > "$FAKE_AGENTVM_DIR/box-execlog-s3.json"
omc_run AgentVM.programs.refresh
check "no prompts: nothing said, whatever the image needs" "" "$(ui_value "$PROG_NOTICES_ID")"
check "  an empty log says so"   "No program has run in this box yet." "$(ui_value "$PROG_NOTE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/box-execlog-s3.json"
store '.'

section "the notices stay short: five at most, long commands cut"
/usr/bin/jq '[range(7) as $i | .[3] | .started = "2026-09-30T10:0\($i):00Z" | .argv = ["/bin/sh", "-c", ("x" * 100)]]' \
    "$FIXTURES_AGENTVM/box-execlog.json" > "$FAKE_AGENTVM_DIR/box-execlog-s3.json"
omc_run AgentVM.programs.refresh
check "five of seven"            "5" "$(ui_value "$PROG_NOTICES_ID" | /usr/bin/awk 'END { print NR }')"
check "  a command cut to 60 characters, ending in ..." "60 ..." \
    "$(ui_value "$PROG_NOTICES_ID" | /usr/bin/sed -n '1p' | /usr/bin/sed 's/^Sep 30 10:06:00  //; s/ waited on.*//' | /usr/bin/awk '{ print length($0), substr($0, length($0) - 2) }')"
/bin/rm -f "$FAKE_AGENTVM_DIR/box-execlog-s3.json"

section "a log agent-vm cannot read"
printf 'the log is unreadable\n' > "$FAKE_AGENTVM_DIR/fail-box-execlog"
omc_run AgentVM.programs.refresh
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-box-execlog"
check "the note says why"        "the log is unreadable" "$(ui_value "$PROG_NOTE_ID")"

section "each box has a window of its own"
omc_run AgentVM.programs.refresh
/usr/bin/jq '[.[0]]' "$FIXTURES_AGENTVM/box-execlog.json" > "$FAKE_AGENTVM_DIR/box-execlog-cadabra-spike.json"
: > "$FAKE_AGENTVM_DIR/log"
open_programs cadabra-spike "$OTHER_UUID"
check "the other box's log is read" "1" "$(fake_log | /usr/bin/grep -c -x 'box execlog cadabra-spike --last 200 --json')"
check "  and shown in its window" "1|Programs in box cadabra-spike" "$(ui_row_count "$PROG_TABLE_ID")|$(ui_title)"
check "  the first window keeps its own" "6" "$(ui_row_count "$PROG_TABLE_ID" "$UUID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/box-execlog-cadabra-spike.json"

section "activation reads the window again"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.programs.activated
check "the box's state and its programs" "status --json|box execlog cadabra-spike --last 200 --json" "$(fake_log | /usr/bin/paste -sd '|' -)"

section "the box deleted elsewhere, and status failing, while the window is open"
store 'del(.boxes[] | select(.box.name == "cadabra-spike"))'
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.programs.activated
check "says the box is gone"     "Box cadabra-spike no longer exists." "$(ui_value "$PROG_NOTE_ID")"
check "  shows nothing of it, and reads nothing of it" "0|0" "$(ui_row_count "$PROG_TABLE_ID")|$(fake_log | /usr/bin/grep -c '^box execlog')"
store '.'
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-status"
omc_run AgentVM.programs.activated
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
check_status "exits cleanly" 0
check "status failing: the note says why" "the store is locked" "$(ui_value "$PROG_NOTE_ID")"
omc_run AgentVM.programs.activated
check "status answers again: the programs are back" "6" "$(ui_row_count "$PROG_TABLE_ID")"

section "deleting a box in the main window closes its programs window"
in_window "$MAIN_UUID"
closed="$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel" "$OTHER_UUID")"
"$PB" "agentvm_box_delete_$MAIN_UUID" set cadabra-spike
omc_run AgentVM.main.box.delete.confirmed
check "the deleted box's window is closed" "$((closed + 1))" "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel" "$OTHER_UUID")"
check "  the other box's is not" "0" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel" "$UUID")"

section "closing"
in_window "$UUID"
cache="$TMPDIR/AgentVM/$UUID"
check "the window has a cache"   "yes" "$([ -d "$cache" ] && echo yes)"
omc_run AgentVM.programs.close
check "the box has no programs window" "" "$(registered s3)"
check "  the window forgets its box" "" "$("$PB" "agentvm_box_$UUID" get)"
check "  and its cache is gone"  "no" "$([ -d "$cache" ] && echo yes || echo no)"
"$PB" agentvm_window_programs_s3 set "$APP_PID $OTHER_UUID"
"$PB" "agentvm_box_$UUID" set s3
omc_run AgentVM.programs.close
check "a window that was not the box's leaves the entry alone" "$APP_PID $OTHER_UUID" "$(registered s3)"
"$PB" agentvm_window_programs_s3 set ""

section "no writes to views the windows do not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no rows written as a value" "" "$(ui_suspect_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
