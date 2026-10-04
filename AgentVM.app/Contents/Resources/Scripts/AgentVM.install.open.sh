#!/bin/sh
# AgentVM.install.open.sh
# Install... or Update... on the first step of Get started, and Check for Updates... in
# Settings: the Install agent-vm window opens, or comes to the front. It only shows.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.ui.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_open install window "$OMC_CURRENT_COMMAND_GUID"
exit 0
