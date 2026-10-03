#!/bin/sh
# AgentVM.main.box.delete.sh
# Delete... in the bar under the box list: asks first, saying what deleting frees, about the box as it is
# now (status is read and the box measured again; a box that started meanwhile is not asked
# about). The box asked about is kept as the window's pending delete: the confirmation's handler
# deletes that one, whatever the selection is by then. Delete in the question runs
# AgentVM.main.box.delete.confirmed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
ui_set box_delete "$window_uuid" ""
main_read_status "$window_uuid"
read_status=$?
# Not when status failed: the rows would be old ones (the note under the lists says why). A box
# agent-vm could not measure is still asked about, without the space it frees.
if [ "$read_status" -ne 0 ]; then
    main_paint "$window_uuid"
    exit 0
fi
main_box_askable "$window_uuid" "$name" delete && main_read_info "$window_uuid" box "$name"
main_paint "$window_uuid"
main_box_askable "$window_uuid" "$name" delete || exit 0
ui_set box_delete "$window_uuid" "$name"
"$dialog" "$window_uuid" omc_window omc_present_alert "Delete box $name?" \
    "$(main_box_delete_question "$window_uuid" "$name")" \
    "Cancel:cancel:" "Delete:destructive:AgentVM.main.box.delete.confirmed"
