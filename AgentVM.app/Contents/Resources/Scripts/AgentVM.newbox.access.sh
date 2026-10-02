#!/bin/sh
# AgentVM.newbox.access.sh
# Set Up..., under the image table: brings the picked image's Full Disk Access guide to the
# front, or opens one. The guide says what to do and asks; nothing is started here. Coming back
# to this window reads the images again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
[ "$(newbox_step "$window_uuid")" = "1" ] || exit 0
picked="$(ui_get picked "$window_uuid")"
agentvm_valid_name "$picked" || exit 0
[ -z "$(newbox_image_blocker "$window_uuid" "$picked")" ] || exit 0
ui_item_open access "$picked" "$OMC_CURRENT_COMMAND_GUID"
exit 0
