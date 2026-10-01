#!/bin/sh
# AgentVM.main.box.delete.confirmed.sh
# Delete, in the question AgentVM.main.box.delete asked: agent-vm deletes the box asked about,
# its network and programs windows close, and the lists are read again. When agent-vm refuses
# (the box was started meanwhile), its reason is shown and the box stays selected.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box_delete "$window_uuid")"
# Read once: a second confirmation, or one without a question, deletes nothing.
ui_set box_delete "$window_uuid" ""
[ -n "$name" ] && agentvm_valid_name "$name" || exit 0
agentvm_box_delete "$name"
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "Box $name was not deleted" "$(agentvm_last_error "$status")"
    main_refresh "$window_uuid" status
    exit 0
fi
# A deleted box has nothing to show in a window of its own.
ui_item_close network "$name"
ui_item_close programs "$name"
selected="$(ui_get box "$window_uuid")"
[ "$selected" = "$name" ] && ui_set box "$window_uuid" ""
main_refresh "$window_uuid" status
