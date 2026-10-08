#!/bin/sh
# AgentVM.main.logs.remove.confirmed.sh
# Remove All, in the question AgentVM.main.logs.remove asked: agent-vm removes the logs of every
# deleted box it kept, the window reads status again, and a toast says how many boxes' logs went.
# When agent-vm fails, its reason is shown.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
asked="$(ui_get logs_remove "$window_uuid")"
# Read once: a second confirmation, or one without a question, removes nothing.
ui_set logs_remove "$window_uuid" ""
[ "$asked" = "1" ] || exit 0
removed="$(agentvm_store_logs_remove_all)"
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "The logs were not removed" "$(agentvm_last_error "$status")"
    main_refresh "$window_uuid" status
    exit 0
fi
main_refresh "$window_uuid" status
case "$removed" in
    ''|0|*[!0123456789]*) ;;
    *)  "$dialog" "$window_uuid" omc_window omc_present_toast "The logs of $(main_kept_boxes_text "$removed") are removed." "$MAIN_TOAST_SECONDS" ;;
esac
exit 0
