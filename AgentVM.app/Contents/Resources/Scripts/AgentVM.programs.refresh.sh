#!/bin/sh
# AgentVM.programs.refresh.sh
# Refresh, in a box's programs window: the box's state and its last programs read again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.programs.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
prog_refresh "$window_uuid"
exit 0
