#!/bin/sh
# AgentVM.newbox.image.sh
# A row of the image table was selected or deselected: the row is kept as the one picked, the line
# under the table says what a box made from it gets, and Set Up... is on for an image without
# Full Disk Access.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
[ "$(newbox_step "$window_uuid")" = "1" ] || exit 0
picked="$(newbox_picked "$window_uuid" "${OMC_ACTIONUI_TABLE_2051_COLUMN_5_VALUE:-}" "${OMC_ACTIONUI_TABLE_2051_COLUMN_1_VALUE:-}")"
ui_set picked "$window_uuid" "$picked"
newbox_paint_selection "$window_uuid" "$picked"
exit 0
