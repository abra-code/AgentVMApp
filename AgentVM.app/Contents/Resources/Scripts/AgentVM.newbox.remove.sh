#!/bin/sh
# AgentVM.newbox.remove.sh
# Remove, under the network step's other hosts: the selected rule leaves the rules.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
[ "$(newbox_step "$window_uuid")" = "2" ] || exit 0
rule="${OMC_ACTIONUI_TABLE_2066_COLUMN_1_VALUE:-}"
[ -n "$rule" ] || exit 0
newbox_remove_rule "$window_uuid" "$rule"
newbox_paint_network "$window_uuid"
exit 0
