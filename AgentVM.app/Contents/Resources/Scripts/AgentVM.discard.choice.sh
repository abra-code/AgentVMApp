#!/bin/sh
# AgentVM.discard.choice.sh
# The choice in the Discard Sessions window changed: the sessions that ended before a day, or all
# ended and undone sessions. The line above the buttons follows.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.discard.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
dsc_is "$window_uuid" || exit 0
eval "choice=\"\${OMC_ACTIONUI_VIEW_${DSC_CHOICE_ID}_VALUE:-}\""
dsc_choose "$window_uuid" "$choice"
exit 0
