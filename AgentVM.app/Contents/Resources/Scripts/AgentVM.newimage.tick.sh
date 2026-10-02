#!/bin/sh
# AgentVM.newimage.tick.sh
# A recipe's checkbox was clicked, in the New Image window: the recipes ticked are kept, and the
# notes beside them follow (what a ticked recipe needs that is neither ticked nor in the start).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newimage_is "$window_uuid" || exit 0
[ "$(newimage_step "$window_uuid")" = "2" ] || exit 0
newimage_take_ticks "$window_uuid"
newimage_paint_recipe_notes "$window_uuid"
exit 0
