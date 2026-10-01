#!/bin/sh
# AgentVM.progress.init.sh
# A job's progress window opens (INIT_SUBCOMMAND_ID): takes the job's id from the open request,
# becomes that job's progress window, reads and paints it, and starts the poll loop that follows
# the job while it runs. A window opened without a request of this run of the app (a URL naming
# the command itself), or for a job whose progress window is already open, closes again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.progress.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set job "$window_uuid" ""
ui_set job_stop "$window_uuid" ""
ui_set poll "$window_uuid" ""
job="$(ui_item_request progress)"
agentvm_valid_job_id "$job" || job=""
if [ -z "$job" ]; then
    "$dialog" "$window_uuid" "$PROGRESS_STATUS_ID" "No job was named for this window."
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
existing="$(ui_item_window progress "$job")"
if [ -n "$existing" ] && [ "$existing" != "$window_uuid" ]; then
    "$dialog" "$existing" omc_window omc_select
    "$dialog" "$window_uuid" omc_window omc_terminate_cancel
    exit 0
fi
ui_set job "$window_uuid" "$job"
ui_item_claim progress "$job" "$window_uuid"
progress_refresh "$window_uuid"
progress_moving "$window_uuid" && "$next_command" "$OMC_CURRENT_COMMAND_GUID" "AgentVM.progress.poll"
exit 0
