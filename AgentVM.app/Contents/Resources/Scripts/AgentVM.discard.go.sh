#!/bin/sh
# AgentVM.discard.go.sh
# Discard, in the Discard Sessions window: the window closes, and the sessions it chose are
# discarded in the main window (lib.agentvm.discard.sh, dsc_go).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.discard.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
dsc_is "$window_uuid" || exit 0
# One click at a time: a second Discard clicked before the window closed would discard twice.
wizard_enter "$window_uuid" || exit 0
dsc_go "$window_uuid"
exit 0
