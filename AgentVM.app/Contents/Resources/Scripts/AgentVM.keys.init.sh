#!/bin/sh
# AgentVM.keys.init.sh
# The Agent Keys window opens (INIT_SUBCOMMAND_ID): it becomes the one Agent Keys window, reads
# which agent-vm runs and the agents with their keys, and paints. A window opened without a
# request of this run of the app (a URL naming the command itself), or while another Agent Keys
# window is open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.keys.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set keys "$window_uuid" ""
ui_set key "$window_uuid" ""
ui_set keyagent "$window_uuid" ""
ui_set key_remove "$window_uuid" ""
ui_set busy "$window_uuid" ""
requested="$(ui_item_request keys)"
if [ "$requested" != "window" ]; then
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window keys window)"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set keys "$window_uuid" "1"
ui_item_claim keys window "$window_uuid"
"$dialog" "$window_uuid" omc_window "Agent Keys"
keys_read "$window_uuid" full
# The window closed while agent-vm was read: nothing is painted, and the cache folder the
# reading made again goes.
if ! keys_is "$window_uuid"; then
    ui_cache_clear "$window_uuid"
    exit 0
fi
keys_paint "$window_uuid"
# Painting reads the cache, which makes its folder again for a window that closed meanwhile.
keys_is "$window_uuid" || ui_cache_clear "$window_uuid"
exit 0
