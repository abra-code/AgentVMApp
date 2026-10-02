#!/bin/sh
# AgentVM.main.box.new.sh
# The plus button under the box list, and New Box from It... in the image pane: the New Box
# window opens, or comes to the front. From the pane's button, the selected image is handed over,
# for a window that opens now.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
from=""
if [ "${OMC_ACTIONUI_TRIGGER_VIEW_ID:-}" = "$MAIN_IMAGE_BOX_ID" ]; then
    from="$(ui_get image "$window_uuid")"
    [ -n "$from" ] || exit 0
    [ -n "$(main_row "$window_uuid" images "$from")" ] || exit 0
fi
"$pasteboard" "$AGENTVM_NEWBOX_FROM_KEY" set "${OMC_APP_PROCESS_ID:-} $from"
ui_item_open newbox window "$OMC_CURRENT_COMMAND_GUID"
exit 0
