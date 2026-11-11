#!/bin/sh
# AgentVM.recreate.image.sh
# A row of the image table was selected or deselected: the row is kept as the image chosen, and
# the line under the table and Recreate follow.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.recreate.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
recreate_is "$window_uuid" || exit 0
picked="$(newbox_picked "$window_uuid" "${OMC_ACTIONUI_TABLE_5203_COLUMN_5_VALUE:-}" "${OMC_ACTIONUI_TABLE_5203_COLUMN_1_VALUE:-}")"
ui_set picked "$window_uuid" "$picked"
recreate_paint_choice "$window_uuid"
recreate_tidy "$window_uuid"
exit 0
