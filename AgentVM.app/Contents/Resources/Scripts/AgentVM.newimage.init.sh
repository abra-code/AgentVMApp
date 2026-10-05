#!/bin/sh
# AgentVM.newimage.init.sh
# The New Image window opens (INIT_SUBCOMMAND_ID): it becomes the one New Image window, reads
# agent-vm (which one runs, its recipes, the images, the restore files), fills the start table,
# and shows step 1; or step 2, with the start chosen, when New Image from This... handed an image
# over that a build can start from. A window opened without a request of this run of the app (a
# URL naming the command itself), or while another New Image window is open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
for key in newimage step start ticks name cpus memory disk auto_name auto_disk busy taken delete; do
    ui_set "$key" "$window_uuid" ""
done
requested="$(ui_item_request newimage)"
from="$("$pasteboard" "$AGENTVM_NEWIMAGE_FROM_KEY" get)"
"$pasteboard" "$AGENTVM_NEWIMAGE_FROM_KEY" set ""
if [ "$requested" != "window" ]; then
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window newimage window)"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set newimage "$window_uuid" "1"
ui_item_claim newimage window "$window_uuid"
"$dialog" "$window_uuid" omc_window "New Image"
newimage_read "$window_uuid" full
# The window closed while agent-vm was read: nothing is painted or kept, and the cache folder the
# reading made again goes.
if ! newimage_is "$window_uuid"; then
    ui_cache_clear "$window_uuid"
    exit 0
fi
# The image handed over, when this run of the app named it and a build can start from it.
step=1
if [ -n "${OMC_APP_PROCESS_ID:-}" ] && [ "${from%% *}" = "$OMC_APP_PROCESS_ID" ] && agentvm_valid_name "${from#* }"; then
    ui_set start "$window_uuid" "image ${from#* }"
    if [ -z "$(newimage_start_blocker "$window_uuid")" ]; then
        step=2
    else
        ui_set start "$window_uuid" ""
    fi
fi
newimage_paint_sources "$window_uuid"
newimage_show "$window_uuid" "$step"
exit 0
