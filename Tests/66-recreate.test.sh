#!/bin/sh
# Tests/66-recreate.test.sh - the Recreate window: one window at a time and only when this run of
# the app asked for it, what it says (what goes, the logs agent-vm keeps), the images it lists and
# which one it chooses (the box's own when it is ready; none, and why, when it was deleted or is
# not ready), another image chosen, what stands in the way at Recreate (the box started, the image
# chosen went), Recreate (what reaches agent-vm, the main window, the window closing), agent-vm's
# refusal, activation, and Cancel.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json, with cadabra-spike made a
# kept box (stopped, made from dev-agents); `box recreate --image` makes the box name the image.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.recreate.sh"
[ -n "$RECREATE_HEAD_ID" ] && [ -n "$RECREATE_WHAT_ID" ] && [ -n "$RECREATE_IMAGES_ID" ] && [ -n "$RECREATE_NOTE_ID" ] \
    && [ -n "$RECREATE_APPLY_ID" ] && [ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_BOX_IMAGE_ID" ] || {
    printf '66-recreate: no view ids imported from the libraries\n' >&2
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
APP_PID="${OMC_APP_PROCESS_ID:?66-recreate: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-recreate-$$"
OTHER_UUID="OMCTEST-other-recreate-$$"
TAB="$(printf '\t')"
BOX=cadabra-spike
KEPT='(.boxes[] | select(.box.name == "cadabra-spike")).box.disposable = false'
WHAT="The box is made again from the image chosen below, as the image is now, with the same name, processors, memory and network rules. Everything installed or saved in the box, logins included, is deleted."

in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

# store [jq filter]  ->  what status answers: the variety with cadabra-spike kept, then the filter.
store() {
    /usr/bin/jq "$KEPT | ${1:-.}" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

request()    { "$PB" agentvm_open_request_recreate get; }
handed()     { "$PB" agentvm_recreate_of get; }
registered() { "$PB" agentvm_window_recreate_window get; }
target()     { "$PB" "agentvm_recreate_$UUID" get; }
picked()     { "$PB" "agentvm_picked_$UUID" get; }
note()       { ui_value "$RECREATE_NOTE_ID"; }
note_color() { ui_prop "$RECREATE_NOTE_ID" foregroundStyle; }
closed()     { ui_calls "${1}${TAB}omc_window${TAB}omc_terminate_cancel"; }
recreates()  { fake_log | /usr/bin/grep -c '^box recreate'; }

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

# listed  ->  the names in the image table, comma-joined.
listed() {
    ui_rows "$RECREATE_IMAGES_ID" | /usr/bin/cut -f1 | /usr/bin/paste -sd ',' -
}

# selected  ->  the name of the selected row of the image table, or nothing.
selected() {
    local _index="$(ui_selection "$RECREATE_IMAGES_ID")"
    [ -n "$_index" ] || return 0
    ui_rows "$RECREATE_IMAGES_ID" | /usr/bin/sed -n "$(( _index + 1 ))p" | /usr/bin/cut -f1
}

# choose <image>  ->  a click on that row of the image table (an empty name deselects).
choose() {
    omc_table_cell "$RECREATE_IMAGES_ID" 1 "$1"
    omc_table_cell "$RECREATE_IMAGES_ID" 5 "$1"
    omc_trigger "$RECREATE_IMAGES_ID"
    omc_run AgentVM.recreate.image
}

select_box() {
    omc_table_cell "$MAIN_BOXES_ID" 1 "$1"
    omc_trigger "$MAIN_BOXES_ID"
    omc_run AgentVM.main.box.selected
}

# open_recreate <box> [uuid]  ->  the window opened the way Recreate in the box pane opens it: the
# request and the box, then the window's init handler, in a window of its own.
open_recreate() {
    "$PB" agentvm_open_request_recreate set "$APP_PID recreate:window"
    "$PB" agentvm_recreate_of set "$APP_PID $1"
    in_window "${2:-$UUID}"
    ui_reset
    omc_control_defaults AgentVM.recreate
    omc_run AgentVM.recreate.init
}

# close_recreate  ->  the window's close handler, as the engine runs it once the window is gone.
close_recreate() {
    in_window "$UUID"
    omc_run AgentVM.recreate.close
}

fake_reset
store
"$PB" agentvm_window_recreate_window set ""
"$PB" agentvm_open_request_recreate set ""
"$PB" agentvm_recreate_of set ""
in_window "$MAIN_UUID"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
select_box "$BOX"

# -----------------------------------------------------------------------------------------------
section "the window opens"
: > "$FAKE_AGENTVM_DIR/log"
open_recreate "$BOX"
check_status "the init handler exits cleanly" 0
check "takes the request and the box, once" "|" "$(request)|$(handed)"
check "becomes the Recreate window, for that box" "$APP_PID $UUID|$BOX" "$(registered)|$(target)"
check "its title and head" "Recreate Box|Recreate box $BOX" "$(ui_title)|$(ui_value "$RECREATE_HEAD_ID")"
check "what goes, as the question said it" "$WHAT This cannot be undone." "$(ui_value "$RECREATE_WHAT_ID")"
check "reads agent-vm's lists, and nothing else" "status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "lists the ready images, as New Box does (not the failed one)" "dev,dev-acp,dev-agents,dev-node,dev-xcode,dev-xcode-ios" "$(listed)"
check "  each with its system, what it holds and its state, and its name as the row's key" "5" \
    "$(ui_rows "$RECREATE_IMAGES_ID" | /usr/bin/awk -F'\t' '$1 == "dev-agents" { print NF }')"
check "chooses the box's own image" "dev-agents|dev-agents" "$(picked)|$(selected)"
check "  and says so, plainly" "Image dev-agents is the one the box was made from.|secondary" "$(note)|$(note_color)"
check "Recreate is on" "1" "$(enabled "$RECREATE_APPLY_ID")"

"$PB" agentvm_open_request_recreate set "$APP_PID recreate:window"
"$PB" agentvm_recreate_of set "$APP_PID try1"
in_window "$OTHER_UUID"
ui_reset
omc_run AgentVM.recreate.init
check "a second window while one is open closes, and the first stays the Recreate window" "$APP_PID $UUID|1|" \
    "$(registered)|$(closed "$OTHER_UUID")|$("$PB" "agentvm_recreate_$OTHER_UUID" get)"
ui_reset
omc_run AgentVM.recreate.init
check "a window nobody of this run asked for closes" "1" "$(closed "$OTHER_UUID")"
"$PB" agentvm_open_request_recreate set "$APP_PID recreate:window"
"$PB" agentvm_recreate_of set "$APP_PID -rf"
ui_reset
omc_run AgentVM.recreate.init
check "  and so does one for what cannot be a name" "1|" "$(closed "$OTHER_UUID")|$("$PB" "agentvm_recreate_$OTHER_UUID" get)"
"$PB" agentvm_open_request_recreate set ""
"$PB" agentvm_recreate_of set ""

section "Recreate in the box pane while the window is open"
in_window "$MAIN_UUID"
chains_reset
omc_run AgentVM.main.box.recreate
check "for the same box: the open window comes to the front, and no other is asked for" "1|0" \
    "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")|$(chain_asked AgentVM.recreate)"
in_window "$UUID"

# -----------------------------------------------------------------------------------------------
section "another image chosen"
choose dev
check_status "the handler exits cleanly" 0
check "kept as the image chosen" "dev" "$(picked)"
check "the line under the table says it is another than the box's own" \
    "The box was made from image dev-agents, and is made from image dev now.|secondary|1" "$(note)|$(note_color)|$(enabled "$RECREATE_APPLY_ID")"
choose ""
check "none chosen: Recreate is off, and the line says to choose" "|Choose the image the box is made from.|orange|0" \
    "$(picked)|$(note)|$(note_color)|$(enabled "$RECREATE_APPLY_ID")"
choose dev-agents
check "its own again" "Image dev-agents is the one the box was made from.|1" "$(note)|$(enabled "$RECREATE_APPLY_ID")"

section "activation reads the lists again"
choose dev-xcode-ios
store 'del(.images[] | select(.name == "dev-xcode-ios"))'
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.recreate.activated
check "status is read again" "status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "an image deleted meanwhile is listed no more" "dev,dev-acp,dev-agents,dev-node,dev-xcode" "$(listed)"
check "  and, chosen, is chosen no more: the row goes, the line says to choose" "||0" "$(picked)|$(selected)|$(enabled "$RECREATE_APPLY_ID")"
choose dev-acp
store
omc_run AgentVM.recreate.activated
check "an image chosen that is still listed stays chosen" "dev-acp|dev-acp" "$(picked)|$(selected)"
omc_run AgentVM.recreate.cancel
close_recreate

# -----------------------------------------------------------------------------------------------
section "the box's own image was deleted"
store 'del(.images[] | select(.name == "dev-agents"))'
open_recreate "$BOX"
check "nothing is chosen, and no row is selected" "|" "$(picked)|$(selected)"
check "the line says the image was deleted, in orange, and Recreate is off" \
    "Image dev-agents, which the box was made from, was deleted. Choose another image.|orange|0" \
    "$(note)|$(note_color)|$(enabled "$RECREATE_APPLY_ID")"
choose dev
check "another image chosen: Recreate is on" "The box was made from image dev-agents, and is made from image dev now.|1" \
    "$(note)|$(enabled "$RECREATE_APPLY_ID")"
omc_run AgentVM.recreate.cancel
close_recreate

section "the box's own image is not ready"
store '(.images[] | select(.name == "dev-agents")).state = "provisioning"'
open_recreate "$BOX"
check "not listed, nothing chosen, and the line says why" \
    "0||Image dev-agents, which the box was made from, is not ready. Choose another image, or wait until it is ready.|0" \
    "$(listed | /usr/bin/tr ',' '\n' | /usr/bin/grep -c '^dev-agents$')|$(picked)|$(note)|$(enabled "$RECREATE_APPLY_ID")"
omc_run AgentVM.recreate.cancel
close_recreate

# -----------------------------------------------------------------------------------------------
section "what stands in the way at Recreate"
store
open_recreate "$BOX"
store '(.boxes[] | select(.box.name == "cadabra-spike")).state = "running"'
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.recreate.apply
check_status "the handler exits cleanly" 0
check "the box started meanwhile: the lists are read, nothing is recreated" "status --json|0" "$(fake_log | /usr/bin/paste -sd '|' -)|$(recreates)"
check "  the line says why, and Recreate is off; the window stays" \
    "Box $BOX can be recreated once it is stopped and nothing else is changing it.|0|0" "$(note)|$(enabled "$RECREATE_APPLY_ID")|$(closed "$UUID")"
store 'del(.boxes[] | select(.box.name == "cadabra-spike"))'
omc_run AgentVM.recreate.apply
check "the box was deleted meanwhile" "Box $BOX is not there any more.|0" "$(note)|$(recreates)"
store
choose dev-node
store 'del(.images[] | select(.name == "dev-node"))'
omc_run AgentVM.recreate.apply
check "the image chosen was deleted meanwhile: chosen no more, nothing recreated" "|Choose the image the box is made from.|0" "$(picked)|$(note)|$(recreates)"
store '(.images[] | select(.name == "dev-node")).updating = true'
omc_run AgentVM.recreate.activated
choose dev-node
check "an image another command is changing: said, and Recreate is off" \
    "Another command is changing image dev-node. A box can be made from it when that has ended.|0" "$(note)|$(enabled "$RECREATE_APPLY_ID")"
store
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-status"
choose dev
omc_run AgentVM.recreate.apply
check "agent-vm cannot be read: said, and nothing recreated" "agent-vm could not be read: the store is locked|0" "$(note)|$(recreates)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
"$PB" "agentvm_busy_$UUID" set "click-$$"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.recreate.apply
check "a second Recreate while the first is worked on asks agent-vm nothing" "" "$(fake_log)"
"$PB" "agentvm_busy_$UUID" set ""

section "agent-vm refuses"
REFUSAL='deleted the old box but could not make the new one; run agent-vm box create cadabra-spike --image dev'
printf '%s\n' "$REFUSAL" > "$FAKE_AGENTVM_DIR/fail-box-recreate"
alerts_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.recreate.apply
check_status "the handler exits cleanly" 0
check "asked of agent-vm with the image chosen" "box recreate $BOX --image dev --json" "$(fake_log | /usr/bin/grep '^box recreate')"
check "its words, whole, in an alert" "Box $BOX was not recreated|$REFUSAL" "$(ui_alert_title)|$(ui_alert_message)"
check "  the main window reads its lists again, and the window stays with Recreate on" "1|0|1" \
    "$(( $(fake_log | /usr/bin/grep -c '^status --json$') >= 3 ))|$(closed "$UUID")|$(enabled "$RECREATE_APPLY_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-box-recreate"

section "a box recreated from another image"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.recreate.apply
check_status "the handler exits cleanly" 0
check "the lists are read, agent-vm recreates it from the image chosen, the main window reads its lists and measures the box" \
    "status --json|box recreate $BOX --image dev --json|status --json|box info $BOX --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "the window closes" "1" "$(closed "$UUID")"
close_recreate
check "  and is the Recreate window no more" "||" "$(registered)|$(target)|$(picked)"
check "the box pane names the new image" "1" "$(ui_value "$MAIN_BOX_IMAGE_ID" "$MAIN_UUID" | /usr/bin/grep -c '^dev ')"

section "a box recreated from its own image"
store
open_recreate "$BOX"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.recreate.apply
check "agent-vm is given the image all the same: what is asked is what the window showed" \
    "box recreate $BOX --image dev-agents --json" "$(fake_log | /usr/bin/grep '^box recreate')"
close_recreate

section "Recreate takes the row its click carried"
store
open_recreate "$BOX"
# A row clicked just before Recreate, whose own handler has not kept it yet.
omc_table_cell "$RECREATE_IMAGES_ID" 1 dev
omc_table_cell "$RECREATE_IMAGES_ID" 5 dev
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.recreate.apply
check "the image of the row the window showed is asked, not the one kept before" \
    "box recreate $BOX --image dev --json" "$(fake_log | /usr/bin/grep '^box recreate')"
close_recreate

section "the window closed while agent-vm was read"
# An agent-vm that, the first time status is asked, does what closing the window does first.
CLOSE_MARK="$OMCTEST_WORK/recreate-closed-once"
CLOSING_AGENTVM="$OMCTEST_WORK/closing_agent_vm"
/bin/cat > "$CLOSING_AGENTVM" <<'TOOL'
#!/bin/sh
if [ "$1" = "status" ] && [ ! -e "$CLOSE_MARK" ]; then
    : > "$CLOSE_MARK"
    /bin/sh "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/AgentVM.recreate.close.sh"
fi
exec "$REAL_AGENTVM" "$@"
TOOL
/bin/chmod +x "$CLOSING_AGENTVM"
store
for handler in AgentVM.recreate.activated AgentVM.recreate.apply; do
    open_recreate "$BOX"
    /bin/rm -f "$CLOSE_MARK"
    : > "$FAKE_AGENTVM_DIR/log"
    ( AGENTVM_APP_AGENT_VM="$CLOSING_AGENTVM"; REAL_AGENTVM="$FAKE_AGENTVM"
      export AGENTVM_APP_AGENT_VM REAL_AGENTVM CLOSE_MARK
      omc_run "$handler" )
    check "$handler: the window closed, nothing is recreated, and no cache folder or image chosen is left" "closed|0|no|" \
        "$([ -e "$CLOSE_MARK" ] && echo closed)|$(recreates)|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)|$(picked)"
done

section "the window closed while it was painted"
# The window's tools, with one that does what closing the window does before the first write of
# the text of what goes: the painting that follows reads the cache, which makes its folder again.
REAL_TOOLS="$OMC_OMC_SUPPORT_PATH"
CLOSING_TOOLS="$OMCTEST_WORK/recreate_closing_tools"
/bin/mkdir -p "$CLOSING_TOOLS"
/bin/cat > "$CLOSING_TOOLS/closing_tool" <<'TOOL'
#!/bin/sh
tool="${0##*/}"
case "$tool $*" in
    $CLOSE_BEFORE)
        if [ ! -e "$CLOSE_MARK" ]; then
            : > "$CLOSE_MARK"
            OMC_OMC_SUPPORT_PATH="$REAL_TOOLS" /bin/sh "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/AgentVM.recreate.close.sh"
        fi ;;
esac
exec "$REAL_TOOLS/$tool" "$@"
TOOL
/bin/chmod +x "$CLOSING_TOOLS/closing_tool"
for tool in "$REAL_TOOLS"/*; do
    /bin/ln -sf "$tool" "$CLOSING_TOOLS/${tool##*/}"
done
/bin/rm -f "$CLOSING_TOOLS/omc_dialog_control"
/bin/cp "$CLOSING_TOOLS/closing_tool" "$CLOSING_TOOLS/omc_dialog_control"
for handler in AgentVM.recreate.init AgentVM.recreate.activated; do
    open_recreate "$BOX"
    if [ "$handler" = "AgentVM.recreate.init" ]; then
        "$PB" agentvm_open_request_recreate set "$APP_PID recreate:window"
        "$PB" agentvm_recreate_of set "$APP_PID $BOX"
        omc_run AgentVM.recreate.close
    fi
    /bin/rm -f "$CLOSE_MARK"
    ( CLOSE_BEFORE="omc_dialog_control $UUID $RECREATE_WHAT_ID *"; OMC_OMC_SUPPORT_PATH="$CLOSING_TOOLS"
      export CLOSE_BEFORE CLOSE_MARK REAL_TOOLS OMC_OMC_SUPPORT_PATH
      omc_run "$handler" )
    check "$handler: the window closed, and no cache folder or image chosen is left" "closed|no|" \
        "$([ -e "$CLOSE_MARK" ] && echo closed)|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)|$(picked)"
done

# -----------------------------------------------------------------------------------------------
section "the logs agent-vm keeps"
box_folder="$OMCTEST_WORK/Boxes/$BOX"
/bin/mkdir -p "$box_folder"
: > "$box_folder/supervisor.log"
store "(.boxes[] | select(.box.name == \"$BOX\")).path = \"$box_folder\" | .keptLogs = {count: 0, bytes: 0, holdDays: 30, directory: \"/x/Logs\"}"
open_recreate "$BOX"
check "a box that has logs: the window says they are kept, and for how long" "$WHAT Its logs are kept for 30 days. This cannot be undone." \
    "$(ui_value "$RECREATE_WHAT_ID")"
omc_run AgentVM.recreate.cancel
close_recreate
/bin/rm -f "$box_folder/supervisor.log"
open_recreate "$BOX"
check "a box that has logged nothing: nothing is promised" "$WHAT This cannot be undone." "$(ui_value "$RECREATE_WHAT_ID")"
omc_run AgentVM.recreate.cancel
close_recreate

# -----------------------------------------------------------------------------------------------
section "Cancel"
store
open_recreate "$BOX"
choose dev
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.recreate.cancel
check "the window closes, and agent-vm is asked nothing" "1|" "$(closed "$UUID")|$(fake_log)"
close_recreate
check "  the closed window keeps nothing" "||" "$(registered)|$(target)|$(picked)"
in_window "$OTHER_UUID"
ui_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.recreate.cancel
omc_run AgentVM.recreate.apply
omc_run AgentVM.recreate.activated
check "a window that is not the Recreate window: Cancel, Recreate and activation do nothing" "0|" "$(closed "$OTHER_UUID")|$(fake_log)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
