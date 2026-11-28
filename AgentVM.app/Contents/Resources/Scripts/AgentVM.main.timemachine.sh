#!/bin/sh
# AgentVM.main.timemachine.sh
# A checkbox of Settings' Time Machine group was checked or unchecked: that folder of the store
# (Boxes, Images or Cache) is left out of Time Machine backups, or backed up again
# (lib.agentvm.timemachine.sh). Which folder is the checkbox's place in the group.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
n="$(tm_number "${OMC_ACTIONUI_TRIGGER_VIEW_ID:-}")"
[ -n "$n" ] || exit 0
[ "$OMC_ACTIONUI_TRIGGER_VIEW_ID" = "$(tm_toggle_id "$n")" ] || exit 0
eval "value=\"\${OMC_ACTIONUI_VIEW_${OMC_ACTIONUI_TRIGGER_VIEW_ID}_VALUE:-}\""
case "$value" in
    true)  tm_set "$window_uuid" "$n" 1 ;;
    false) tm_set "$window_uuid" "$n" 0 ;;
esac
exit 0
