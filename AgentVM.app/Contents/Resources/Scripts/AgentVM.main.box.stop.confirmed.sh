#!/bin/sh
# AgentVM.main.box.stop.confirmed.sh
# Stop, in the question AgentVM.main.box.stop asked: stops the box asked about, whatever the
# selection is by then, if it still runs and no job holds it.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"
# For the one-click-at-a-time mark (wizard_enter).
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box_stop "$window_uuid")"
# Read once: a second confirmation, or one without a question, stops nothing.
ui_set box_stop "$window_uuid" ""
[ -n "$name" ] && agentvm_valid_name "$name" || exit 0
# One click at a time, as in AgentVM.main.box.stop.
wizard_enter "$window_uuid" || exit 0
main_read_status "$window_uuid"
read_status=$?
main_paint "$window_uuid"
[ "$read_status" -eq 0 ] || exit 0
main_box_askable "$window_uuid" "$name" stop || exit 0
main_box_job "$window_uuid" "$name" stop "$OMC_CURRENT_COMMAND_GUID"
exit 0
