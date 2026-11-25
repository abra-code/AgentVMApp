#!/bin/sh
# AgentVM.main.session.older.sh
# The discard button after the plus in the Sessions tab's toolbar: the Discard Sessions window in
# front, the open one or a new one (lib.agentvm.discard.sh).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.discard.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
dsc_ask "$OMC_CURRENT_COMMAND_GUID"
exit 0
