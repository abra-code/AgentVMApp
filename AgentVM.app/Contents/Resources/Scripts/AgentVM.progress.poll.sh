#!/bin/sh
# AgentVM.progress.poll.sh
# A progress window's poll loop (lib.agentvm.progress.sh, progress_poll), chained by the init,
# activate and stop handlers. Runs until the job has ended, the window closes, a newer loop takes
# over, or the app quits.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.progress.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
[ -n "$(progress_job_id "$window_uuid")" ] || exit 0
progress_poll "$window_uuid"
exit 0
