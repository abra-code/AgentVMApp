#!/bin/sh
# AgentVM.access.progress.sh
# Progress..., in an image's Full Disk Access guide: brings the progress window of the setup job
# the guide follows to the front, or opens one: its log, and Stop.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.access.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
[ -n "$(access_image "$window_uuid")" ] || exit 0
job="$(access_followed "$window_uuid" | /usr/bin/cut -f1)"
agentvm_valid_job_id "$job" || exit 0
ui_item_open progress "$job" "$OMC_CURRENT_COMMAND_GUID"
exit 0
