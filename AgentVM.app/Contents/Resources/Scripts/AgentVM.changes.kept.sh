#!/bin/sh
# AgentVM.changes.kept.sh
# Show Kept Versions in the Session Changes window: the session's folder, where undo moved what
# the agent left in the entries it put back.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.changes.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
chg_is "$window_uuid" || exit 0
chg_kept "$window_uuid"
exit 0
