#!/bin/sh
# AgentVM.progress.stop.confirmed.sh
# Stop, in the question AgentVM.progress.stop asked: agent-vm is asked to cancel the job asked
# about, which then stops at its next safe point; the window goes on following it until it has.
# When agent-vm refuses (the job ended meanwhile), its reason is shown.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.progress.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
job="$(ui_get job_stop "$window_uuid")"
# Read once: a second confirmation, or one without a question, stops nothing.
ui_set job_stop "$window_uuid" ""
[ -n "$job" ] && agentvm_valid_job_id "$job" || exit 0
[ "$job" = "$(progress_job_id "$window_uuid")" ] || exit 0
agentvm_job_cancel "$job"
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "The job was not stopped" "$(agentvm_last_error "$status")"
fi
progress_refresh "$window_uuid"
progress_moving "$window_uuid" || exit 0
progress_poll_running "$window_uuid" && exit 0
"$next_command" "$OMC_CURRENT_COMMAND_GUID" "AgentVM.progress.poll"
exit 0
