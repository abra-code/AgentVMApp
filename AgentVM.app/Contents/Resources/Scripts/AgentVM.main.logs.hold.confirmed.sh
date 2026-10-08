#!/bin/sh
# AgentVM.main.logs.hold.confirmed.sh
# Change, in the question AgentVM.main.logs.hold asked: the store keeps a deleted box's logs for
# the time asked about, whatever the picker shows by then.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
days="$(ui_get logs_hold "$window_uuid")"
# Read once: a second confirmation, or one without a question, changes nothing.
ui_set logs_hold "$window_uuid" ""
case " $MAIN_KEPT_HOLD_CHOICES " in
    *" $days "*) ;;
    *) exit 0 ;;
esac
case "$days" in
    ''|*[!0123456789]*) exit 0 ;;
esac
main_kept_hold_apply "$window_uuid" "$days"
exit 0
