#!/bin/sh
# AgentVM.main.poll.sh
# The main window's poll loop (lib.agentvm.main.sh, main_poll), chained by the init and activate
# handlers. Runs until the window closes, a newer loop takes over, or the app quits.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
main_poll "$window_uuid"
