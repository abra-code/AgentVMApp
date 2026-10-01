#!/bin/sh
# AgentVM.network.discard.sh
# Discard Changes, in the Settings tab: the rules wanted are the box's rules as they apply now.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(ui_get box "$window_uuid")"
[ -n "$box" ] && agentvm_valid_name "$box" || exit 0
current="$(net_file "$window_uuid" "$box" current)"
[ -f "$current" ] || exit 0
/bin/cat "$current" | ui_store "$(net_file "$window_uuid" "$box" desired)"
net_paint "$window_uuid"
