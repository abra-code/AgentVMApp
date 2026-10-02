#!/bin/sh
# AgentVM.getmacos.progress.sh
# Progress..., in the Get macOS window: brings the progress window of the download that runs to
# the front, or opens one: how far it is, its log, and Stop.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.getmacos.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
getmacos_is "$window_uuid" || exit 0
job="$(getmacos_job "$window_uuid" | /usr/bin/cut -f1)"
agentvm_valid_job_id "$job" || exit 0
ui_item_open progress "$job" "$OMC_CURRENT_COMMAND_GUID"
exit 0
