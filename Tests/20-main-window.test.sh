#!/bin/sh
# Tests/20-main-window.test.sh - the main window: which face it shows, the box and image lists
# of cards, the detail pane of each list's selection, Settings, and the poll loop that keeps
# them current.
#
# agent-vm is the fake (fixtures/agentvm/), the process list is fake_ps.sh (pid 812 is Cadabra),
# and the poll loop's wait is fake_sleep.sh, which records the seconds instead of waiting.
# AGENTVM_APP_POLL_PASSES ends each loop after a pass or two. Dates are shown in the Mac's time
# zone, so the file runs in UTC.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_IMAGES_ID" ] && [ -n "$MAIN_GETSTARTED_ID" ] && [ -n "$MAIN_BOX_DETAIL_ID" ] || {
    printf '20-main-window: no view ids imported from lib.agentvm.main.sh\n' >&2
    exit 1
}

AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
TZ=UTC
export AGENTVM_APP_PS AGENTVM_APP_SLEEP FAKE_SLEEP_LOG TZ
UUID="$OMC_ACTIONUI_WINDOW_UUID"
CACHE="$TMPDIR/AgentVM/$UUID"
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
VERSION="$(lib_value AGENTVM_MIN_VERSION)"
# 2026-09-29T14:02:10Z, when box s3 of status-variety.json started, as seconds since 1970.
S3_STARTED=1790690530

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

# select_box <name> / select_image <name>  ->  a click on that card (an empty name deselects).
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

# card <list id> <name>  ->  that list's row whose first cell is name.
card() {
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
check "the poll loop is chained" "1" "$(chain_asked AgentVM.main.poll)"
check "the box list's footer: the virtual machines" "1 of 2 virtual machines running" "$(ui_value "$MAIN_BOXES_FOOTER_ID")"
check "the image list's footer: how many" "7 images" "$(ui_value "$MAIN_IMAGES_FOOTER_ID")"
check "no error note"            "" "$(ui_value "$MAIN_BOXES_NOTE_ID")$(ui_value "$MAIN_IMAGES_NOTE_ID")"
check "no box selected yet: the placeholder"    "1 0" "$(visible "$MAIN_BOX_NONE_ID") $(visible "$MAIN_BOX_DETAIL_ID")"
check "no image selected yet: the placeholder"  "1 0" "$(visible "$MAIN_IMAGE_NONE_ID") $(visible "$MAIN_IMAGE_DETAIL_ID")"

section "Settings"
check "agent-vm's version"       "$VERSION" "$(ui_value "$MAIN_AGENTVM_VERSION_ID")"
check "the test agent-vm is named as such" "$FAKE_AGENTVM (test agent-vm)" "$(ui_value "$MAIN_AGENTVM_LOCATION_ID")"
check "the virtual machines, without repeating the label" "1 of 2 running" "$(ui_value "$MAIN_VMS_ID")"
check "the free disk space"      "104 GB free" "$(ui_value "$MAIN_DISK_ID")"

section "the box cards"
check "one card per box" "3" "$(ui_row_count "$MAIN_BOXES_ID")"
check "six fields on every card" "6" "$(ui_rows "$MAIN_BOXES_ID" | field_count)"
check "a running box: a play symbol, its image and macOS, green" \
    "s3${TAB}play.circle.fill${TAB}dev-acp - macOS 27.0${TAB}${TAB}${TAB}#2E9E4F" \
    "$(card "$MAIN_BOXES_ID" s3)"
check "an unresponsive box: its own symbol, orange" \
    "try1${TAB}exclamationmark.circle.fill${TAB}dev - macOS 27.0${TAB}${TAB}${TAB}#E8861A" \
    "$(card "$MAIN_BOXES_ID" try1)"
check "a stopped box: a stop symbol, gray" \
    "cadabra-spike${TAB}stop.circle${TAB}dev-agents - macOS 27.0${TAB}${TAB}${TAB}#8E8E93" \
    "$(card "$MAIN_BOXES_ID" cadabra-spike)"

section "the image cards"
check "one card per image" "7" "$(ui_row_count "$MAIN_IMAGES_ID")"
check "seven fields on every card" "7" "$(ui_rows "$MAIN_IMAGES_ID" | field_count)"
check "a base image: macOS, a restore file, maintenance, one box" \
    "dev${TAB}square.stack.3d.up.fill${TAB}macOS 27.0 - from a restore file${TAB}Needs maintenance${TAB}exclamationmark.triangle.fill${TAB}#5E5CE6${TAB}1" \
    "$(card "$MAIN_IMAGES_ID" dev)"
check "a derived image: what it was built from, nothing to do" \
    "dev-acp${TAB}square.stack.3d.up.fill${TAB}macOS 27.0 - from dev-node${TAB}${TAB}${TAB}#5E5CE6${TAB}1" \
    "$(card "$MAIN_IMAGES_ID" dev-acp)"
check "no box made from it: 0" "0" "$(card "$MAIN_IMAGES_ID" dev-node | col 7)"
check "a failed image: red, and says so" \
    "latest-test${TAB}xmark.octagon.fill${TAB}Failed - macOS 27.0${TAB}${TAB}${TAB}#D93025${TAB}0" \
    "$(card "$MAIN_IMAGES_ID" latest-test)"
/usr/bin/jq '(.images[] | select(.name == "dev-xcode-ios")).state = "provisioning"' \
    "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
poll 1
check "an image being built: a hammer, blue" \
    "dev-xcode-ios${TAB}hammer.fill${TAB}Building - macOS 27.0" \
    "$(card "$MAIN_IMAGES_ID" dev-xcode-ios | col 1-3)"
store status-variety.json

section "the installed agent-vm, in Settings"
use_installed
fake_reset
store status-variety.json
open_window
check "its path" "~/.local/bin/agent-vm" "$(ui_value "$MAIN_AGENTVM_LOCATION_ID")"

section "a developer override, in Settings"
use_nothing
settings_write "{\"developerAgentVM\": \"$FAKE_AGENTVM\"}"
fake_reset
store status-variety.json
open_window
check "its path, named as a developer build" "$FAKE_AGENTVM (developer build)" "$(ui_value "$MAIN_AGENTVM_LOCATION_ID")"
settings_clear

# -----------------------------------------------------------------------------------------------
section "agent-vm not installed: Get started, and agent-vm is not run"
use_nothing
fake_reset
open_window
check_status "the init handler exits cleanly" 0
check "Get started is shown" "1" "$(visible "$MAIN_GETSTARTED_ID")"
check "Status is not"        "0" "$(visible "$MAIN_STATUS_ID")"
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
check "  with the installed version in Settings" "$VERSION" "$(ui_value "$MAIN_AGENTVM_VERSION_ID")"

section "an empty store: Get started with what is missing"
use_fake
fake_reset
store status-empty.json
open_window
check "Get started is shown" "1" "$(visible "$MAIN_GETSTARTED_ID")"
check "the version and where it is" \
    "agent-vm: $VERSION (test agent-vm at $FAKE_AGENTVM)" \
    "$(ui_value "$MAIN_GETSTARTED_TEXT_ID" | /usr/bin/head -1)"
check "what exists and what does not" \
    "This Mac can run boxes.|Images: none ready yet.|Boxes: none yet." \
    "$(ui_value "$MAIN_GETSTARTED_TEXT_ID" | /usr/bin/sed -n '2,4p' | /usr/bin/paste -sd '|' -)"

section "images but no box: still Get started"
/usr/bin/jq '.boxes = []' "$FIXTURES_AGENTVM/status.json" > "$FAKE_AGENTVM_DIR/status.json"
open_window
check "Get started is shown" "1" "$(visible "$MAIN_GETSTARTED_ID")"
check "the ready images are counted" "Images: 6 ready." \
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

section "status fails at the first read: Get started says why"
fake_reset
# A new window has no cache; this file's one window has the last section's rows.
/bin/rm -rf "$CACHE"
printf 'the store is locked by another agent-vm\n' > "$FAKE_AGENTVM_DIR/fail-status"
open_window
check "Get started is shown, with nothing listed" "1" "$(visible "$MAIN_GETSTARTED_ID")"
check "  and agent-vm's message" "the store is locked by another agent-vm" "$(ui_value "$MAIN_GETSTARTED_NOTE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"

section "agent-vm removed while the window is open"
use_installed
fake_reset
store status-variety.json
open_window
printf 'the store is locked by another agent-vm\n' > "$FAKE_AGENTVM_DIR/fail-status"
poll 1
check "a status error first, under both lists" \
    "the store is locked by another agent-vm|the store is locked by another agent-vm" \
    "$(ui_value "$MAIN_BOXES_NOTE_ID")|$(ui_value "$MAIN_IMAGES_NOTE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
use_nothing
poll 1
check "the next pass notices: Get started" "1" "$(visible "$MAIN_GETSTARTED_ID")"
check "  saying agent-vm is not installed" "agent-vm: agent-vm is not installed: there is nothing at ~/.local/bin/agent-vm." \
    "$(ui_value "$MAIN_GETSTARTED_TEXT_ID" | /usr/bin/head -1)"
check "  and the old error is gone" "" "$(ui_value "$MAIN_GETSTARTED_NOTE_ID")"

section "a broken developer override: no advice about installing"
settings_write "{\"developerAgentVM\": \"$HOME/no-such/agent-vm\"}"
open_window
check "one line, the reason" "1" "$(ui_value "$MAIN_GETSTARTED_TEXT_ID" | /usr/bin/awk 'END { print NR }')"
check "  which names the setting" "1" "$(ui_value "$MAIN_GETSTARTED_TEXT_ID" | /usr/bin/grep -c 'developer agent-vm in Settings')"
settings_clear
use_fake

section "status fails: the note says why, and the cards already shown stay"
fake_reset
store status-variety.json
open_window
printf 'the store is locked by another agent-vm\n' > "$FAKE_AGENTVM_DIR/fail-status"
poll 1
check "agent-vm's message"     "the store is locked by another agent-vm" "$(ui_value "$MAIN_BOXES_NOTE_ID")"
check "the boxes are still listed" "3" "$(ui_row_count "$MAIN_BOXES_ID")"
check "Status is still shown"  "1" "$(visible "$MAIN_STATUS_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
poll 1
check "the next good answer clears the note" "" "$(ui_value "$MAIN_BOXES_NOTE_ID")$(ui_value "$MAIN_IMAGES_NOTE_ID")"

# -----------------------------------------------------------------------------------------------
section "a running box's details"
AGENTVM_APP_NOW=$((S3_STARTED + 3900))
export AGENTVM_APP_NOW
fake_reset
store status-variety.json
open_window
select_box s3
check_status "the handler exits cleanly" 0
check "the detail pane replaces the placeholder" "0 1" "$(visible "$MAIN_BOX_NONE_ID") $(visible "$MAIN_BOX_DETAIL_ID")"
check "its name"               "s3" "$(ui_value "$MAIN_BOX_NAME_ID")"
check "how long it has run"    "Running for 1 h 5 min" "$(ui_value "$MAIN_BOX_STATE_ID")"
check "nothing to maintain"    "" "$(ui_value "$MAIN_BOX_MAINTENANCE_ID")"
check "a running box's actions" "1 0" "$(visible "$MAIN_RUNNING_BOX_ACTIONS_ID") $(visible "$MAIN_STOPPED_BOX_ACTIONS_ID")"
check "its image, with the macOS it was made with" "dev-acp (macOS 27.0, 26A428)" "$(ui_value "$MAIN_BOX_IMAGE_ID")"
check "the network"            "allowlist, 6 rules" "$(ui_value "$MAIN_BOX_NETWORK_ID")"
check "the project folder"     "/Users/you/src/app" "$(ui_value "$MAIN_BOX_PROJECT_ID")"
check "the programs in it"     "2" "$(ui_value "$MAIN_BOX_PROGRAMS_ID")"
check "the program that owns it, by name" "Cadabra (812)" "$(ui_value "$MAIN_BOX_OWNER_ID")"
check "processors and memory"  "4 CPUs, 8 GB" "$(ui_value "$MAIN_BOX_HARDWARE_ID")"
check "kept"                   "yes, until it is deleted" "$(ui_value "$MAIN_BOX_KEPT_ID")"
check "the day it was made"    "Sep 26, 2026" "$(ui_value "$MAIN_BOX_CREATED_ID")"
check "its folder"             "/Users/you/Library/Application Support/agent-vm/Boxes/s3" "$(ui_value "$MAIN_BOX_FOLDER_ID")"

section "an unresponsive box's details"
select_box try1
check "not responding, and why" "Not responding: no answer from the supervisor within 5 s" "$(ui_value "$MAIN_BOX_STATE_ID")"
check "  a running box's actions, since it may still hold its VM" "1 0" "$(visible "$MAIN_RUNNING_BOX_ACTIONS_ID") $(visible "$MAIN_STOPPED_BOX_ACTIONS_ID")"
check "  no network record: open" "open" "$(ui_value "$MAIN_BOX_NETWORK_ID")"
check "  no owner"             "nobody: it runs until it is stopped" "$(ui_value "$MAIN_BOX_OWNER_ID")"
check "  no program"           "none" "$(ui_value "$MAIN_BOX_PROGRAMS_ID")"

section "a stopped disposable box's details"
select_box cadabra-spike
check "stopped"                "Stopped" "$(ui_value "$MAIN_BOX_STATE_ID")"
check "  a stopped box's actions" "0 1" "$(visible "$MAIN_RUNNING_BOX_ACTIONS_ID") $(visible "$MAIN_STOPPED_BOX_ACTIONS_ID")"
check "  not kept"             "no: it is deleted when it stops" "$(ui_value "$MAIN_BOX_KEPT_ID")"
check "  no owner while stopped" "-" "$(ui_value "$MAIN_BOX_OWNER_ID")"
check "  no project"           "none" "$(ui_value "$MAIN_BOX_PROJECT_ID")"
check "  4 GB"                 "4 CPUs, 4 GB" "$(ui_value "$MAIN_BOX_HARDWARE_ID")"

section "an image's details"
select_image dev-node
check_status "the handler exits cleanly" 0
check "the detail pane replaces the placeholder" "0 1" "$(visible "$MAIN_IMAGE_NONE_ID") $(visible "$MAIN_IMAGE_DETAIL_ID")"
check "its name"               "dev-node" "$(ui_value "$MAIN_IMAGE_NAME_ID")"
check "ready"                  "Ready" "$(ui_value "$MAIN_IMAGE_STATE_ID")"
check "what it needs, in full" \
    "Needs maintenance|Needs a guest update for agent-vm $VERSION.|Needs Full Disk Access, or programs in its boxes cannot open Desktop, Documents or Downloads." \
    "$(ui_value "$MAIN_IMAGE_MAINTENANCE_ID" | /usr/bin/paste -sd '|' -)"
check "macOS, with the build"  "27.0 (26A428)" "$(ui_value "$MAIN_IMAGE_MACOS_ID")"
check "what it was built from" "dev" "$(ui_value "$MAIN_IMAGE_BASE_ID")"
check "its tools"              "Homebrew and Node" "$(ui_value "$MAIN_IMAGE_TOOLS_ID")"
check "the guest daemon"       "0.2.18" "$(ui_value "$MAIN_IMAGE_GUEST_ID")"
check "the day it was made"    "Sep 23, 2026" "$(ui_value "$MAIN_IMAGE_CREATED_ID")"
check "no box made from it"    "none" "$(ui_value "$MAIN_IMAGE_BOXES_ID")"
check "the images built from it" "dev-acp and dev-agents" "$(ui_value "$MAIN_IMAGE_DERIVED_ID")"
check "its folder"             "/Users/you/Library/Application Support/agent-vm/Images/dev-node" "$(ui_value "$MAIN_IMAGE_FOLDER_ID")"
check "the box list keeps its own selection" "cadabra-spike" "$("$PB" "agentvm_box_$UUID" get)"
select_image dev
check "a base image: a restore file, macOS only" "a macOS restore file|macOS only" \
    "$(ui_value "$MAIN_IMAGE_BASE_ID")|$(ui_value "$MAIN_IMAGE_TOOLS_ID")"
check "  the box made from it, with its state" "try1 (unresponsive)" "$(ui_value "$MAIN_IMAGE_BOXES_ID")"
select_image latest-test
check "a failed image says why" "Failed: the build was canceled." "$(ui_value "$MAIN_IMAGE_STATE_ID")"
check "  and has nothing to maintain" "" "$(ui_value "$MAIN_IMAGE_MAINTENANCE_ID")"

section "deselecting"
select_image ""
check "no image: the placeholder again" "1 0" "$(visible "$MAIN_IMAGE_NONE_ID") $(visible "$MAIN_IMAGE_DETAIL_ID")"
check "  and the selection is forgotten" "" "$("$PB" "agentvm_image_$UUID" get)"
check "  the box list's is not" "cadabra-spike" "$("$PB" "agentvm_box_$UUID" get)"
select_box "-rf"
check "a value that is no box name selects nothing" "1 0" "$(visible "$MAIN_BOX_NONE_ID") $(visible "$MAIN_BOX_DETAIL_ID")"
check "  and is not kept" "" "$("$PB" "agentvm_box_$UUID" get)"

section "the selection survives a repaint"
select_box try1
select_image dev-acp
poll 1
check "the box card is highlighted again, by name" "2" "$(ui_selection "$MAIN_BOXES_ID")"
check "  and so is the image card" "1" "$(ui_selection "$MAIN_IMAGES_ID")"
check "the box's details are painted again" "try1" "$(ui_value "$MAIN_BOX_NAME_ID")"
/usr/bin/jq '(.boxes[] | select(.box.name == "try1")) |= (.state = "stopped" | del(.statusError))' \
    "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
poll 1
check "  from the new rows" "Stopped" "$(ui_value "$MAIN_BOX_STATE_ID")"
/usr/bin/jq '.boxes |= map(select(.box.name != "try1"))' "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
poll 1
check "a box that is gone: the placeholder" "1 0" "$(visible "$MAIN_BOX_NONE_ID") $(visible "$MAIN_BOX_DETAIL_ID")"
check "  and the selection is forgotten" "" "$("$PB" "agentvm_box_$UUID" get)"
check "  the image stays selected" "dev-acp" "$("$PB" "agentvm_image_$UUID" get)"
unset AGENTVM_APP_NOW

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
check "and gives the token back when it ends" "" "$("$PB" "agentvm_poll_$UUID" get)"
/usr/bin/jq '(.boxes[] | select(.box.name == "cadabra-spike")).state = "starting"' \
    "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
: > "$FAKE_SLEEP_LOG"
poll 2
check "every 2 seconds once a box is starting" "15 2 " "$(/usr/bin/tr '\n' ' ' < "$FAKE_SLEEP_LOG")"
check "  shown with a dotted circle, blue" "circle.dotted${TAB}#0A84FF" "$(card "$MAIN_BOXES_ID" cadabra-spike | col 2,6)"

section "the poll loop: a newer loop takes over"
store status-variety.json
fake_reset
store status-variety.json
: > "$FAKE_SLEEP_LOG"
( FAKE_SLEEP_TAKE_TOKEN="poll-newer"; export FAKE_SLEEP_TAKE_TOKEN; poll 3 )
check "the old loop paints nothing more" "" "$(fake_log)"
check "and leaves the newer loop's token" "poll-newer" "$("$PB" "agentvm_poll_$UUID" get)"

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
"$PB" "agentvm_poll_$UUID" set ""
fake_reset
store status-variety.json
chains_reset
omc_run AgentVM.main.activated
check_status "exits cleanly" 0
check "reads everything again, doctor included" "--version doctor --json status --json " "$(fake_log | /usr/bin/tr '\n' ' ')"
check "starts a poll loop when none runs" "1" "$(chain_asked AgentVM.main.poll)"
# A live process holds the token: this test file itself.
"$PB" "agentvm_poll_$UUID" set "poll-$$"
chains_reset
omc_run AgentVM.main.activated
check "and not a second one" "0" "$(chain_asked AgentVM.main.poll)"
/usr/bin/true &
killed_loop=$!
wait "$killed_loop"
"$PB" "agentvm_poll_$UUID" set "poll-$killed_loop"
chains_reset
omc_run AgentVM.main.activated
check "but a new one when the loop holding the token was killed" "1" "$(chain_asked AgentVM.main.poll)"

section "closing"
select_box s3
select_image dev
omc_run AgentVM.main.close
check_status "exits cleanly" 0
check "the poll token says closed" "closed" "$("$PB" "agentvm_poll_$UUID" get)"
check "both selections are forgotten" "" "$("$PB" "agentvm_box_$UUID" get)$("$PB" "agentvm_image_$UUID" get)"
check_absent "the window's cache folder is gone" "$CACHE"
fake_reset
: > "$FAKE_SLEEP_LOG"
poll 3
check "a loop chained before the close does nothing" "" "$(/bin/cat "$FAKE_SLEEP_LOG")$(fake_log)"
check "and does not take the token over" "closed" "$("$PB" "agentvm_poll_$UUID" get)"
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
