#!/bin/sh
# AgentVM.main.session.expiry.sh
# The expiry picker in Settings' Sessions group changed: Never is set at once; a number of days
# that would discard ended sessions at the end of the next session asks first (the days are kept
# for AgentVM.main.session.expiry.confirmed), one that would discard none is set at once.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set session-expiry "$window_uuid" ""
eval "days=\"\${OMC_ACTIONUI_VIEW_${SES_EXPIRY_ID}_VALUE:-}\""
case " $SES_EXPIRY_CHOICES " in
    *" $days "*) ;;
    *) exit 0 ;;
esac
case "$days" in
    ''|*[!0123456789]*) exit 0 ;;
esac
main_read_status "$window_uuid"
# The question counts the ended sessions: the list as it is now. Without it nothing would be
# counted and a time that discards sessions would be set with no question.
ses_read "$window_uuid"
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "The expiry was not changed" "$(/bin/cat "$(ses_cache "$window_uuid" session-list-error)" 2>/dev/null)"
    ses_paint_settings "$window_uuid"
    exit 0
fi
if [ "$(ses_status_field "$window_uuid" 9)" = "$days" ]; then
    ses_paint_settings "$window_uuid"
    exit 0
fi
question=""
[ "$days" = "0" ] || question="$(ses_expiry_question "$window_uuid" "$days")"
if [ -z "$question" ]; then
    ses_expiry_apply "$window_uuid" "$days"
    exit 0
fi
ui_set session-expiry "$window_uuid" "$days"
"$dialog" "$window_uuid" omc_window omc_present_alert "Discard ended sessions $days days after they end?" "$question" \
    "Cancel:cancel:AgentVM.main.session.expiry.canceled" "Set:destructive:AgentVM.main.session.expiry.confirmed"
exit 0
