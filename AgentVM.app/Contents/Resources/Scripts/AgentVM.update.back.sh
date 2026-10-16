#!/bin/sh
# AgentVM.update.back.sh
# Back, in an image's update window: the first step again. The files chosen for the recipes'
# inputs are kept while the tools stay ticked.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.update.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
[ -n "$(update_image "$window_uuid")" ] || exit 0
ui_set step "$window_uuid" 1
update_paint "$window_uuid"
[ -n "$(update_image "$window_uuid")" ] || ui_cache_clear "$window_uuid"
exit 0
