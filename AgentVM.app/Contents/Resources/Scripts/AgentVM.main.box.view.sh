#!/bin/sh
# AgentVM.main.box.view.sh
# View, in the box detail pane: the running box's screen in a window its supervisor owns, so
# it returns at once and closing the window leaves the box running. Keys and clicks reach the
# box, and the window has a Type Password button. A Linux box has no screen: the button is not
# shown for one, and agent-vm is not asked for one however this handler came to run.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
[ "$(main_guest "$window_uuid" boxes "$name")" != "linux" ] || exit 0
agentvm_box_view "$name" interactive
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "Could not show box $name" "$(agentvm_last_error "$status")"
fi
