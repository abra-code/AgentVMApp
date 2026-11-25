#!/bin/sh
# AgentVM.main.session.nudge.dismiss.sh
# Not Now, in the banner below the main window's tabs: hidden until the sessions hold 10 GB more
# that can be freed (lib.agentvm.sessions.sh, "The banner below the tabs").

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ses_nudge_dismiss "$window_uuid"
exit 0
