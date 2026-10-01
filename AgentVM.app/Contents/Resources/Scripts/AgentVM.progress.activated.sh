#!/bin/sh
# AgentVM.progress.activated.sh
# A job's progress window became active (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): reads and paints the
# job again, and starts the poll loop if the job still runs and no loop follows it (the last one
# was killed, or ended when a reading found the job over that a later one finds running).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.progress.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
[ -n "$(progress_job_id "$window_uuid")" ] || exit 0
progress_refresh "$window_uuid"
progress_moving "$window_uuid" || exit 0
progress_poll_running "$window_uuid" && exit 0
"$next_command" "$OMC_CURRENT_COMMAND_GUID" "AgentVM.progress.poll"
exit 0
