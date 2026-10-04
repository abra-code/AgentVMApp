#!/bin/sh
# Tests/63-how-to.test.sh - the How to Use a Box window: the button that opens it, one window at
# a time and only when this run of the app asked for it, the lines it shows for a store with
# images and boxes and for an empty one, what it says about avm, and Copy: the line that reaches
# the clipboard.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json or status-empty.json.
# The clipboard is a file (helpers/fake_pbcopy.sh).
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.howto.sh"
HOWTO_COMMAND_BASE="$(/usr/bin/sed -n 's/^HOWTO_COMMAND_BASE=\([0-9]*\)$/\1/p' "$APP_SCRIPTS/lib.agentvm.howto.sh")"
HOWTO_COPY_BASE="$(/usr/bin/sed -n 's/^HOWTO_COPY_BASE=\([0-9]*\)$/\1/p' "$APP_SCRIPTS/lib.agentvm.howto.sh")"
HOWTO_WHAT_BASE="$(/usr/bin/sed -n 's/^HOWTO_WHAT_BASE=\([0-9]*\)$/\1/p' "$APP_SCRIPTS/lib.agentvm.howto.sh")"
[ -n "$HOWTO_NOTE_ID" ] && [ -n "$MAIN_HOWTO_ID" ] && [ -n "$HOWTO_COMMAND_BASE" ] && [ -n "$HOWTO_COPY_BASE" ] && [ -n "$HOWTO_WHAT_BASE" ] || {
    printf '63-how-to: no view ids imported from the libraries\n' >&2
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
APP_PID="${OMC_APP_PROCESS_ID:?63-how-to: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-how-to-$$"
OTHER_UUID="OMCTEST-other-how-to-$$"

in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

request() {
    "$PB" agentvm_open_request_howto get
}

registered() {
    "$PB" agentvm_window_howto_window get
}

# open_window [uuid]  ->  the window opened the way the button opens it: the request, then the
# window's init handler, in a window of its own.
open_window() {
    "$PB" agentvm_open_request_howto set "$APP_PID howto:window"
    in_window "${1:-$UUID}"
    ui_reset
    omc_control_defaults AgentVM.howto
    omc_run AgentVM.howto.init
}

# commands  ->  the five commands the window shows. what <n>  ->  what line n does.
commands() {
    printf '%s|%s|%s|%s|%s\n' "$(ui_value "$(( HOWTO_COMMAND_BASE + 1 ))")" "$(ui_value "$(( HOWTO_COMMAND_BASE + 2 ))")" \
        "$(ui_value "$(( HOWTO_COMMAND_BASE + 3 ))")" "$(ui_value "$(( HOWTO_COMMAND_BASE + 4 ))")" "$(ui_value "$(( HOWTO_COMMAND_BASE + 5 ))")"
}
what() {
    ui_value "$(( HOWTO_WHAT_BASE + $1 ))"
}

# copy <n>  ->  Copy beside line n. clipboard  ->  what reached the clipboard, or "(nothing)".
copy() {
    omc_trigger "$(( HOWTO_COPY_BASE + $1 ))"
    omc_run AgentVM.howto.copy
}
clipboard() {
    if [ -f "$FAKE_PBCOPY_FILE" ]; then
        /bin/cat "$FAKE_PBCOPY_FILE"
    else
        printf '(nothing)\n'
    fi
}

fake_reset
/bin/cp "$FIXTURES_AGENTVM/status-variety.json" "$FAKE_AGENTVM_DIR/status.json"
"$PB" agentvm_window_howto_window set ""
"$PB" agentvm_open_request_howto set ""

# -----------------------------------------------------------------------------------------------
section "the button that opens it"
in_window "$MAIN_UUID"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_trigger "$MAIN_HOWTO_ID"
omc_run AgentVM.howto.open
check "the question mark under the box list asks for the window, with a request of this run, and asks agent-vm nothing" \
    "1|$APP_PID howto:window|" "$(chain_asked AgentVM.howto)|$(request)|$(fake_log)"
check "the button runs that handler, and has only a symbol and a tooltip" "AgentVM.howto.open|questionmark.circle|null|How to use a box" \
    "$(/usr/bin/jq -r --argjson id "$MAIN_HOWTO_ID" '.. | objects | select(.id? == $id) | .properties | "\(.actionID)|\(.systemImage)|\(.title)|\(.help)"' "$APP_RESOURCES/Base.lproj/AgentVM.json")"

section "the window opens: a store with images and boxes"
mkdir_avm="$HOME/.local/bin"
/bin/mkdir -p "$mkdir_avm"
printf '#!/bin/sh\n' > "$mkdir_avm/avm"
/bin/chmod +x "$mkdir_avm/avm"
: > "$FAKE_AGENTVM_DIR/log"
open_window
check_status "the init handler exits cleanly" 0
check "takes the request, once"     "" "$(request)"
check "becomes the How to Use a Box window" "$APP_PID $UUID|1" "$(registered)|$("$PB" "agentvm_howto_$UUID" get)"
check "asks agent-vm which it is, and reads status" "--version|status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "its title"                   "How to Use a Box" "$(ui_title)"
check "the lines name the first ready image and the first kept box" \
    "avm|avm new dev|avm new dev --name work|avm s3|~/.local/bin/avm" "$(commands)"
check "what the second does" "Run in a new temporary box from the image \"dev\", used once and deleted when you leave it." "$(what 2)"
check "what the fourth does" "Run avm in existing box \"s3\". It is started if needed and runs on afterwards." "$(what 4)"
check "avm is where the installer puts it" "1" "$(ui_value "$HOWTO_NOTE_ID" | /usr/bin/grep -c '^avm is installed in ~/.local/bin/\.')"
check "every line of the document has its three views" "5 5 5" \
    "$(for base in "$HOWTO_COMMAND_BASE" "$HOWTO_COPY_BASE" "$HOWTO_WHAT_BASE"; do /usr/bin/jq --argjson base "$base" '[.. | objects | select((.id? // 0) > $base and (.id? // 0) <= $base + 5)] | length' "$APP_RESOURCES/Base.lproj/AgentVM.howto.json"; done | /usr/bin/paste -sd ' ' -)"
check "Agent Keys... in it opens the keys window" "AgentVM.keys.open" \
    "$(/usr/bin/jq -r '.. | objects | select(.properties?.title? == "Agent Keys...") | .properties.actionID' "$APP_RESOURCES/Base.lproj/AgentVM.howto.json")"

section "Copy"
/bin/rm -f "$FAKE_PBCOPY_FILE" "$FAKE_PBCOPY_FILE.args"
copy 3
check_status "Copy exits cleanly" 0
check "the line goes to the clipboard as shown, on stdin, with no line end" "avm new dev --name work||23" \
    "$(clipboard)|$(/bin/cat "$FAKE_PBCOPY_FILE.args")|$(/usr/bin/wc -c < "$FAKE_PBCOPY_FILE" | /usr/bin/tr -d ' ')"
check "the window says what was copied" "Copied: avm new dev --name work" "$(ui_value "$HOWTO_NOTE_ID")"
copy 5
check "the full path" "~/.local/bin/avm" "$(clipboard)"
/bin/rm -f "$FAKE_PBCOPY_FILE"
for stray in 0 6 -1 99; do
    copy "$stray"
done
( OMC_ACTIONUI_TRIGGER_VIEW_ID="x; id"; export OMC_ACTIONUI_TRIGGER_VIEW_ID; omc_run AgentVM.howto.copy )
check "a button that is not one of the five copies nothing" "(nothing)" "$(clipboard)"
( FAKE_PBCOPY_FAIL=1; export FAKE_PBCOPY_FAIL
  "$OMC_OMC_SUPPORT_PATH/omc_dialog_control" "$UUID" "$HOWTO_NOTE_ID" "before"
  copy 1 )
check "a clipboard that cannot be written: the window does not say Copied" "before" "$(ui_value "$HOWTO_NOTE_ID")"

section "only one window, and only when this run asked"
: > "$FAKE_AGENTVM_DIR/log"
open_window "$OTHER_UUID"
check "a second window closes itself and brings the first to the front" "1|1|$APP_PID $UUID|" \
    "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(ui_calls "^${UUID}${TAB}omc_window${TAB}omc_select")|$(registered)|$(fake_log)"
/bin/rm -f "$FAKE_PBCOPY_FILE"
copy 1
check "  and its Copy does nothing" "(nothing)" "$(clipboard)"
in_window "$OTHER_UUID"
omc_run AgentVM.howto.close
check "  and its closing leaves the first registered" "$APP_PID $UUID" "$(registered)"
in_window "$UUID"
omc_run AgentVM.howto.close
check "the window closes: it is no longer registered, and nothing of it stays" "||no" \
    "$(registered)|$("$PB" "agentvm_howto_$UUID" get)|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)"
ui_reset
omc_control_defaults AgentVM.howto
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.howto.init
check "a window nobody asked for closes itself and reads nothing" "1||" \
    "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(fake_log)|$("$PB" "agentvm_howto_$UUID" get)"
"$PB" agentvm_open_request_howto set "1 howto:window"
omc_run AgentVM.howto.init
check "nor does a request another run of the app left open one" "" "$("$PB" "agentvm_howto_$UUID" get)"

# -----------------------------------------------------------------------------------------------
section "an empty store, no avm, and reading again"
/bin/cp "$FIXTURES_AGENTVM/status-empty.json" "$FAKE_AGENTVM_DIR/status.json"
/bin/rm -f "$HOME/.local/bin/avm"
open_window
check "the lines use example names" "avm|avm new dev|avm new dev --name work|avm work|~/.local/bin/avm" "$(commands)"
check "  and say that they are examples" "1|1" \
    "$(what 2 | /usr/bin/grep -c 'No image is ready yet: dev stands for the one you build\.$')|$(what 4 | /usr/bin/grep -c 'No kept box exists yet: work stands for one you make\.$')"
check "avm is not there: the window says where it comes from" "1" "$(ui_value "$HOWTO_NOTE_ID" | /usr/bin/grep -c '^avm is not in ~/.local/bin/ on this Mac\.')"
/usr/bin/jq '.boxes |= map(select(.box.name == "cadabra-spike"))' "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.howto.activated
check "the window comes to the front: status is read again" "status --json" "$(fake_log)"
check "  a box that is deleted when it stops is not the kept box of the fourth line" "avm new dev|avm work" \
    "$(ui_value "$(( HOWTO_COMMAND_BASE + 2 ))")|$(ui_value "$(( HOWTO_COMMAND_BASE + 4 ))")"
omc_run AgentVM.howto.close
( AGENTVM_APP_AGENT_VM="$OMCTEST_WORK/no-such-agent-vm"; export AGENTVM_APP_AGENT_VM
  open_window
  commands > "$OMCTEST_WORK/unusable" )
check "no agent-vm: the lines are still there, with the example names" "avm|avm new dev|avm new dev --name work|avm work|~/.local/bin/avm" "$(/bin/cat "$OMCTEST_WORK/unusable")"
in_window "$UUID"
omc_run AgentVM.howto.close
in_window "$MAIN_UUID"

check "no harness errors"            "" "$(ui_errors)"

omctest_end
