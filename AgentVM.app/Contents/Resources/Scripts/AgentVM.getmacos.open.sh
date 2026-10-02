#!/bin/sh
# AgentVM.getmacos.open.sh
# The Get macOS button, under the main window's image list and on the first step of the New
# Image window: the Get macOS window opens, or comes to the front. It only shows; a download is
# started by its own button.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.ui.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_open getmacos window "$OMC_CURRENT_COMMAND_GUID"
exit 0
