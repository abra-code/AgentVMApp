#!/bin/sh
# AgentVM.main.box.control.sh
# View and Control, in the box detail pane: the running box's screen, as View shows it, with
# keys and clicks reaching the box (and a Type Password button in the window).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
agentvm_box_view "$name" interactive
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "Could not show box $name" "$(agentvm_last_error "$status")"
fi
