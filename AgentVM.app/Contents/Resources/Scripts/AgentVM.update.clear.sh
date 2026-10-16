#!/bin/sh
# AgentVM.update.clear.sh
# Clear, in a recipe's slot of an image's update window (the second step): the file chosen for the
# slot's input is forgotten, so the recipe runs its update steps instead of running again, and
# the window follows.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.update.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
image="$(update_image "$window_uuid")"
[ -n "$image" ] || exit 0
case "${OMC_ACTIONUI_TRIGGER_VIEW_ID:-}" in
    ''|*[!0123456789]*) exit 0 ;;
esac
slot=$((OMC_ACTIONUI_TRIGGER_VIEW_ID - UPDATE_CLEAR_BASE))
if [ "$slot" -lt 1 ] || [ "$slot" -gt "$UPDATE_SLOTS" ]; then
    exit 0
fi
# The buttons are on the second step, which is shown only while the tools are ticked.
[ "$(update_step "$window_uuid" "$image")" = "2" ] || exit 0
input="$(update_slot_input "$window_uuid" "$slot")"
[ -n "$input" ] || exit 0
update_unchoose "$window_uuid" "$input"
update_paint "$window_uuid"
[ -n "$(update_image "$window_uuid")" ] || ui_cache_clear "$window_uuid"
exit 0
