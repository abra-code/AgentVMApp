#!/bin/sh
# AgentVM.main.session.older.sh
# Discard Older Than..., under the Sessions tab's cards: the question with the ages offered, each
# with how many sessions ended that long ago and what discarding them frees
# (lib.agentvm.sessions.sh, ses_older_ask).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ses_older_ask "$window_uuid"
exit 0
