#!/bin/sh
# AgentVM.main.box.progress.sh
# Progress..., beside the box pane's state line while a job holds the selected box: brings that
# job's progress window to the front, or opens one. The job is the one the pane showed, from the
# rows last read; when it has ended since, its window still opens, on how it ended.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
job="$(main_job "$window_uuid" box "$name" | /usr/bin/cut -f1)"
agentvm_valid_job_id "$job" || exit 0
ui_item_open progress "$job" "$OMC_CURRENT_COMMAND_GUID"
exit 0
