#!/bin/sh
# AgentVM.network.init.sh
# A box's network window opens (INIT_SUBCOMMAND_ID): takes the box's name from the open request,
# becomes that box's network window, and reads and paints it. A window opened without a request
# of this run of the app (a URL naming the command itself), or for a box whose network window is
# already open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set box "$window_uuid" ""
ui_set net_allow "$window_uuid" ""
box="$(ui_item_request network)"
if [ -z "$box" ]; then
    "$dialog" "$window_uuid" "$NET_MODE_NOTE_ID" "No box was named for this window."
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window network "$box")"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set box "$window_uuid" "$box"
ui_item_claim network "$box" "$window_uuid"
"$dialog" "$window_uuid" omc_window "Network of box $box"
net_refresh "$window_uuid"
exit 0
