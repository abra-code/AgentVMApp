#!/bin/sh
# AgentVM.network.connection.selected.sh
# A row of the Activity tab's connections was selected or deselected: Allow Selected Host... is
# on for a refused host a rule can be made for, while the box's mode is allowlist (net_allowable).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
rule="$(net_allowable "$window_uuid" "$OMC_ACTIONUI_TABLE_613_COLUMN_1_VALUE" "$OMC_ACTIONUI_TABLE_613_COLUMN_2_VALUE" \
    "$OMC_ACTIONUI_TABLE_613_COLUMN_6_VALUE" "$OMC_ACTIONUI_TABLE_613_COLUMN_7_VALUE")"
allow=0
[ -n "$rule" ] && allow=1
ui_enable "$window_uuid" "$NET_ALLOW_ID" "$allow"
