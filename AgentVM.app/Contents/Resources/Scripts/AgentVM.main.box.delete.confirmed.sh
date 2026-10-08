#!/bin/sh
# AgentVM.main.box.delete.confirmed.sh
# Delete, in the question AgentVM.main.box.delete asked: agent-vm deletes the box asked about,
# its network and programs windows close, and the lists are read again. When agent-vm kept the
# box's logs, a toast says so, and for how long; when it could not keep some or all of them, an
# alert says why, since the question had said they would be kept. When agent-vm refuses (the box
# was started meanwhile), its reason is shown and the box stays selected.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box_delete "$window_uuid")"
# Read once: a second confirmation, or one without a question, deletes nothing.
ui_set box_delete "$window_uuid" ""
[ -n "$name" ] && agentvm_valid_name "$name" || exit 0
answer="$(agentvm_box_delete "$name")"
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
# What became of the box's logs (agentvm_box_delete), said after the reading, which has how long
# the store keeps a deleted box's logs.
kept="$(printf '%s\n' "$answer" | /usr/bin/cut -f1)"
problem="$(printf '%s\n' "$answer" | /usr/bin/cut -f2)"
if [ -n "$problem" ] && [ "$problem" != "-" ]; then
    main_alert "$window_uuid" "Box $name is deleted, and not all of its logs were kept" "$problem"
elif [ -n "$kept" ] && [ "$kept" != "-" ]; then
    "$dialog" "$window_uuid" omc_window omc_present_toast "$(main_box_deleted_text "$window_uuid" "$name")" "$MAIN_TOAST_SECONDS"
fi
