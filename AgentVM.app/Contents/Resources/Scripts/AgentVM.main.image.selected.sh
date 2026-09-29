#!/bin/sh
# AgentVM.main.image.selected.sh
# A row of the images table was selected or deselected: the one selection across both tables
# becomes that image (the boxes table loses its highlight), and the action row follows.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$OMC_ACTIONUI_TABLE_320_COLUMN_1_VALUE"
if [ -n "$name" ] && agentvm_valid_name "$name"; then
    ui_set selected "$window_uuid" "image:$name"
    # Fires no action, so the boxes table's handler does not clear what was just set.
    "$dialog" "$window_uuid" "$MAIN_BOXES_ID" omc_deselect
else
    selected="$(ui_get selected "$window_uuid")"
    case "$selected" in
        image:*) ui_set selected "$window_uuid" "" ;;
    esac
fi
main_paint_actions "$window_uuid"
