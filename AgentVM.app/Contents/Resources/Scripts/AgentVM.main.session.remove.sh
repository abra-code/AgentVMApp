#!/bin/sh
# AgentVM.main.session.remove.sh
# The trash button under the Sessions tab's project cards: the question before taking the selected
# project off the list, discarding its sessions (lib.agentvm.sessions.sh, ses_remove_ask).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ses_remove_ask "$window_uuid"
exit 0
