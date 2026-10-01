#!/bin/sh
# AgentVM.main.image.selected.sh
# A card of the image list was selected or deselected: the image list's selection becomes that
# image, or nothing, and the detail pane follows. A selected image is measured (`image info`, 0.1-0.3
# s) for the pane's space, tools and Full Disk Access; a failure is shown in the pane.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$OMC_ACTIONUI_TABLE_411_COLUMN_1_VALUE"
if [ -n "$name" ] && agentvm_valid_name "$name"; then
    ui_set image "$window_uuid" "$name"
    main_read_info "$window_uuid" image "$name"
else
    ui_set image "$window_uuid" ""
fi
main_paint_image_detail "$window_uuid"
