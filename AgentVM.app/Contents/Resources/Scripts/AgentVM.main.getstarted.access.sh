#!/bin/sh
# AgentVM.main.getstarted.access.sh
# Set Up..., beside "Full Disk Access" in Get started: brings the Full Disk Access guide of the
# first ready image that lacks the grant to the front, or opens one. The guide says what to do
# and asks; nothing is started here.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(main_rows "$window_uuid" images | /usr/bin/awk -F'\t' '$2 == "ready" && $8 ~ /full-disk-access/ { print $1; exit }')"
agentvm_valid_name "$name" || exit 0
ui_item_open access "$name" "$OMC_CURRENT_COMMAND_GUID"
exit 0
