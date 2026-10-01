#!/bin/sh
# AgentVM.main.box.recreate.confirmed.sh
# Recreate, in the question AgentVM.main.box.recreate asked: agent-vm makes the box asked about
# again from its image, and the lists are read again, after a failure too: agent-vm can delete the
# old box and then fail to make the new one (its message gives the command that does), and the
# list must not show a box that is gone. A recreated box is measured again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box_recreate "$window_uuid")"
# Read once: a second confirmation, or one without a question, recreates nothing.
ui_set box_recreate "$window_uuid" ""
[ -n "$name" ] && agentvm_valid_name "$name" || exit 0
agentvm_box_recreate "$name"
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "Box $name was not recreated" "$(agentvm_last_error "$status")"
fi
main_refresh "$window_uuid" status
[ "$(ui_get box "$window_uuid")" = "$name" ] || exit 0
[ -n "$(main_row "$window_uuid" boxes "$name")" ] || exit 0
main_read_info "$window_uuid" box "$name"
main_paint_box_detail "$window_uuid"
