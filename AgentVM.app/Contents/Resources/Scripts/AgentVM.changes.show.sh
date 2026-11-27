#!/bin/sh
# AgentVM.changes.show.sh
# Show in Finder in the Session Changes window: the selected entry, in the project or, for one
# the agent deleted, in the snapshot.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.changes.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
chg_is "$window_uuid" || exit 0
chg_show "$window_uuid"
exit 0
