#!/bin/sh
# AgentVM.image.init.sh
# An image's window opens (INIT_SUBCOMMAND_ID): takes the image's name from the open request,
# becomes that image's window, and reads and paints it. A window opened without a request of this
# run of the app (a URL naming the command itself), or for an image whose window is already open,
# closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.image.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set item "$window_uuid" ""
name="$(ui_item_request image)"
if [ -z "$name" ]; then
    "$dialog" "$window_uuid" "$IMAGE_FACTS_ID" "No image was named for this window."
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window image "$name")"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set item "$window_uuid" "$name"
ui_item_claim image "$name" "$window_uuid"
image_refresh "$window_uuid"
exit 0
