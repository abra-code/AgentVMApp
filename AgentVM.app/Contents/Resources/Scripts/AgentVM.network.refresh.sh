#!/bin/sh
# AgentVM.network.refresh.sh
# Refresh, in the Activity tab: the box's state, its rules and its last connections read again.
# Edits not applied yet stay.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
net_refresh "$window_uuid"
exit 0
