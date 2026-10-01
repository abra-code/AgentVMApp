#!/bin/sh
# AgentVM.network.remove.sh
# Remove, under the Settings tab's other hosts: the selected rule leaves the rules wanted.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(ui_get box "$window_uuid")"
[ -n "$box" ] && agentvm_valid_name "$box" || exit 0
rule="$OMC_ACTIONUI_TABLE_604_COLUMN_1_VALUE"
[ -n "$rule" ] || exit 0
net_remove_rule "$window_uuid" "$box" "$rule"
net_paint "$window_uuid"
