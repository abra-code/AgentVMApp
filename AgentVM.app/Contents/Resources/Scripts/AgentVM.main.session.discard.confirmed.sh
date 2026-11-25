#!/bin/sh
# AgentVM.main.session.discard.confirmed.sh
# Discard, in the question of Discard Ticked... or Discard All Ended...: the sessions the question
# named are discarded (lib.agentvm.sessions.sh, ses_discard).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ids="$(ui_get session-discard "$window_uuid")"
ui_set session-discard "$window_uuid" ""
[ -n "$ids" ] || exit 0
ses_discard "$window_uuid" "$ids"
exit 0
