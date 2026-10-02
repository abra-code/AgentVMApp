#!/bin/sh
# AgentVM.newbox.mode.sh
# The network step's mode picker changed: the mode is kept, and the line under it says what it
# lets through. The picker reports the 1-based index of its option.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
[ "$(newbox_step "$window_uuid")" = "2" ] || exit 0
case "${OMC_ACTIONUI_VIEW_2061_VALUE:-}" in
    1) mode=allowlist ;;
    2) mode=off ;;
    3) mode=open ;;
    *) exit 0 ;;
esac
ui_set mode "$window_uuid" "$mode"
"$dialog" "$window_uuid" "$NBOX_MODE_NOTE_ID" "$(net_mode_text "$mode" stopped)"
exit 0
