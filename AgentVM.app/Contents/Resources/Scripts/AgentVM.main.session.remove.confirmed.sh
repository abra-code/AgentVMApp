#!/bin/sh
# AgentVM.main.session.remove.confirmed.sh
# Remove, in the question of the trash button under the Sessions tab's project cards: the project
# the question named goes from the list, and its sessions are discarded (lib.agentvm.sessions.sh,
# ses_remove).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ses_remove "$window_uuid"
exit 0
