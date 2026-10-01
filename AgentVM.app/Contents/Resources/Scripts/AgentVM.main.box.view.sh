#!/bin/sh
# AgentVM.main.box.view.sh
# View, in the box detail pane: the running box's screen in a window its supervisor owns, so
# it returns at once and closing the window leaves the box running. Keys and clicks do not reach
# the box.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
agentvm_box_view "$name"
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "Could not show box $name" "$(agentvm_last_error "$status")"
fi
