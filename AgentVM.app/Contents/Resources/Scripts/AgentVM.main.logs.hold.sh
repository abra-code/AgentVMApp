#!/bin/sh
# AgentVM.main.logs.hold.sh
# The picker of the Logs of deleted boxes part of Settings changed: the store keeps a deleted
# box's logs for the time picked. A time that would remove logs kept now (a shorter one, or
# Never) is asked about first, about the logs as they are now; the time asked about is kept as
# the window's pending change, and Change in the question runs AgentVM.main.logs.hold.confirmed.
# The store's own time, picked again, changes nothing.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set logs_hold "$window_uuid" ""
eval "days=\"\${OMC_ACTIONUI_VIEW_${MAIN_KEPT_HOLD_ID}_VALUE:-}\""
# Only a time the picker offers: its value comes back from the window.
case " $MAIN_KEPT_HOLD_CHOICES " in
    *" $days "*) ;;
    *) exit 0 ;;
esac
case "$days" in
    ''|*[!0123456789]*) exit 0 ;;
esac
main_read_status "$window_uuid"
read_status=$?
if [ "$read_status" -ne 0 ]; then
    main_paint "$window_uuid"
    exit 0
fi
if [ "$(main_kept_hold_days "$window_uuid")" = "$days" ]; then
    main_paint "$window_uuid"
    exit 0
fi
question="$(main_kept_hold_question "$window_uuid" "$days")"
if [ -z "$question" ]; then
    main_kept_hold_apply "$window_uuid" "$days"
    exit 0
fi
ui_set logs_hold "$window_uuid" "$days"
if [ "$days" = "0" ]; then
    title="Keep no logs of deleted boxes?"
else
    title="Keep the logs of deleted boxes for $days days?"
fi
"$dialog" "$window_uuid" omc_window omc_present_alert "$title" "$question" \
    "Cancel:cancel:AgentVM.main.logs.hold.canceled" "Change:destructive:AgentVM.main.logs.hold.confirmed"
exit 0
