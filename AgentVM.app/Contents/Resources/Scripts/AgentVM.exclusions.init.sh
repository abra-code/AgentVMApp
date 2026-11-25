#!/bin/sh
# AgentVM.exclusions.init.sh
# The Exclusions window opens (INIT_SUBCOMMAND_ID): it becomes the one such window, takes the
# project the main window handed over, and looks through it (`session scan`, seconds for a large
# project), with the rows ticked as saved or as agent-vm suggests. A window opened without a
# request of this run of the app (a URL naming the command itself), without a project, or while
# another one is open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.exclusions.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set exclusions "$window_uuid" ""
requested="$(ui_item_request exclusions)"
project="$(excl_take)"
if [ "$requested" != "window" ] || [ -z "$project" ]; then
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window exclusions window)"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set exclusions "$window_uuid" "$project"
ui_item_claim exclusions window "$window_uuid"
"$dialog" "$window_uuid" omc_window "Snapshot Exclusions"
excl_scan "$window_uuid"
# Painting reads the cache, which makes its folder again for a window that closed meanwhile.
excl_is "$window_uuid" || ui_cache_clear "$window_uuid"
exit 0
