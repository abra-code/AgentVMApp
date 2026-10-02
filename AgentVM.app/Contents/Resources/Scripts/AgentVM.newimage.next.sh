#!/bin/sh
# AgentVM.newimage.next.sh
# Continue, in the New Image window: what the step shown asks for is kept, as this click saw it,
# and checked; when something is wrong the step stays and says what, else the next step is shown.
# Step 1 takes the row selected in the start table and reads agent-vm again; step 2 the
# checkboxes; step 3 the option fields; step 4 the name and sizes. The options step is skipped
# when the tools ticked ask for nothing.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newimage_is "$window_uuid" || exit 0
newimage_enter "$window_uuid" || exit 0
step="$(newimage_step "$window_uuid")"
case "$step" in
    1)
        newimage_set_start "$window_uuid" "$(newimage_start_key "$window_uuid" "${OMC_ACTIONUI_TABLE_1051_COLUMN_5_VALUE:-}" "${OMC_ACTIONUI_TABLE_1051_COLUMN_1_VALUE:-}")"
        newimage_read "$window_uuid"
        # The window closed while agent-vm was read: the cache folder the reading made again goes.
        if ! newimage_is "$window_uuid"; then
            ui_cache_clear "$window_uuid"
            exit 0
        fi
        blocker="$(newimage_unreadable "$window_uuid")"
        [ -n "$blocker" ] || blocker="$(newimage_start_blocker "$window_uuid")" ;;
    2)
        newimage_take_ticks "$window_uuid"
        blocker="$(newimage_tools_blocker "$window_uuid")" ;;
    3)
        newimage_take_options "$window_uuid"
        blocker="$(newimage_options_blocker "$window_uuid")" ;;
    4)
        newimage_take_sizes "$window_uuid"
        blocker="$(newimage_sizes_blocker "$window_uuid")" ;;
    *)
        exit 0 ;;
esac
if [ -n "$blocker" ]; then
    "$dialog" "$window_uuid" "$NEW_NOTE_ID" "$blocker"
    exit 0
fi
next=$((step + 1))
if [ "$step" -eq 2 ] && [ -z "$(newimage_option_rows "$window_uuid")" ]; then
    next=4
fi
newimage_show "$window_uuid" "$next"
exit 0
