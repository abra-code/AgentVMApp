#!/bin/sh
# AgentVM.recreate.init.sh
# The Recreate window opens (INIT_SUBCOMMAND_ID): it becomes the one such window, takes the box the
# main window handed over, reads agent-vm's lists, and chooses the box's own image when it is
# ready. A window opened without a request of this run of the app (a URL naming the command
# itself), without a box, or while another one is open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.recreate.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set recreate "$window_uuid" ""
ui_set picked "$window_uuid" ""
requested="$(ui_item_request recreate)"
box="$(recreate_take)"
if [ "$requested" != "window" ] || [ -z "$box" ]; then
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window recreate window)"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set recreate "$window_uuid" "$box"
ui_item_claim recreate window "$window_uuid"
"$dialog" "$window_uuid" omc_window "Recreate Box"
recreate_read "$window_uuid"
recreate_is "$window_uuid" || exit 0
# The box's own image, when it is listed (ready); recreate_paint drops one that is not.
ui_set picked "$window_uuid" "$(recreate_own_image "$window_uuid")"
recreate_paint "$window_uuid"
recreate_tidy "$window_uuid"
exit 0
