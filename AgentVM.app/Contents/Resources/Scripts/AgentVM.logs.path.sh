#!/bin/sh
# AgentVM.logs.path.sh
# Copy Path, beside a place of the Where the Logs Are window: that place's folder goes to the
# clipboard as a full path. Which place is the button's place among the Copy Path buttons.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.logs.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
logs_is "$window_uuid" || exit 0
case "$OMC_ACTIONUI_TRIGGER_VIEW_ID" in
    ''|*[!0123456789]*) exit 0 ;;
esac
logs_copy_path "$window_uuid" "$(( OMC_ACTIONUI_TRIGGER_VIEW_ID - LOGS_PATH_BASE ))"
exit 0
