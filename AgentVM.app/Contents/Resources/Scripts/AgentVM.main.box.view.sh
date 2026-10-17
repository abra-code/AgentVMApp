#!/bin/sh
# AgentVM.main.box.view.sh
# View, in the box detail pane: the running box's screen in a window its supervisor owns, so
# it returns at once and closing the window leaves the box running. Keys and clicks reach the
# box; the window of a macOS box has a Type Password button, that of a Linux box none (its
# account has no password). A Linux box without a desktop has no screen: the button is not
# shown for one, and agent-vm is not asked for one however this handler came to run.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
# A box not listed any more is agent-vm's to refuse, in its words.
[ -z "$(main_row "$window_uuid" boxes "$name")" ] || main_has_screen "$window_uuid" boxes "$name" || exit 0
agentvm_box_view "$name" interactive
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "Could not show box $name" "$(agentvm_last_error "$status")"
fi
