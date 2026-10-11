#!/bin/sh
# Tests/65-rename.test.sh - the Rename window: the library's two calls, the Rename buttons beside the
# names in the main window's panes and which boxes and images they are on for, one window at a time and only
# when this run of the app asked for it, what the window refuses itself, a box renamed (what
# reaches agent-vm, the windows of the old name, the main window), agent-vm's refusal, and an
# image renamed, with its boxes following.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json, with the box s3
# stopped; `box rename` and `image rename` change what it answers.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.rename.sh"
[ -n "$RENAME_HEAD_ID" ] && [ -n "$RENAME_WHAT_ID" ] && [ -n "$RENAME_NAME_ID" ] && [ -n "$RENAME_NOTE_ID" ] && [ -n "$RENAME_APPLY_ID" ] \
    && [ -n "$MAIN_BOX_RENAME_ID" ] && [ -n "$MAIN_IMAGE_RENAME_ID" ] && [ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_IMAGES_ID" ] \
    && [ -n "$MAIN_BOX_IMAGE_ID" ] && [ -n "$MAIN_STATUS_ID" ] || {
    printf '65-rename: no view ids imported from the libraries\n' >&2
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
APP_PID="${OMC_APP_PROCESS_ID:?65-rename: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-rename-$$"
OTHER_UUID="OMCTEST-other-rename-$$"
NET_UUID="OMCTEST-rename-network-$$"
UPDATE_UUID="OMCTEST-rename-update-$$"
TAB="$(printf '\t')"

in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

# store <jq filter>  ->  what status answers: the variety with the box s3 stopped, then the filter.
store() {
    /usr/bin/jq '(.boxes[] | select(.box.name == "s3")) |= (.state = "stopped" | .running = false) | '"$1" \
        "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

request()    { "$PB" agentvm_open_request_rename get; }
handed()     { "$PB" agentvm_rename_of get; }
registered() { "$PB" agentvm_window_rename_window get; }
target()     { "$PB" "agentvm_rename_$UUID" get; }
note()       { ui_value "$RENAME_NOTE_ID"; }
closed()     { ui_calls "${1}${TAB}omc_window${TAB}omc_terminate_cancel"; }
renames()    { fake_log | /usr/bin/grep -c ' rename '; }

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

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

# open_rename <box|image> <name> [uuid]  ->  the window opened the way a Rename button opens it: the
# request and what to rename, then the window's init handler, in a window of its own.
open_rename() {
    "$PB" agentvm_open_request_rename set "$APP_PID rename:window"
    "$PB" agentvm_rename_of set "$APP_PID $1:$2"
    in_window "${3:-$UUID}"
    ui_reset
    omc_control_defaults AgentVM.rename
    omc_run AgentVM.rename.init
}

# apply <text>  ->  the text typed into the field, and Rename.
apply() {
    omc_control "$RENAME_NAME_ID" "$1"
    omc_run AgentVM.rename.apply
}

fake_reset
store '.'
"$PB" agentvm_window_rename_window set ""
"$PB" agentvm_open_request_rename set ""
"$PB" agentvm_rename_of set ""

# -----------------------------------------------------------------------------------------------
section "the library: box rename and image rename"
with_fake agentvm_box_rename s3 work
check "a box renamed" "0" "$?"
check "what reaches agent-vm" "box rename s3 work --json" "$(fake_log)"
check "the box is listed by its new name, and its record keeps the old one" "work|s3" \
    "$(/usr/bin/jq -r '.boxes[] | select(.box.name == "work") | "\(.box.name)|\(.box.formerNames | join(","))"' "$FAKE_AGENTVM_DIR/status.json")"
: > "$FAKE_AGENTVM_DIR/log"
with_fake agentvm_box_rename work -x
check "a new name that is no name is refused" "2" "$?"
check "  before agent-vm runs" "" "$(fake_log)"
with_fake agentvm_box_rename "" work
check "  and so is no box" "2" "$?"
with_fake agentvm_image_rename dev-node node
check "an image renamed" "0" "$?"
check "what reaches agent-vm" "image rename dev-node node --json" "$(fake_log)"
check "the images built from it name it by the new name" "dev-acp,dev-agents" \
    "$(/usr/bin/jq -r '[.images[] | select(.derivedFrom.image? == "node") | .name] | join(",")' "$FAKE_AGENTVM_DIR/status.json")"
with_fake agentvm_image_rename node dev
check "a name that is taken: agent-vm refuses" "1" "$?"
check "  in its words" "image dev already exists" "$(with_fake agentvm_last_error 1)"
: > "$FAKE_AGENTVM_DIR/log"
with_fake agentvm_image_rename node "a b"
check "a new name that is no name is refused" "2" "$?"
check "  before agent-vm runs" "" "$(fake_log)"

# -----------------------------------------------------------------------------------------------
section "the Rename buttons beside the names"
fake_reset
store '.'
in_window "$MAIN_UUID"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
check "each is in its pane, right after the name" "321,348|421,437" \
    "$(/usr/bin/jq -r '[.. | objects | select(.type? == "HStack") | [.children[]?.id?] | select(. == [321, 348] or . == [421, 437]) | map(tostring) | join(",")] | join("|")' "$APP_RESOURCES/Base.lproj/AgentVM.json")"
check "each runs its handler, and has the title Rename and a pencil" \
    "AgentVM.main.box.rename|pencil|Rename|AgentVM.main.image.rename|pencil|Rename" \
    "$(/usr/bin/jq -r --argjson box "$MAIN_BOX_RENAME_ID" --argjson image "$MAIN_IMAGE_RENAME_ID" '[.. | objects | select(.id? == $box or .id? == $image) | .properties | "\(.actionID)|\(.systemImage)|\(.title)"] | join("|")' "$APP_RESOURCES/Base.lproj/AgentVM.json")"
select_box s3
check "a stopped box that is kept: on" "1" "$(enabled "$MAIN_BOX_RENAME_ID")"
select_box cadabra-spike
check "a stopped box that is deleted when it stops: off" "0" "$(enabled "$MAIN_BOX_RENAME_ID")"
chains_reset
omc_run AgentVM.main.box.rename
check "  and its handler, however it came to run, opens nothing" "0|" "$(chain_asked AgentVM.rename)|$(handed)"
select_box try1
check "a box that runs: off" "0" "$(enabled "$MAIN_BOX_RENAME_ID")"
omc_run AgentVM.main.box.rename
check "  and its handler opens nothing" "0|" "$(chain_asked AgentVM.rename)|$(handed)"
select_image dev
check "an image nothing holds: on" "1" "$(enabled "$MAIN_IMAGE_RENAME_ID")"
select_box s3
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.rename
check "the box's button asks for the window, with a request of this run and the box, and asks agent-vm nothing" \
    "1|$APP_PID rename:window|$APP_PID box:s3|" "$(chain_asked AgentVM.rename)|$(request)|$(handed)|$(fake_log)"
chains_reset
omc_run AgentVM.main.image.rename
check "the image's button asks for it with the image" "1|$APP_PID image:dev" "$(chain_asked AgentVM.rename)|$(handed)"
"$PB" agentvm_open_request_rename set ""
"$PB" agentvm_rename_of set ""

# -----------------------------------------------------------------------------------------------
section "the window opens"
open_rename box s3
check_status "the init handler exits cleanly" 0
check "takes the request and the box, once" "|" "$(request)|$(handed)"
check "becomes the Rename window, for that box" "$APP_PID $UUID|box:s3" "$(registered)|$(target)"
check "its title, and what it says" "Rename Box|Rename box s3" "$(ui_title)|$(ui_value "$RENAME_HEAD_ID")"
check "what a box keeps" "1" "$(ui_value "$RENAME_WHAT_ID" | /usr/bin/grep -c '^The box keeps what it holds, its network rules and its logs')"
check "the field holds the name as it is" "s3" "$(ui_value "$RENAME_NAME_ID")"
check "the window asked agent-vm nothing" "" "$(fake_log)"
"$PB" agentvm_open_request_rename set "$APP_PID rename:window"
"$PB" agentvm_rename_of set "$APP_PID box:try1"
in_window "$OTHER_UUID"
ui_reset
omc_run AgentVM.rename.init
check "a second window while one is open closes, and the first stays the Rename window" "$APP_PID $UUID|1|" \
    "$(registered)|$(closed "$OTHER_UUID")|$("$PB" "agentvm_rename_$OTHER_UUID" get)"
ui_reset
omc_run AgentVM.rename.init
check "a window nobody of this run asked for closes" "1" "$(closed "$OTHER_UUID")"
"$PB" agentvm_open_request_rename set "$APP_PID rename:window"
ui_reset
omc_run AgentVM.rename.init
check "  and so does one with nothing to rename" "1" "$(closed "$OTHER_UUID")"
"$PB" agentvm_open_request_rename set "$APP_PID rename:window"
"$PB" agentvm_rename_of set "$APP_PID box:-rf"
ui_reset
omc_run AgentVM.rename.init
check "  or with what cannot be a name" "1|" "$(closed "$OTHER_UUID")|$("$PB" "agentvm_rename_$OTHER_UUID" get)"
"$PB" agentvm_open_request_rename set ""
"$PB" agentvm_rename_of set ""

section "a Rename button while the window is open"
in_window "$MAIN_UUID"
chains_reset
omc_run AgentVM.main.box.rename
check "for the same box: the open window comes to the front, and no other is asked for" "1|0" \
    "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")|$(chain_asked AgentVM.rename)"
omc_run AgentVM.main.image.rename
check "for another: the open window closes, is the Rename window no more, and a new one is asked for" "1||1|$APP_PID image:dev" \
    "$(closed "$UUID")|$(registered)|$(chain_asked AgentVM.rename)|$(handed)"
in_window "$UUID"
omc_run AgentVM.rename.close
check "the closed window keeps nothing" "" "$(target)"
"$PB" agentvm_open_request_rename set ""
"$PB" agentvm_rename_of set ""

# -----------------------------------------------------------------------------------------------
section "what the window refuses itself"
open_rename box s3
: > "$FAKE_AGENTVM_DIR/log"
apply ""
check "no name" "Give the box a name.|0" "$(note)|$(renames)"
apply "s3"
check "the name it has" "s3 is its name now.|0" "$(note)|$(renames)"
apply "My Box"
check "what cannot be a name; the rule is in the window, under the field" "\"My Box\" cannot be a name.|0|1" \
    "$(note)|$(renames)|$(/usr/bin/jq -r '[.. | objects | select(.properties?.text? // "" | startswith("Lower-case letters, digits"))] | length' "$APP_RESOURCES/Base.lproj/AgentVM.rename.json")"
apply "-x"
check "nor one agent-vm would read as an option" "1|0" "$(note | /usr/bin/grep -c '^"-x" cannot be a name')|$(renames)"
check "the window stays, and Rename was not turned off" "0|0" "$(closed "$UUID")|$(ui_calls "${UUID}${TAB}${RENAME_APPLY_ID}${TAB}omc_disable")"

section "agent-vm refuses"
alerts_before="$(ui_calls omc_present_alert)"
apply "try1"
check "a name that is taken: asked of agent-vm, its words in an alert, and the main window reads its lists again" "box rename s3 try1 --json status --json|1|Box s3 was not renamed|box try1 already exists" \
    "$(fake_log | /usr/bin/paste -sd ' ' -)|$(( $(ui_calls omc_present_alert) - alerts_before ))|$(ui_alert_title)|$(ui_alert_message)"
check "  the line under the field is clear, the window stays, and Rename can be clicked again" "|0|1|" \
    "$(note)|$(closed "$UUID")|$(enabled "$RENAME_APPLY_ID")|$("$PB" "agentvm_busy_$UUID" get)"
INTERRUPTED='renaming box s3 to work was interrupted; `agent-vm box rename s3 work` finishes it'
printf '%s\n' "$INTERRUPTED" > "$FAKE_AGENTVM_DIR/fail-box-rename"
apply "work"
check "a long refusal is shown whole" "$INTERRUPTED" "$(ui_alert_message)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-box-rename"
"$PB" "agentvm_busy_$UUID" set "click-$$"
: > "$FAKE_AGENTVM_DIR/log"
apply "work"
check "a second Rename while the first is worked on asks agent-vm nothing" "" "$(fake_log)"
"$PB" "agentvm_busy_$UUID" set ""

# -----------------------------------------------------------------------------------------------
section "a box renamed"
"$PB" agentvm_window_network_s3 set "$APP_PID $NET_UUID"
in_window "$MAIN_UUID"
select_box s3
in_window "$UUID"
: > "$FAKE_AGENTVM_DIR/log"
alerts_before="$(ui_calls omc_present_alert)"
apply "work"
check_status "the handler exits cleanly" 0
check "agent-vm renames it, and then the lists are read" "box rename s3 work --json|status --json" \
    "$(fake_log | /usr/bin/sed -n '1,2p' | /usr/bin/paste -sd '|' -)"
check "the box's network window, opened under the old name, closes" "1" "$(closed "$NET_UUID")"
check "the main window selects the box under its new name, on the Boxes tab" "work|0" \
    "$("$PB" "agentvm_box_$MAIN_UUID" get)|$(ui_value "$MAIN_STATUS_ID" "$MAIN_UUID")"
check "  and measures it by that name" "1" "$(fake_log | /usr/bin/grep -c '^box info work --json$')"
check "the window closes, with no alert" "1|0" "$(closed "$UUID")|$(( $(ui_calls omc_present_alert) - alerts_before ))"
omc_run AgentVM.rename.close
check "  and is the Rename window no more" "|" "$(registered)|$(target)"
"$PB" agentvm_window_network_s3 set ""

# -----------------------------------------------------------------------------------------------
section "an image renamed"
fake_reset
store '.'
in_window "$MAIN_UUID"
omc_run AgentVM.main.activated
select_image dev-acp
"$PB" agentvm_window_update_dev-acp set "$APP_PID $UPDATE_UUID"
open_rename image dev-acp
check "its title, what it says, and its name in the field" "Rename Image|Rename image dev-acp|dev-acp" \
    "$(ui_title)|$(ui_value "$RENAME_HEAD_ID")|$(ui_value "$RENAME_NAME_ID")"
check "what follows an image" "1" "$(ui_value "$RENAME_WHAT_ID" | /usr/bin/grep -c '^The boxes made from the image and the images built from it follow at once')"
apply ""
check "no name" "Give the image a name." "$(note)"
alerts_before="$(ui_calls omc_present_alert)"
apply "dev"
check "a name that is taken: agent-vm's words" "Image dev-acp was not renamed|image dev already exists" "$(ui_alert_title)|$(ui_alert_message)"
: > "$FAKE_AGENTVM_DIR/log"
apply "acp"
check "agent-vm renames it" "image rename dev-acp acp --json" "$(fake_log | /usr/bin/sed -n '1p')"
check "the image's update window, opened under the old name, closes" "1" "$(closed "$UPDATE_UUID")"
check "the main window selects the image under its new name, on the Images tab" "acp|1" \
    "$("$PB" "agentvm_image_$MAIN_UUID" get)|$(ui_value "$MAIN_STATUS_ID" "$MAIN_UUID")"
check "the window closes" "1" "$(closed "$UUID")"
omc_run AgentVM.rename.close
in_window "$MAIN_UUID"
select_box s3
check "a box made from it names its image by the new name" "1" "$(ui_value "$MAIN_BOX_IMAGE_ID" | /usr/bin/grep -c '^acp ')"
"$PB" agentvm_window_update_dev-acp set ""

section "Cancel"
open_rename box s3
: > "$FAKE_AGENTVM_DIR/log"
omc_control "$RENAME_NAME_ID" "other"
omc_run AgentVM.rename.cancel
check "the window closes, and agent-vm is asked nothing" "1|" "$(closed "$UUID")|$(fake_log)"
omc_run AgentVM.rename.close
in_window "$OTHER_UUID"
ui_reset
omc_run AgentVM.rename.cancel
omc_control "$RENAME_NAME_ID" "other"
omc_run AgentVM.rename.apply
check "Cancel and Rename in a window that is no Rename window do nothing" "0|" "$(closed "$OTHER_UUID")|$(fake_log)"

check "no harness errors" "" "$(ui_errors)"

omctest_end
