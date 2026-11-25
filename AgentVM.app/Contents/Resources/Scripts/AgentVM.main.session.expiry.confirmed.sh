#!/bin/sh
# AgentVM.main.session.expiry.confirmed.sh
# Set, in the question of the expiry picker: the store's expiry is the days it asked about.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
days="$(ui_get session-expiry "$window_uuid")"
ui_set session-expiry "$window_uuid" ""
case " $SES_EXPIRY_CHOICES " in
    *" $days "*) ;;
    *) exit 0 ;;
esac
case "$days" in
    ''|*[!0123456789]*) exit 0 ;;
esac
ses_expiry_apply "$window_uuid" "$days"
exit 0
