#!/bin/sh
# AgentVM.newbox.back.sh
# Back, in the New Box window: what the step shown holds is kept, as this click saw it and
# unchecked, and the step before it is shown.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
wizard_enter "$window_uuid" || exit 0
step="$(newbox_step "$window_uuid")"
case "$step" in
    1) exit 0 ;;
    3) newbox_take_sizes "$window_uuid" ;;
esac
newbox_show "$window_uuid" "$((step - 1))"
exit 0
