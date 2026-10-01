#!/bin/sh
# AgentVM.network.public.sh
# "Any public host name" in the Settings tab was clicked: agent-vm's rule "public" is flipped in
# the rules wanted.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(ui_get box "$window_uuid")"
[ -n "$box" ] && agentvm_valid_name "$box" || exit 0
net_flip_rule "$window_uuid" "$box" public
net_paint "$window_uuid"
