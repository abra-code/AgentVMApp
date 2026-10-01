#!/bin/sh
# AgentVM.update.choice.sh
# A checkbox of an image's update window was clicked: the parts ticked are kept, and the command
# line and Update follow. A checkbox's value is "true" or "false"; anything else is not ticked.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.update.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
[ -n "$(update_image "$window_uuid")" ] || exit 0
macos=0
tools=0
guest=0
[ "${OMC_ACTIONUI_VIEW_811_VALUE:-}" = "true" ] && macos=1
[ "${OMC_ACTIONUI_VIEW_821_VALUE:-}" = "true" ] && tools=1
[ "${OMC_ACTIONUI_VIEW_831_VALUE:-}" = "true" ] && guest=1
ui_set choices "$window_uuid" "$macos $tools $guest"
update_paint "$window_uuid"
exit 0
