#!/bin/sh
# Tests/20-main-window.test.sh - the main window: which face it shows, the header, the two
# tables, the one selection across them, and the poll loop that keeps them current.
#
# agent-vm is the fake (fixtures/agentvm/), the process list is fake_ps.sh (pid 812 is Cadabra),
# and the poll loop's wait is fake_sleep.sh, which records the seconds instead of waiting.
# AGENTVM_APP_POLL_PASSES ends each loop after a pass or two.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_IMAGES_ID" ] && [ -n "$MAIN_GETSTARTED_ID" ] || {
    printf '20-main-window: no view ids imported from lib.agentvm.main.sh\n' >&2
    exit 1
}

AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
export AGENTVM_APP_PS AGENTVM_APP_SLEEP FAKE_SLEEP_LOG
UUID="$OMC_ACTIONUI_WINDOW_UUID"
CACHE="$TMPDIR/AgentVM/$UUID"

# use_fake  ->  the handlers run the fake through the test seam; use_installed puts the fake at
# ~/.local/bin/agent-vm instead and clears the seam, as a Mac with agent-vm installed has it.
use_fake() {
    AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
    export AGENTVM_APP_AGENT_VM
}
use_installed() {
    unset AGENTVM_APP_AGENT_VM
    /bin/mkdir -p "$HOME/.local/bin"
    /bin/ln -sf "$FAKE_AGENTVM" "$HOME/.local/bin/agent-vm"
}
use_nothing() {
    unset AGENTVM_APP_AGENT_VM
    /bin/rm -f "$HOME/.local/bin/agent-vm"
}

# store <fixture>  ->  the fake answers status with that fixture.
store() {
    /bin/cp "$FIXTURES_AGENTVM/$1" "$FAKE_AGENTVM_DIR/status.json"
}

# open_window  ->  a freshly opened window: the declared controls, nothing recorded yet, then
# the init handler.
open_window() {
    ui_reset
    chains_reset
    omc_control_defaults AgentVM
    : > "$FAKE_SLEEP_LOG"
    omc_run AgentVM.main.init
}

# poll <passes>  ->  the poll loop, ended after that many passes.
poll() {
    ( AGENTVM_APP_POLL_PASSES="$1"; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
}

# select_box <name> / select_image <name>  ->  a click on that row (an empty name deselects).
select_box() {
    omc_table_cell "$MAIN_BOXES_ID" 1 "$1"
    omc_trigger "$MAIN_BOXES_ID"
    omc_run AgentVM.main.box.selected
}
select_image() {
    omc_table_cell "$MAIN_IMAGES_ID" 1 "$1"
    omc_trigger "$MAIN_IMAGES_ID"
    omc_run AgentVM.main.image.selected
}

# table_row <table id> <name>  ->  that table's row whose first cell is name.
table_row() {
    ui_rows "$1" | row_named "$2"
}

# visible <view id>  ->  1 when the handlers left the view shown, 0 when hidden or never shown.
visible() {
    [ "$(ui_visible "$1")" = "1" ] && echo 1 || echo 0
}

# -----------------------------------------------------------------------------------------------
section "opening, with images and boxes: the Status face"
use_fake
fake_reset
store status-variety.json
open_window
check_status "the init handler exits cleanly" 0
check "Status is shown"          "1" "$(visible "$MAIN_STATUS_ID")"
check "Get started is not"       "0" "$(visible "$MAIN_GETSTARTED_ID")"
check "agent-vm was asked: version, doctor, status" \
    "--version doctor --json status --json " "$(fake_log | /usr/bin/tr '\n' ' ')"
check "the header: version and origin, the VMs, the disk" \
    "agent-vm $(lib_value AGENTVM_MIN_VERSION) (test agent-vm at $FAKE_AGENTVM)  -  1 of 2 virtual machines running  -  66 GB free" \
    "$(ui_value "$MAIN_HEADER_ID")"
check "no error note"            "" "$(ui_value "$MAIN_NOTE_ID")"
check "the poll loop is chained" "1" "$(chain_asked AgentVM.main.poll)"
check "nothing selected yet"     "Select a box or an image." "$(ui_value "$MAIN_SELECTED_ID")"

section "the boxes table"
check "one row per box" "3" "$(ui_row_count "$MAIN_BOXES_ID")"
check "a running box: its symbol, project, programs, owner by name, and Stop" \
    "s3${TAB}play.circle.fill${TAB}running${TAB}dev-acp${TAB}allowlist (6)${TAB}/Users/you/src/app, 2 programs, Cadabra${TAB}Stop" \
    "$(table_row "$MAIN_BOXES_ID" s3)"
check "an unresponsive box: a warning, open network, why, and Stop" \
    "try1${TAB}exclamationmark.triangle${TAB}unresponsive${TAB}dev${TAB}open${TAB}no answer from the supervisor within 5 s${TAB}Stop" \
    "$(table_row "$MAIN_BOXES_ID" try1)"
check "a stopped disposable box, and Start" \
    "cadabra-spike${TAB}circle${TAB}stopped${TAB}dev-agents${TAB}allowlist (4)${TAB}disposable${TAB}Start" \
    "$(table_row "$MAIN_BOXES_ID" cadabra-spike)"

section "the images table"
check "one row per image" "7" "$(ui_row_count "$MAIN_IMAGES_ID")"
check "a base image: built from a restore file, needs a guest update" \
    "dev${TAB}checkmark.circle${TAB}ready${TAB}27.0${TAB}restore file${TAB}-${TAB}guest update${TAB}..." \
    "$(table_row "$MAIN_IMAGES_ID" dev)"
check "a derived image: its base, its recipe up to the parenthesis" \
    "dev-acp${TAB}checkmark.circle${TAB}ready${TAB}27.0${TAB}dev-node${TAB}ACP agents: Claude Agent ACP, Codex ACP and opencode${TAB}-${TAB}..." \
    "$(table_row "$MAIN_IMAGES_ID" dev-acp)"
check "two needs, in words" "Full Disk Access, guest update" \
    "$(table_row "$MAIN_IMAGES_ID" dev-node | col 7)"
check "a failed image says why" "exclamationmark.triangle${TAB}failed: the build was canceled" \
    "$(table_row "$MAIN_IMAGES_ID" latest-test | col 2-3)"

section "the installed agent-vm is named in the header"
use_installed
fake_reset
store status-variety.json
open_window
check "in ~/.local/bin" \
    "agent-vm $(lib_value AGENTVM_MIN_VERSION) (in ~/.local/bin)  -  1 of 2 virtual machines running  -  66 GB free" \
    "$(ui_value "$MAIN_HEADER_ID")"

section "a developer override is named in the header"
use_nothing
settings_write "{\"developerAgentVM\": \"$FAKE_AGENTVM\"}"
fake_reset
store status-variety.json
open_window
check "as a developer build, with its path" \
    "agent-vm $(lib_value AGENTVM_MIN_VERSION) (developer build at $FAKE_AGENTVM)" \
    "$(ui_value "$MAIN_HEADER_ID" | /usr/bin/sed 's/  -  .*//')"
settings_clear

# -----------------------------------------------------------------------------------------------
section "agent-vm not installed: Get started, and agent-vm is not run"
use_nothing
fake_reset
open_window
check_status "the init handler exits cleanly" 0
check "Get started is shown" "1" "$(visible "$MAIN_GETSTARTED_ID")"
check "Status is not"        "0" "$(visible "$MAIN_STATUS_ID")"
check "the header says so"   "agent-vm is not installed" "$(ui_value "$MAIN_HEADER_ID")"
check "the first line says where it looked" \
    "agent-vm: agent-vm is not installed: there is nothing at ~/.local/bin/agent-vm." \
    "$(ui_value "$MAIN_GETSTARTED_TEXT_ID" | /usr/bin/head -1)"
check "agent-vm never ran"   "" "$(fake_log)"
check "the poll loop is still chained, to notice an install" "1" "$(chain_asked AgentVM.main.poll)"

section "... and the poll loop notices when it is installed"
use_installed
store status-variety.json
: > "$FAKE_SLEEP_LOG"
poll 1
check "the next pass checks agent-vm again and reads everything" \
    "--version doctor --json status --json " "$(fake_log | /usr/bin/tr '\n' ' ')"
check "and the window moves to Status by itself" "1" "$(visible "$MAIN_STATUS_ID")"

section "an empty store: Get started with what is missing"
use_fake
fake_reset
store status-empty.json
open_window
check "Get started is shown" "1" "$(visible "$MAIN_GETSTARTED_ID")"
check "what exists and what does not" \
    "This Mac can run boxes.|Images: none ready yet.|Boxes: none yet." \
    "$(ui_value "$MAIN_GETSTARTED_TEXT_ID" | /usr/bin/sed -n '2,4p' | /usr/bin/paste -sd '|' -)"

section "images but no box: still Get started"
/usr/bin/jq '.boxes = []' "$FIXTURES_AGENTVM/status.json" > "$FAKE_AGENTVM_DIR/status.json"
open_window
check "Get started is shown" "1" "$(visible "$MAIN_GETSTARTED_ID")"
check "the ready images are counted" "Images: 7 ready." \
    "$(ui_value "$MAIN_GETSTARTED_TEXT_ID" | /usr/bin/sed -n 3p)"

section "a doctor failure: Get started, with doctor's detail"
fake_reset
store status-variety.json
/usr/bin/jq '(.checks[] | select(.name == "virtualization")) |= (.status = "failure" | .detail = "Virtualization reports that this process cannot run virtual machines")' \
    "$FIXTURES_AGENTVM/doctor.json" > "$FAKE_AGENTVM_DIR/doctor.json"
open_window
check "Get started is shown" "1" "$(visible "$MAIN_GETSTARTED_ID")"
check "the failure, named" \
    "This Mac cannot run boxes now: Virtualization reports that this process cannot run virtual machines (virtualization)" \
    "$(ui_value "$MAIN_GETSTARTED_TEXT_ID" | /usr/bin/sed -n 2p)"
/bin/rm -f "$FAKE_AGENTVM_DIR/doctor.json"

section "agent-vm removed while the window is open"
use_installed
fake_reset
store status-variety.json
open_window
printf 'the store is locked by another agent-vm\n' > "$FAKE_AGENTVM_DIR/fail-status"
poll 1
check "a status error first" "the store is locked by another agent-vm" "$(ui_value "$MAIN_NOTE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
use_nothing
poll 1
check "the next pass notices: Get started" "1" "$(visible "$MAIN_GETSTARTED_ID")"
check "  the header says so" "agent-vm is not installed" "$(ui_value "$MAIN_HEADER_ID")"
check "  and the old error is gone" "" "$(ui_value "$MAIN_NOTE_ID")"

section "a broken developer override: no advice about installing"
settings_write "{\"developerAgentVM\": \"$HOME/no-such/agent-vm\"}"
open_window
check "one line, the reason" "1" "$(ui_value "$MAIN_GETSTARTED_TEXT_ID" | /usr/bin/awk 'END { print NR }')"
check "  which names the setting" "1" "$(ui_value "$MAIN_GETSTARTED_TEXT_ID" | /usr/bin/grep -c 'developer agent-vm in Settings')"
settings_clear
use_fake

section "status fails: the note says why, and the rows already shown stay"
fake_reset
store status-variety.json
open_window
printf 'the store is locked by another agent-vm\n' > "$FAKE_AGENTVM_DIR/fail-status"
poll 1
check "agent-vm's message"     "the store is locked by another agent-vm" "$(ui_value "$MAIN_NOTE_ID")"
check "the boxes are still listed" "3" "$(ui_row_count "$MAIN_BOXES_ID")"
check "Status is still shown"  "1" "$(visible "$MAIN_STATUS_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
poll 1
check "the next good answer clears the note" "" "$(ui_value "$MAIN_NOTE_ID")"

# -----------------------------------------------------------------------------------------------
section "one selection across both tables"
fake_reset
store status-variety.json
open_window
select_box s3
check "a running box"            "Selected: box s3 (running)" "$(ui_value "$MAIN_SELECTED_ID")"
check "  its actions"            "1" "$(visible "$MAIN_RUNNING_BOX_ACTIONS_ID")"
check "  not a stopped box's"    "0" "$(visible "$MAIN_STOPPED_BOX_ACTIONS_ID")"
check "  not an image's"         "0" "$(visible "$MAIN_IMAGE_ACTIONS_ID")"
check "  and the images table loses its highlight" "1" "$(ui_calls "${MAIN_IMAGES_ID}${TAB}omc_deselect")"
select_box cadabra-spike
check "a stopped box's actions"  "1" "$(visible "$MAIN_STOPPED_BOX_ACTIONS_ID")"
check "  and not a running one's" "0" "$(visible "$MAIN_RUNNING_BOX_ACTIONS_ID")"
select_image dev-node
check "an image"                 "Selected: image dev-node (ready)" "$(ui_value "$MAIN_SELECTED_ID")"
check "  its actions"            "1" "$(visible "$MAIN_IMAGE_ACTIONS_ID")"
check "  no box's"               "0" "$(visible "$MAIN_STOPPED_BOX_ACTIONS_ID")"
check "  and the boxes table loses its highlight" "1" "$(ui_calls "${MAIN_BOXES_ID}${TAB}omc_deselect")"
select_box ""
check "the boxes table's deselection does not undo the image" "Selected: image dev-node (ready)" "$(ui_value "$MAIN_SELECTED_ID")"
select_image ""
check "deselecting the image clears it" "Select a box or an image." "$(ui_value "$MAIN_SELECTED_ID")"
check "  and every action"       "0" "$(visible "$MAIN_IMAGE_ACTIONS_ID")"
select_box "-rf"
check "a value that is no box name selects nothing" "Select a box or an image." "$(ui_value "$MAIN_SELECTED_ID")"

section "the selection survives a repaint"
select_box try1
poll 1
check "the row is highlighted again, by name" "2" "$(ui_selection "$MAIN_BOXES_ID")"
check "the action row still names it" "Selected: box try1 (unresponsive)" "$(ui_value "$MAIN_SELECTED_ID")"
/usr/bin/jq '.boxes |= map(select(.box.name != "try1"))' "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
poll 1
check "a box that is gone is not selected any more" "Select a box or an image." "$(ui_value "$MAIN_SELECTED_ID")"
check "  and the selection is forgotten" "" "$("$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_selected_$UUID" get)"

# -----------------------------------------------------------------------------------------------
section "the poll loop"
fake_reset
store status-variety.json
open_window
fake_reset
store status-variety.json
: > "$FAKE_SLEEP_LOG"
poll 2
check_status "exits cleanly" 0
check "each pass reads only status" "status --json status --json " "$(fake_log | /usr/bin/tr '\n' ' ')"
check "every 15 seconds when nothing moves" "15 15 " "$(/usr/bin/tr '\n' ' ' < "$FAKE_SLEEP_LOG")"
check "and gives the token back when it ends" "" "$("$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_poll_$UUID" get)"
/usr/bin/jq '(.boxes[] | select(.box.name == "cadabra-spike")).state = "starting"' \
    "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
: > "$FAKE_SLEEP_LOG"
poll 2
check "every 2 seconds once a box is starting" "15 2 " "$(/usr/bin/tr '\n' ' ' < "$FAKE_SLEEP_LOG")"
check "  shown with an hourglass" "hourglass" "$(table_row "$MAIN_BOXES_ID" cadabra-spike | col 2)"

section "the poll loop: a newer loop takes over"
store status-variety.json
fake_reset
store status-variety.json
: > "$FAKE_SLEEP_LOG"
( FAKE_SLEEP_TAKE_TOKEN="poll-newer"; export FAKE_SLEEP_TAKE_TOKEN; poll 3 )
check "the old loop paints nothing more" "" "$(fake_log)"
check "and leaves the newer loop's token" "poll-newer" "$("$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_poll_$UUID" get)"

section "the poll loop: the app is gone"
/usr/bin/true &
dead_pid=$!
wait "$dead_pid"
fake_reset
store status-variety.json
: > "$FAKE_SLEEP_LOG"
( OMC_APP_PROCESS_ID="$dead_pid"; export OMC_APP_PROCESS_ID; poll 3 )
check "no wait, no agent-vm" "" "$(/bin/cat "$FAKE_SLEEP_LOG")$(fake_log)"

# -----------------------------------------------------------------------------------------------
section "activation"
fake_reset
store status-variety.json
open_window
"$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_poll_$UUID" set ""
fake_reset
store status-variety.json
chains_reset
omc_run AgentVM.main.activated
check_status "exits cleanly" 0
check "reads everything again, doctor included" "--version doctor --json status --json " "$(fake_log | /usr/bin/tr '\n' ' ')"
check "starts a poll loop when none runs" "1" "$(chain_asked AgentVM.main.poll)"
# A live process holds the token: this test file itself.
"$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_poll_$UUID" set "poll-$$"
chains_reset
omc_run AgentVM.main.activated
check "and not a second one" "0" "$(chain_asked AgentVM.main.poll)"
/usr/bin/true &
killed_loop=$!
wait "$killed_loop"
"$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_poll_$UUID" set "poll-$killed_loop"
chains_reset
omc_run AgentVM.main.activated
check "but a new one when the loop holding the token was killed" "1" "$(chain_asked AgentVM.main.poll)"

section "closing"
omc_run AgentVM.main.close
check_status "exits cleanly" 0
check "the poll token says closed" "closed" "$("$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_poll_$UUID" get)"
check_absent "the window's cache folder is gone" "$CACHE"
fake_reset
: > "$FAKE_SLEEP_LOG"
poll 3
check "a loop chained before the close does nothing" "" "$(/bin/cat "$FAKE_SLEEP_LOG")$(fake_log)"
check "and does not take the token over" "closed" "$("$OMC_OMC_SUPPORT_PATH/pasteboard" "agentvm_poll_$UUID" get)"
# A handler that was reading agent-vm when the window closed writes its caches after the close
# handler removed them.
store status-variety.json
omc_run AgentVM.main.activated
check_absent "a refresh that ends after the close leaves no cache folder" "$CACHE"

section "no writes to views the window does not have"
check "no undeclared ids"   "" "$(ui_unknown_writes)"
check "no clobbered tables" "" "$(ui_suspect_writes)"
check "no harness errors"   "" "$(ui_errors)"

omctest_end
