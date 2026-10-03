#!/bin/sh
# AgentVM.howto.open.sh
# The question mark under the main window's box list: the How to Use a Box window opens, or
# comes to the front. It only shows.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.ui.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_open howto window "$OMC_CURRENT_COMMAND_GUID"
exit 0
