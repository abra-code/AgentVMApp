#!/bin/sh
# AgentVM.discard.init.sh
# The Discard Sessions window opens (INIT_SUBCOMMAND_ID): it becomes the one such window, with a
# day DSC_DEFAULT_DAYS ago, and says what discarding the sessions that ended before it frees. A
# window opened without a request of this run of the app (a URL naming the command itself),
# without a main window, or while another one is open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.discard.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set discard "$window_uuid" ""
requested="$(ui_item_request discard)"
main="$(ui_item_window main window)"
if [ "$requested" != "window" ] || [ -z "$main" ]; then
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window discard window)"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set discard "$window_uuid" open
ui_item_claim discard window "$window_uuid"
dsc_open "$window_uuid" "$main"
exit 0
