#!/bin/sh
# AgentVM.keys.selected.sh
# A row of the Agent Keys window's table was selected, or the selection cleared: that key, of
# that agent, is the one Store and Remove... work on, if agent-vm listed it; the part under the
# table says what it is.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.keys.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
keys_is "$window_uuid" || exit 0
name="$OMC_ACTIONUI_TABLE_4001_COLUMN_2_VALUE"
agent="$OMC_ACTIONUI_TABLE_4001_COLUMN_5_VALUE"
if [ -n "$(keys_row "$window_uuid" "$name" "$agent")" ]; then
    ui_set key "$window_uuid" "$name"
    ui_set keyagent "$window_uuid" "$agent"
else
    ui_set key "$window_uuid" ""
    ui_set keyagent "$window_uuid" ""
fi
"$dialog" "$window_uuid" "$KEYS_NOTE_ID" ""
keys_paint_detail "$window_uuid"
exit 0
