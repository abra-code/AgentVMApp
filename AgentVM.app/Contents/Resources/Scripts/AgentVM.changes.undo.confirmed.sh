#!/bin/sh
# AgentVM.changes.undo.confirmed.sh
# Undo (or Undo Anyway) in the question of the Session Changes window: the entries the question
# named are put back, and the window compares again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.changes.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
chg_is "$window_uuid" || exit 0
# One click at a time: a second Undo while agent-vm works would ask it twice.
wizard_enter "$window_uuid" || exit 0
chg_undo "$window_uuid"
exit 0
