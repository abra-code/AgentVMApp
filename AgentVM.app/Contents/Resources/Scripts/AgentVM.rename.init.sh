#!/bin/sh
# AgentVM.rename.init.sh
# The Rename window opens (INIT_SUBCOMMAND_ID): it becomes the one such window, takes the box or
# image the main window handed over, and shows its name in the field. A window opened without a
# request of this run of the app (a URL naming the command itself), without a box or image to
# rename, or while another one is open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.rename.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set rename "$window_uuid" ""
requested="$(ui_item_request rename)"
target="$(rename_take)"
if [ "$requested" != "window" ] || [ -z "$target" ]; then
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window rename window)"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set rename "$window_uuid" "$target"
ui_item_claim rename window "$window_uuid"
if [ "${target%%:*}" = "box" ]; then
    "$dialog" "$window_uuid" omc_window "Rename Box"
else
    "$dialog" "$window_uuid" omc_window "Rename Image"
fi
rename_paint "$window_uuid"
exit 0
