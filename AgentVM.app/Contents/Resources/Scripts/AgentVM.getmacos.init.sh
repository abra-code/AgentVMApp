#!/bin/sh
# AgentVM.getmacos.init.sh
# The Get macOS window opens (INIT_SUBCOMMAND_ID): it becomes the one Get macOS window, reads
# which agent-vm runs, status and the restore files downloaded, and paints; then asks what Apple
# offers, which takes a few seconds, and paints again. A window opened without a request of this
# run of the app (a URL naming the command itself), or while another Get macOS window is open,
# closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.getmacos.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set getmacos "$window_uuid" ""
ui_set busy "$window_uuid" ""
requested="$(ui_item_request getmacos)"
if [ "$requested" != "window" ]; then
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window getmacos window)"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set getmacos "$window_uuid" "1"
ui_item_claim getmacos window "$window_uuid"
"$dialog" "$window_uuid" omc_window "Get macOS"
getmacos_read "$window_uuid" full
# The window closed while agent-vm was read: nothing is painted, and the cache folder the
# reading made again goes.
if ! getmacos_is "$window_uuid"; then
    ui_cache_clear "$window_uuid"
    exit 0
fi
getmacos_paint "$window_uuid"
getmacos_check "$window_uuid"
if ! getmacos_is "$window_uuid"; then
    ui_cache_clear "$window_uuid"
    exit 0
fi
getmacos_paint "$window_uuid"
# Painting reads the cache, which makes its folder again for a window that closed meanwhile.
getmacos_is "$window_uuid" || ui_cache_clear "$window_uuid"
exit 0
