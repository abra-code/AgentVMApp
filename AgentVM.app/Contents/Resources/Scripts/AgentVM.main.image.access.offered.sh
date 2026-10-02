#!/bin/sh
# AgentVM.main.image.access.offered.sh
# Grant It Again..., in the question the main window asks when an update took an image's Full
# Disk Access away (lib.agentvm.main.sh, main_report_jobs): opens the guide of the image asked
# about, whatever the selection is by then. Nothing is started here.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get access_offer "$window_uuid")"
# Read once: a second answer, or one without a question, opens nothing.
ui_set access_offer "$window_uuid" ""
[ -n "$name" ] && agentvm_valid_name "$name" || exit 0
[ -n "$(main_row "$window_uuid" images "$name")" ] || exit 0
ui_item_open access "$name" "$OMC_CURRENT_COMMAND_GUID"
exit 0
