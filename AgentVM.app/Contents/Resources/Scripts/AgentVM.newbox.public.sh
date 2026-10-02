#!/bin/sh
# AgentVM.newbox.public.sh
# "Any public host name" in the network step was clicked: agent-vm's rule "public" is flipped.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
[ "$(newbox_step "$window_uuid")" = "2" ] || exit 0
newbox_flip_rule "$window_uuid" public
newbox_paint_network "$window_uuid"
exit 0
