#!/bin/sh
# AgentVM.main.logs.hold.canceled.sh
# Cancel, in the question AgentVM.main.logs.hold asked: nothing is changed, the pending change is
# forgotten, and the picker, which shows the time that was picked, goes back to the store's.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set logs_hold "$window_uuid" ""
main_paint_kept "$window_uuid"
exit 0
