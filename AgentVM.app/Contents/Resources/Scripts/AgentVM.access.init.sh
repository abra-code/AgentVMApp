#!/bin/sh
# AgentVM.access.init.sh
# An image's Full Disk Access guide opens (INIT_SUBCOMMAND_ID): takes the image's name from the
# open request, becomes that image's guide, reads status, paints, and starts the poll loop when a
# setup job already holds the image. A window opened without a request of this run of the app (a
# URL naming the command itself), or for an image whose guide is already open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.access.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set image "$window_uuid" ""
ui_set job "$window_uuid" ""
ui_set poll "$window_uuid" ""
image="$(ui_item_request access)"
if [ -z "$image" ]; then
    "$dialog" "$window_uuid" "$ACCESS_NOTE_ID" "No image was named for this window."
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window access "$image")"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set image "$window_uuid" "$image"
ui_item_claim access "$image" "$window_uuid"
"$dialog" "$window_uuid" omc_window "Full Disk Access for image $image"
access_refresh "$window_uuid" full
access_moving "$window_uuid" && "$next_command" "$OMC_CURRENT_COMMAND_GUID" "AgentVM.access.poll"
exit 0
