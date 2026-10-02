#!/bin/sh
# AgentVM.newbox.init.sh
# The New Box window opens (INIT_SUBCOMMAND_ID): it becomes the one New Box window, reads agent-vm
# (which one runs, its agents and packs, the images and boxes), fills the image table, and shows
# step 1; or step 2, with the image chosen, when New Box from It... handed over an image a box
# can be made from. A window opened without a request of this run of the app (a URL naming the
# command itself), or while another New Box window is open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
for key in $NBOX_KEYS; do
    ui_set "$key" "$window_uuid" ""
done
requested="$(ui_item_request newbox)"
from="$("$pasteboard" "$AGENTVM_NEWBOX_FROM_KEY" get)"
"$pasteboard" "$AGENTVM_NEWBOX_FROM_KEY" set ""
if [ "$requested" != "window" ]; then
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window newbox window)"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set newbox "$window_uuid" "1"
ui_item_claim newbox window "$window_uuid"
"$dialog" "$window_uuid" omc_window "New Box"
newbox_read "$window_uuid" full
# The window closed while agent-vm was read: nothing is painted or kept, and the cache folder the
# reading made again goes.
if ! newbox_is "$window_uuid"; then
    ui_cache_clear "$window_uuid"
    exit 0
fi
# The image handed over, when this run of the app named it and a box can be made from it.
step=1
if [ -n "${OMC_APP_PROCESS_ID:-}" ] && [ "${from%% *}" = "$OMC_APP_PROCESS_ID" ] && agentvm_valid_name "${from#* }"; then
    if [ -z "$(newbox_image_blocker "$window_uuid" "${from#* }")" ]; then
        ui_set picked "$window_uuid" "${from#* }"
        newbox_set_image "$window_uuid" "${from#* }"
        step=2
    fi
fi
newbox_show "$window_uuid" "$step"
exit 0
