#!/bin/sh
# AgentVM.keys.open.sh
# Agent Keys..., in the main window's Settings: the Agent Keys window opens, or comes to the
# front. It only shows; a key is stored or removed by the window's own buttons.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.ui.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_open keys window "$OMC_CURRENT_COMMAND_GUID"
exit 0
