#!/bin/sh
# AgentVM.install.init.sh
# The Install agent-vm window opens (INIT_SUBCOMMAND_ID): it becomes the one such window, asks
# GitHub for the newest release and the installed agent-vm for its version, and paints. A window
# opened without a request of this run of the app (a URL naming the command itself), or while
# another one is open, closes again. Nothing is downloaded or installed here.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.install.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set install "$window_uuid" ""
requested="$(ui_item_request install)"
if [ "$requested" != "window" ]; then
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window install window)"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set install "$window_uuid" "1"
ui_set busy "$window_uuid" ""
ui_item_claim install window "$window_uuid"
"$dialog" "$window_uuid" omc_window "Install agent-vm"
# The PATH part starts ticked, as it does in the package; from here on the checkbox is the user's.
"$dialog" "$window_uuid" "$INSTALL_PATH_ID" "true"
install_refresh "$window_uuid"
exit 0
