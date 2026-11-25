#!/bin/sh
# AgentVM.main.session.expiry.canceled.sh
# Cancel, in the question of the expiry picker: the picker goes back to the store's expiry.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set session-expiry "$window_uuid" ""
ses_paint_settings "$window_uuid"
exit 0
