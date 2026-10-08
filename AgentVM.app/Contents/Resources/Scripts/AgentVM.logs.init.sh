#!/bin/sh
# AgentVM.logs.init.sh
# The Where the Logs Are window opens (INIT_SUBCOMMAND_ID): it becomes the one such window, reads
# which agent-vm runs and status, for the store's folders, what agent-vm keeps of deleted boxes
# and the names its lines use, and paints. A window opened without a request of this run of the
# app (a URL naming the command itself), or while another one is open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.logs.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set logs "$window_uuid" ""
requested="$(ui_item_request logs)"
if [ "$requested" != "window" ]; then
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window logs window)"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set logs "$window_uuid" "1"
ui_item_claim logs window "$window_uuid"
"$dialog" "$window_uuid" omc_window "Where the Logs Are"
logs_refresh "$window_uuid" full
exit 0
