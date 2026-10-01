#!/bin/sh
# AgentVM.update.init.sh
# An image's update window opens (INIT_SUBCOMMAND_ID): takes the image's name from the open
# request, becomes that image's update window, reads status, ticks what is known to need
# updating (once agent-vm could be read: update_first_choices), and paints. A window opened
# without a request of this run of the app (a URL naming the command itself), or for an image
# whose update window is already open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.update.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set image "$window_uuid" ""
ui_set choices "$window_uuid" ""
image="$(ui_item_request update)"
if [ -z "$image" ]; then
    "$dialog" "$window_uuid" "$UPDATE_NOTE_ID" "No image was named for this window."
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window update "$image")"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set image "$window_uuid" "$image"
ui_item_claim update "$image" "$window_uuid"
"$dialog" "$window_uuid" omc_window "Update image $image"
update_read "$window_uuid" full
update_first_choices "$window_uuid"
update_paint "$window_uuid" toggles
exit 0
