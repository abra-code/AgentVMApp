#!/bin/sh
# AgentVM.newbox.next.sh
# Continue, in the New Box window: what the step shown asks for is kept, as this click saw it,
# and checked; when something is wrong the step stays and says what, else the next step is shown.
# Step 1 takes the row selected in the image table (the row last picked, when the click did not
# carry it) and reads agent-vm again; step 2 has nothing to take, since every click there was
# kept as it was made; step 3 takes the name, the sizes and the start checkbox.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
wizard_enter "$window_uuid" || exit 0
step="$(newbox_step "$window_uuid")"
blocker=""
case "$step" in
    1)
        picked="$(newbox_picked "$window_uuid" "${OMC_ACTIONUI_TABLE_2051_COLUMN_5_VALUE:-}" "${OMC_ACTIONUI_TABLE_2051_COLUMN_1_VALUE:-}")"
        if [ -z "$picked" ]; then
            picked="$(ui_get picked "$window_uuid")"
            agentvm_valid_name "$picked" || picked=""
        fi
        newbox_read "$window_uuid"
        # The window closed while agent-vm was read: the cache folder the reading made again goes.
        if ! newbox_is "$window_uuid"; then
            ui_cache_clear "$window_uuid"
            exit 0
        fi
        blocker="$(newbox_unreadable "$window_uuid")"
        [ -n "$blocker" ] || blocker="$(newbox_image_blocker "$window_uuid" "$picked")"
        [ -n "$blocker" ] || newbox_set_image "$window_uuid" "$picked" ;;
    2)
        ;;
    3)
        newbox_take_sizes "$window_uuid"
        blocker="$(newbox_sizes_blocker "$window_uuid")" ;;
    *)
        exit 0 ;;
esac
if [ -n "$blocker" ]; then
    "$dialog" "$window_uuid" "$NBOX_NOTE_ID" "$blocker"
    exit 0
fi
newbox_show "$window_uuid" "$((step + 1))"
exit 0
