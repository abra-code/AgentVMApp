#!/bin/sh
# AgentVM.main.activated.sh
# The main window became active again (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): reads everything
# again, doctor included, since the user may have come back from Terminal or from installing
# agent-vm; and starts a poll loop if none runs, or if the one that held the window was killed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
main_refresh "$window_uuid" full
main_poll_running "$window_uuid"
running=$?
if [ "$running" -ne 0 ]; then
    "$next_command" "$OMC_CURRENT_COMMAND_GUID" "AgentVM.main.poll"
fi
