#!/bin/sh
# Tests/64-where-the-logs-are.test.sh - the Where the Logs Are window: the button that opens it,
# one window at a time and only when this run of the app asked for it, the three places it shows
# with their folders (which follow the store agent-vm names), what it says of the logs of deleted
# boxes, the lines for Terminal, Show in Finder, and the two kinds of Copy.
#
# agent-vm is the fake: status from a jq edit of fixtures/agentvm/status-variety.json or of
# status-empty.json, with the store's folder made here, since the fixtures' is not on this Mac.
# Finder and the clipboard are files (helpers/fake_open.sh, helpers/fake_pbcopy.sh).
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.logs.sh"
base() {
    /usr/bin/sed -n "s/^$1=\\([0-9][0-9]*\\)\$/\\1/p" "$APP_SCRIPTS/lib.agentvm.logs.sh"
}
FOLDER="$(base LOGS_FOLDER_BASE)"
SHOW="$(base LOGS_SHOW_BASE)"
PATH_COPY="$(base LOGS_PATH_BASE)"
COMMAND="$(base LOGS_COMMAND_BASE)"
COPY="$(base LOGS_COPY_BASE)"
WHAT="$(base LOGS_WHAT_BASE)"
[ -n "$LOGS_NOTE_ID" ] && [ -n "$LOGS_KEPT_ID" ] && [ -n "$FOLDER" ] && [ -n "$SHOW" ] && [ -n "$PATH_COPY" ] && [ -n "$COMMAND" ] && [ -n "$COPY" ] && [ -n "$WHAT" ] || {
    printf '64-where-the-logs-are: no view ids imported from the library\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
AGENTVM_APP_PBCOPY="$TEST_HELPERS/fake_pbcopy.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
FAKE_PBCOPY_FILE="$OMCTEST_WORK/clipboard"
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN AGENTVM_APP_PBCOPY FAKE_SLEEP_LOG FAKE_OPEN_LOG FAKE_PBCOPY_FILE
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
MAIN_UUID="$OMC_ACTIONUI_WINDOW_UUID"
APP_PID="${OMC_APP_PROCESS_ID:?64-where-the-logs-are: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-logs-$$"
OTHER_UUID="OMCTEST-other-logs-$$"
# The store, on this Mac: its folder has a space in it, as agent-vm's own has.
STORE="$OMCTEST_WORK/the store"

in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

# store <fixture> <jq object: what status says of the logs of deleted boxes> [jq edit]  ->  the
# fake answers status with that.
store() {
    /usr/bin/jq ".keptLogs = $2 | ${3:-.}" "$FIXTURES_AGENTVM/$1" > "$FAKE_AGENTVM_DIR/status.json"
}

request() {
    "$PB" agentvm_open_request_logs get
}

registered() {
    "$PB" agentvm_window_logs_window get
}

# open_window [uuid]  ->  the window opened the way the button opens it: the request, then the
# window's init handler, in a window of its own.
open_window() {
    "$PB" agentvm_open_request_logs set "$APP_PID logs:window"
    in_window "${1:-$UUID}"
    ui_reset
    omc_control_defaults AgentVM.logs
    omc_run AgentVM.logs.init
}

# folders  ->  the three folders the window shows. shows  ->  whether each Show in Finder is on.
folders() {
    printf '%s|%s|%s\n' "$(ui_value "$(( FOLDER + 1 ))")" "$(ui_value "$(( FOLDER + 2 ))")" "$(ui_value "$(( FOLDER + 3 ))")"
}
shows() {
    local _n=0 _all=""
    while [ "$_n" -lt 3 ]; do
        _n=$((_n + 1))
        [ "$(ui_enabled "$(( SHOW + _n ))")" = "1" ] && _all="${_all}1" || _all="${_all}0"
    done
    printf '%s\n' "$_all"
}
commands() {
    printf '%s|%s|%s|%s\n' "$(ui_value "$(( COMMAND + 1 ))")" "$(ui_value "$(( COMMAND + 2 ))")" "$(ui_value "$(( COMMAND + 3 ))")" "$(ui_value "$(( COMMAND + 4 ))")"
}
what() {
    ui_value "$(( WHAT + $1 ))"
}

# show <n>, path <n>, copy <n>  ->  that button, clicked.
show() {
    omc_trigger "$(( SHOW + $1 ))"
    omc_run AgentVM.logs.show
}
path() {
    omc_trigger "$(( PATH_COPY + $1 ))"
    omc_run AgentVM.logs.path
}
copy() {
    omc_trigger "$(( COPY + $1 ))"
    omc_run AgentVM.logs.copy
}
opened() {
    /bin/cat "$FAKE_OPEN_LOG" 2>/dev/null
}
clipboard() {
    if [ -f "$FAKE_PBCOPY_FILE" ]; then
        /bin/cat "$FAKE_PBCOPY_FILE"
    else
        printf '(nothing)\n'
    fi
}
# logslib <function> [args...]  ->  a function of the window's library, in the window $UUID.
logslib() {
    ( . "$APP_SCRIPTS/lib.agentvm.logs.sh" >/dev/null 2>&1; "$@" )
}

fake_reset
"$PB" agentvm_window_logs_window set ""
"$PB" agentvm_open_request_logs set ""
/bin/mkdir -p "$STORE/Boxes" "$STORE/Logs"
store status-variety.json "{count: 3, bytes: 4096, holdDays: 30, directory: \"$STORE/Logs\"}"

# -----------------------------------------------------------------------------------------------
section "the button that opens it"
in_window "$MAIN_UUID"
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.logs.open
check "Where the Logs Are... asks for the window, with a request of this run, and asks agent-vm nothing" \
    "1|$APP_PID logs:window|" "$(chain_asked AgentVM.logs)|$(request)|$(fake_log)"
check "the button is in the How to Use a Box window, and runs that handler" "AgentVM.logs.open" \
    "$(/usr/bin/jq -r '.. | objects | select(.properties?.title? == "Where the Logs Are...") | .properties.actionID' "$APP_RESOURCES/Base.lproj/AgentVM.howto.json")"

section "the window opens: a store with boxes, and logs of deleted ones"
: > "$FAKE_AGENTVM_DIR/log"
open_window
check_status "the init handler exits cleanly" 0
check "takes the request, once"      "" "$(request)"
check "becomes the Where the Logs Are window" "$APP_PID $UUID|1" "$(registered)|$("$PB" "agentvm_logs_$UUID" get)"
check "asks agent-vm which it is, and reads status" "--version|status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "its title"                    "Where the Logs Are" "$(ui_title)"
check "the three folders: the boxes', the jobs', and the logs of deleted boxes, in the store agent-vm names" \
    "$STORE/Boxes|$STORE/Jobs|$STORE/Logs" "$(folders)"
check "Show in Finder is on for a folder that is on this Mac: there is none of jobs yet" "101" "$(shows)"
check "what is said of deleted boxes: for how long their logs are kept, and how many are" \
    "The same files, kept for 30 days in a folder named after the box and the time; 3 boxes' are kept now." "$(ui_value "$LOGS_KEPT_ID")"
check "the lines for Terminal name the first box, and list the jobs when status carries none" \
    "agent-vm box execlog cadabra-spike|agent-vm box netlog cadabra-spike --denied|agent-vm job list|agent-vm store logs" "$(commands)"
check "what the first does"          "The programs agent-vm started in box \"cadabra-spike\"." "$(what 1)"
check "nothing is noted"             "" "$(ui_value "$LOGS_NOTE_ID")"
check "every place and line of the document has its views" "3 3 3|4 4 4" \
    "$(for b in "$FOLDER" "$SHOW" "$PATH_COPY"; do /usr/bin/jq --argjson base "$b" '[.. | objects | select((.id? // 0) > $base and (.id? // 0) <= $base + 3)] | length' "$APP_RESOURCES/Base.lproj/AgentVM.logs.json"; done | /usr/bin/paste -sd ' ' -)|$(for b in "$COMMAND" "$COPY" "$WHAT"; do /usr/bin/jq --argjson base "$b" '[.. | objects | select((.id? // 0) > $base and (.id? // 0) <= $base + 4)] | length' "$APP_RESOURCES/Base.lproj/AgentVM.logs.json"; done | /usr/bin/paste -sd ' ' -)"
check "nothing writes to a view the window does not have" "" "$(ui_unknown_writes)"

section "Show in Finder"
: > "$FAKE_OPEN_LOG"
show 1
check_status "Show in Finder exits cleanly" 0
check "the boxes' folder opens in Finder" "$STORE/Boxes" "$(opened)"
: > "$FAKE_OPEN_LOG"
show 3
check "the folder of the logs of deleted boxes" "$STORE/Logs" "$(opened)"
: > "$FAKE_OPEN_LOG"
show 2
check "a folder that is not on this Mac opens nothing" "" "$(opened)"
/bin/mkdir -p "$STORE/Jobs"
show 2
check "  and opens once it is, with no new reading" "$STORE/Jobs" "$(opened)"
: > "$FAKE_OPEN_LOG"
for stray in 0 4 -1 99; do
    show "$stray"
done
( OMC_ACTIONUI_TRIGGER_VIEW_ID="x; id"; export OMC_ACTIONUI_TRIGGER_VIEW_ID; omc_run AgentVM.logs.show )
check "a button that is not one of the three opens nothing" "" "$(opened)"

section "Copy Path, and Copy"
/bin/rm -f "$FAKE_PBCOPY_FILE" "$FAKE_PBCOPY_FILE.args"
path 3
check_status "Copy Path exits cleanly" 0
check "the folder goes to the clipboard as a full path, on stdin, with no line end" "$STORE/Logs||$(printf '%s' "$STORE/Logs" | /usr/bin/wc -c | /usr/bin/tr -d ' ')" \
    "$(clipboard)|$(/bin/cat "$FAKE_PBCOPY_FILE.args")|$(/usr/bin/wc -c < "$FAKE_PBCOPY_FILE" | /usr/bin/tr -d ' ')"
check "the window says what was copied" "Copied: $STORE/Logs" "$(ui_value "$LOGS_NOTE_ID")"
path 1
check "another place's folder"       "$STORE/Boxes" "$(clipboard)"
copy 2
check "a line for Terminal goes to the clipboard as shown" "agent-vm box netlog cadabra-spike --denied|Copied: agent-vm box netlog cadabra-spike --denied" \
    "$(clipboard)|$(ui_value "$LOGS_NOTE_ID")"
copy 4
check "the last line"                "agent-vm store logs" "$(clipboard)"
/bin/rm -f "$FAKE_PBCOPY_FILE"
for stray in 0 5 -1 99; do
    copy "$stray"
done
for stray in 0 4 -1 99; do
    path "$stray"
done
( OMC_ACTIONUI_TRIGGER_VIEW_ID="x; id"; export OMC_ACTIONUI_TRIGGER_VIEW_ID; omc_run AgentVM.logs.copy; omc_run AgentVM.logs.path )
check "a button that is not one of them copies nothing" "(nothing)" "$(clipboard)"
( FAKE_PBCOPY_FAIL=1; export FAKE_PBCOPY_FAIL
  "$OMC_OMC_SUPPORT_PATH/omc_dialog_control" "$UUID" "$LOGS_NOTE_ID" "before"
  copy 1
  path 1 )
check "a clipboard that cannot be written: the window does not say Copied" "before" "$(ui_value "$LOGS_NOTE_ID")"

section "what status says, read again when the window comes to the front"
/usr/bin/jq -n '[{id: "20260930-120000-0000a1", command: ["image", "create", "dev", "--json"], targets: ["image:dev"], state: "running", createdAt: "2026-09-30T12:00:00Z"},
    {id: "20260930-120500-0000a2", command: ["box", "stop", "s3", "--json"], targets: ["box:s3"], state: "done", createdAt: "2026-09-30T12:05:00Z"}]' > "$FAKE_AGENTVM_DIR/jobs.json"
store status-variety.json "{count: 1, bytes: 512, holdDays: 1, directory: \"$STORE/Logs\"}"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.logs.activated
check "status is read again"         "status --json" "$(fake_log)"
check "one box's logs, kept for a day" "The same files, kept for 1 day in a folder named after the box and the time; 1 box's are kept now." "$(ui_value "$LOGS_KEPT_ID")"
check "the third line prints the newest job status carries" "agent-vm job log 20260930-120500-0000a2|What the newest job wrote; agent-vm job list names the others." \
    "$(ui_value "$(( COMMAND + 3 ))")|$(what 3)"
/bin/rm -f "$FAKE_AGENTVM_DIR/jobs.json"
store status-variety.json "{count: 0, bytes: 0, holdDays: 30, directory: \"$STORE/Logs\"}"
omc_run AgentVM.logs.activated
check "none kept now"                "The same files, kept for 30 days in a folder named after the box and the time; none are kept now." "$(ui_value "$LOGS_KEPT_ID")"
store status-variety.json "{count: 2, bytes: 9, holdDays: 0, directory: \"$STORE/Logs\"}"
omc_run AgentVM.logs.activated
check "a store that keeps none says so" "This store keeps no logs of deleted boxes: a box that is deleted leaves none." "$(ui_value "$LOGS_KEPT_ID")"
store status-variety.json 'null'
omc_run AgentVM.logs.activated
check "an agent-vm that says nothing of kept logs: no number is promised, and the folders are the default store's" \
    "The same files, in a folder named after the box and the time it was deleted.|~/Library/Application Support/agent-vm/Boxes|~/Library/Application Support/agent-vm/Jobs|~/Library/Application Support/agent-vm/Logs" \
    "$(ui_value "$LOGS_KEPT_ID")|$(folders)"
printf 'no status today\n' > "$FAKE_AGENTVM_DIR/fail-status"
omc_run AgentVM.logs.activated
check "status fails: the window says why, in agent-vm's words" "agent-vm could not be read: no status today" "$(ui_value "$LOGS_NOTE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
store status-variety.json "{count: 3, bytes: 4096, holdDays: 30, directory: \"$STORE/Logs\"}"
omc_run AgentVM.logs.activated
check "  and it clears with the next reading" "|$STORE/Logs" "$(ui_value "$LOGS_NOTE_ID")|$(ui_value "$(( FOLDER + 3 ))")"

section "only one window, and only when this run asked"
: > "$FAKE_AGENTVM_DIR/log"
open_window "$OTHER_UUID"
check "a second window closes itself and brings the first to the front" "1|1|$APP_PID $UUID|" \
    "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(ui_calls "^${UUID}${TAB}omc_window${TAB}omc_select")|$(registered)|$(fake_log)"
/bin/rm -f "$FAKE_PBCOPY_FILE"
: > "$FAKE_OPEN_LOG"
copy 1
path 1
show 1
check "  and its buttons do nothing" "(nothing)|" "$(clipboard)|$(opened)"
in_window "$OTHER_UUID"
omc_run AgentVM.logs.close
check "  and its closing leaves the first registered" "$APP_PID $UUID" "$(registered)"
in_window "$UUID"
omc_run AgentVM.logs.close
check "the window closes: it is no longer registered, and nothing of it stays" "||no" \
    "$(registered)|$("$PB" "agentvm_logs_$UUID" get)|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)"
ui_reset
omc_control_defaults AgentVM.logs
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.logs.init
check "a window nobody asked for closes itself and reads nothing" "1||" \
    "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(fake_log)|$("$PB" "agentvm_logs_$UUID" get)"
"$PB" agentvm_open_request_logs set "1 logs:window"
omc_run AgentVM.logs.init
check "nor does a request another run of the app left open one" "" "$("$PB" "agentvm_logs_$UUID" get)"

# -----------------------------------------------------------------------------------------------
section "an empty store, a store of the user's own, and no agent-vm"
store status-empty.json "{count: 0, bytes: 0, holdDays: 30, directory: \"$STORE/Logs\"}"
open_window
check "no box: the lines use an example name, and say so" "agent-vm box execlog work|agent-vm box netlog work --denied|1" \
    "$(ui_value "$(( COMMAND + 1 ))")|$(ui_value "$(( COMMAND + 2 ))")|$(what 1 | /usr/bin/grep -c 'No box exists yet: work stands for one you make\.$')"
omc_run AgentVM.logs.close
# Without an agent-vm nothing names the store: the app's setting does, when there is one.
( AGENTVM_APP_AGENT_VM="$OMCTEST_WORK/no-such-agent-vm"; export AGENTVM_APP_AGENT_VM
  open_window
  { folders; ui_value "$LOGS_NOTE_ID" | /usr/bin/grep -c 'no-such-agent-vm'; commands; } > "$OMCTEST_WORK/unusable" )
check "no agent-vm: the default store's folders, the reason, and the lines with the example name" \
    "~/Library/Application Support/agent-vm/Boxes|~/Library/Application Support/agent-vm/Jobs|~/Library/Application Support/agent-vm/Logs|1|agent-vm box execlog work|agent-vm box netlog work --denied|agent-vm job list|agent-vm store logs" \
    "$(/usr/bin/paste -sd '|' - < "$OMCTEST_WORK/unusable")"
in_window "$UUID"
omc_run AgentVM.logs.close
/bin/mkdir -p "$HOME/Library/Application Support/AgentVM"
printf '{"agentVMHome": "%s"}\n' "$OMCTEST_WORK/own store" > "$HOME/Library/Application Support/AgentVM/settings.json"
( AGENTVM_APP_AGENT_VM="$OMCTEST_WORK/no-such-agent-vm"; export AGENTVM_APP_AGENT_VM
  open_window
  folders > "$OMCTEST_WORK/own" )
check "  with a store of the user's own in the app's settings: that store's folders" \
    "$OMCTEST_WORK/own store/Boxes|$OMCTEST_WORK/own store/Jobs|$OMCTEST_WORK/own store/Logs" "$(/bin/cat "$OMCTEST_WORK/own")"
/bin/rm -f "$HOME/Library/Application Support/AgentVM/settings.json"
in_window "$UUID"
omc_run AgentVM.logs.close
in_window "$MAIN_UUID"

check "no harness errors"            "" "$(ui_errors)"

omctest_end
