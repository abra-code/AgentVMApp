#!/bin/sh
# AgentVM.discard.date.sh
# The day in the Discard Sessions window changed: the line above the buttons follows.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.discard.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
dsc_is "$window_uuid" || exit 0
eval "day=\"\${OMC_ACTIONUI_VIEW_${DSC_DATE_ID}_VALUE:-}\""
dsc_set_day "$window_uuid" "$day"
exit 0
