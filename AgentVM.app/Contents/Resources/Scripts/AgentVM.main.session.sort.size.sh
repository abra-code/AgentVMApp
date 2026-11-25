#!/bin/sh
# AgentVM.main.session.sort.size.sh
# Sort by Size, in the sort menu of the Sessions tab's toolbar: the project cards by size, the
# most to free first. Picking it when it is already checked unchecks the toggle; the paint checks
# it again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ses_sort_set "$window_uuid" size
exit 0
