#!/bin/sh
# AgentVM.changes.refresh.sh
# Compare Again in the Session Changes window: the project is compared with the session's
# snapshot again (an agent may still be changing it).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.changes.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
chg_is "$window_uuid" || exit 0
# One click at a time: agent-vm compares for seconds on a large project.
wizard_enter "$window_uuid" || exit 0
chg_refresh "$window_uuid"
exit 0
