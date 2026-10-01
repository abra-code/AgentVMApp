#!/bin/sh
# AgentVM.progress.close.sh
# A job's progress window closed (END_CANCEL_SUBCOMMAND_ID): the poll loop ends at its next wake,
# the job has no progress window any more, if this one was it, and the window's values and cache
# files go. The job itself goes on.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.progress.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set poll "$window_uuid" "closed"
job="$(progress_job_id "$window_uuid")"
[ -n "$job" ] && ui_item_release progress "$job" "$window_uuid"
ui_set job "$window_uuid" ""
ui_set job_stop "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
