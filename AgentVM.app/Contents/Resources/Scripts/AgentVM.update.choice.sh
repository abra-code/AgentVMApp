#!/bin/sh
# AgentVM.update.choice.sh
# A checkbox of an image's update window was clicked: the parts ticked are kept, and the command
# line and Update follow. A checkbox's value is "true" or "false"; anything else is not ticked.
# Unticking the tools forgets the files chosen for recipes' inputs, and the second step with them.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.update.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
[ -n "$(update_image "$window_uuid")" ] || exit 0
system=0
tools=0
guest=0
[ "${OMC_ACTIONUI_VIEW_811_VALUE:-}" = "true" ] && system=1
[ "${OMC_ACTIONUI_VIEW_821_VALUE:-}" = "true" ] && tools=1
[ "${OMC_ACTIONUI_VIEW_831_VALUE:-}" = "true" ] && guest=1
ui_set choices "$window_uuid" "$system $tools $guest"
# The checkboxes are on the first step, which stays shown: a second step kept from before (one
# that a reading without the tools put back to the first) does not come back by ticking them.
ui_set step "$window_uuid" 1
# A file chosen for a recipe's input is used by the tools update only: unticking it forgets them.
[ "$tools" -eq 0 ] && update_unchoose "$window_uuid"
update_paint "$window_uuid"
exit 0
