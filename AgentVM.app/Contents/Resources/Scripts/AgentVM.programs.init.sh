#!/bin/sh
# AgentVM.programs.init.sh
# A box's programs window opens (INIT_SUBCOMMAND_ID): takes the box's name from the open request,
# becomes that box's programs window, and reads and paints it. A window opened without a request
# of this run of the app (a URL naming the command itself), or for a box whose programs window is
# already open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.programs.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set box "$window_uuid" ""
box="$(ui_item_request programs)"
if [ -z "$box" ]; then
    "$dialog" "$window_uuid" "$PROG_NOTE_ID" "No box was named for this window."
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window programs "$box")"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set box "$window_uuid" "$box"
ui_item_claim programs "$box" "$window_uuid"
"$dialog" "$window_uuid" omc_window "Programs in box $box"
prog_refresh "$window_uuid"
exit 0
