#!/bin/sh
# AgentVM.main.box.recreate.sh
# Recreate... in the box detail pane: asks first, about the box as it is now (status is read
# again; a box that started meanwhile, or whose image is gone, is not asked about). The box asked
# about is kept as the window's pending recreate: the confirmation's handler recreates that one,
# whatever the selection is by then. Recreate in the question runs
# AgentVM.main.box.recreate.confirmed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
ui_set box_recreate "$window_uuid" ""
main_read_status "$window_uuid"
read_status=$?
main_paint "$window_uuid"
# Not when status failed: the rows would be old ones (the note under the lists says why).
[ "$read_status" -eq 0 ] || exit 0
main_box_askable "$window_uuid" "$name" recreate || exit 0
ui_set box_recreate "$window_uuid" "$name"
"$dialog" "$window_uuid" omc_window omc_present_alert "Recreate box $name?" \
    "$(main_box_recreate_question "$window_uuid" "$name")" \
    "Cancel:cancel:" "Recreate:destructive:AgentVM.main.box.recreate.confirmed"
