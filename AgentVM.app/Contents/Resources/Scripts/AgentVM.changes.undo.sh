#!/bin/sh
# AgentVM.changes.undo.sh
# Undo Ticked... in the Session Changes window: the question before putting the ticked entries
# back (chg_undo_ask); its Undo button goes on with AgentVM.changes.undo.confirmed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.changes.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
chg_is "$window_uuid" || exit 0
chg_undo_ask "$window_uuid"
exit 0
