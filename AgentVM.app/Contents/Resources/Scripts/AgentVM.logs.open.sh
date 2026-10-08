#!/bin/sh
# AgentVM.logs.open.sh
# Where the Logs Are..., in the How to Use a Box window: the Where the Logs Are window opens, or
# comes to the front. It only shows.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.ui.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_open logs window "$OMC_CURRENT_COMMAND_GUID"
exit 0
