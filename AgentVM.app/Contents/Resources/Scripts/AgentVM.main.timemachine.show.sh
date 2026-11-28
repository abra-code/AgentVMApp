#!/bin/sh
# AgentVM.main.timemachine.show.sh
# The folder button beside a checkbox of Settings' Time Machine group: that folder of the store
# in Finder. Which folder is the button's place in the group.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
n="$(tm_number "${OMC_ACTIONUI_TRIGGER_VIEW_ID:-}")"
[ -n "$n" ] || exit 0
[ "$OMC_ACTIONUI_TRIGGER_VIEW_ID" = "$(tm_show_id "$n")" ] || exit 0
tm_show "$window_uuid" "$n"
exit 0
