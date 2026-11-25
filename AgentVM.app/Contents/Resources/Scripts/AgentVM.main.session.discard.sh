#!/bin/sh
# AgentVM.main.session.discard.sh
# Discard Ticked..., in the Sessions tab: the question before discarding the sessions ticked in the
# selected project's table (lib.agentvm.sessions.sh, ses_ask).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
project="$(ui_get session-project "$window_uuid")"
[ -n "$project" ] || exit 0
ids="$(ses_ticked_ids "$window_uuid")"
[ -n "$ids" ] || exit 0
ses_ask "$window_uuid" "$ids" "$(/usr/bin/basename "$project")"
exit 0
