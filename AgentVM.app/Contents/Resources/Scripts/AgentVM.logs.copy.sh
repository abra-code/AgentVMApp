#!/bin/sh
# AgentVM.logs.copy.sh
# Copy, beside a line for Terminal of the Where the Logs Are window: that line's command goes to
# the clipboard, as the window shows it. Which line is the button's place among the Copy buttons.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.logs.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
logs_is "$window_uuid" || exit 0
case "$OMC_ACTIONUI_TRIGGER_VIEW_ID" in
    ''|*[!0123456789]*) exit 0 ;;
esac
logs_copy_line "$window_uuid" "$(( OMC_ACTIONUI_TRIGGER_VIEW_ID - LOGS_COPY_BASE ))"
exit 0
