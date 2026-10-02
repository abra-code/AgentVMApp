#!/bin/sh
# AgentVM.main.image.new.sh
# The plus button under the image list, and New Image from This... in the image pane: the New
# Image window opens, or comes to the front. From the pane's button, the selected image is handed
# over as the start, for a window that opens now.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
from=""
if [ "${OMC_ACTIONUI_TRIGGER_VIEW_ID:-}" = "$MAIN_IMAGE_DERIVE_ID" ]; then
    from="$(ui_get image "$window_uuid")"
    [ -n "$from" ] || exit 0
    [ -n "$(main_row "$window_uuid" images "$from")" ] || exit 0
fi
"$pasteboard" "$AGENTVM_NEWIMAGE_FROM_KEY" set "${OMC_APP_PROCESS_ID:-} $from"
ui_item_open newimage window "$OMC_CURRENT_COMMAND_GUID"
exit 0
