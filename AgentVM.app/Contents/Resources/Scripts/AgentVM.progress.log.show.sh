#!/bin/sh
# AgentVM.progress.log.show.sh
# Show Log in Finder, under the log of a job's progress window: the job's whole log, the file
# "log" in the job's folder in the store, selected in a Finder window. It works while the job
# runs and after it ended. Nothing when the window has no job, or the file is not on this Mac.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.progress.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
[ -n "$(progress_job_id "$window_uuid")" ] || exit 0
main_show_file "$(progress_log_file "$window_uuid")"
exit 0
