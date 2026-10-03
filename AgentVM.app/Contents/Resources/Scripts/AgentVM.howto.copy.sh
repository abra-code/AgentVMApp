#!/bin/sh
# AgentVM.howto.copy.sh
# Copy, beside a line of the How to Use a Box window: that line's command goes to the clipboard,
# as the window shows it. Which line is the button's place among the Copy buttons.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.howto.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
howto_is "$window_uuid" || exit 0
case "$OMC_ACTIONUI_TRIGGER_VIEW_ID" in
    ''|*[!0123456789]*) exit 0 ;;
esac
howto_copy "$window_uuid" "$(( OMC_ACTIONUI_TRIGGER_VIEW_ID - HOWTO_COPY_BASE ))"
exit 0
