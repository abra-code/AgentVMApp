#!/bin/sh
# AgentVM.main.session.older.30.sh
# "Older Than 30 Days", in the question of Discard Older Than...: every ended and undone session
# that ended 30 days ago or earlier is discarded (lib.agentvm.sessions.sh, ses_older).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ses_older "$window_uuid" 30
exit 0
