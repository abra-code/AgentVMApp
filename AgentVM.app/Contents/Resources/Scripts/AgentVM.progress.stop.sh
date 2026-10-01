#!/bin/sh
# AgentVM.progress.stop.sh
# Stop..., in a job's progress window: asks first, saying what stopping leaves behind. The job is
# read again, so a job that has ended meanwhile is not asked about. The job asked about is kept as
# the window's pending stop; Stop in the question runs AgentVM.progress.stop.confirmed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.progress.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
job="$(progress_job_id "$window_uuid")"
[ -n "$job" ] || exit 0
ui_set job_stop "$window_uuid" ""
progress_refresh "$window_uuid"
progress_moving "$window_uuid" || exit 0
row="$(progress_job "$window_uuid")"
ui_set job_stop "$window_uuid" "$job"
"$dialog" "$window_uuid" omc_window omc_present_alert "Stop $(progress_title "$row" | /usr/bin/awk '{ print tolower(substr($0, 1, 1)) substr($0, 2) }')?" \
    "$(progress_stop_question "$row")" \
    "Keep Going:cancel:" "Stop:destructive:AgentVM.progress.stop.confirmed"
exit 0
