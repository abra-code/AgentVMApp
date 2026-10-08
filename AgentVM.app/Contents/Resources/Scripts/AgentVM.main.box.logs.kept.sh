#!/bin/sh
# AgentVM.main.box.logs.kept.sh
# Logs of Deleted Boxes, in the bar under the box list: the folder where agent-vm keeps the logs
# of boxes that were deleted or recreated, a folder per box named after the box and the time,
# opens in Finder. Nothing when agent-vm keeps none, or the folder is not on this Mac.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
folder="$(main_kept_logs_folder "$window_uuid")"
[ -n "$folder" ] || exit 0
"$open_tool" "$folder"
exit 0
