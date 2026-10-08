#!/bin/sh
# AgentVM.main.logs.remove.sh
# Remove All..., in the Logs of deleted boxes part of Settings: asks first, saying what goes,
# about the logs as they are now (status is read again; with none kept nothing is asked). Remove
# All in the question runs AgentVM.main.logs.remove.confirmed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set logs_remove "$window_uuid" ""
main_read_status "$window_uuid"
read_status=$?
main_paint "$window_uuid"
# Not when status failed: the count would be an old one (the note under the lists says why).
[ "$read_status" -eq 0 ] || exit 0
count="$(main_kept_count "$window_uuid")"
[ "$count" -gt 0 ] || exit 0
ui_set logs_remove "$window_uuid" "1"
"$dialog" "$window_uuid" omc_window omc_present_alert "Remove the logs of $(main_kept_boxes_text "$count")?" \
    "$(main_kept_remove_question "$window_uuid")" \
    "Cancel:cancel:" "Remove All:destructive:AgentVM.main.logs.remove.confirmed"
exit 0
