#!/bin/sh
# AgentVM.network.mode.sh
# The Settings tab's mode picker changed: the mode becomes the one wanted, applied with the rules.
# agent-vm changes the mode only while the box is stopped, so a change while it runs is put back.
# A value equal to the one wanted is the app's own setting of the picker, and changes nothing.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(ui_get box "$window_uuid")"
[ -n "$box" ] && agentvm_valid_name "$box" || exit 0
case "$OMC_ACTIONUI_VIEW_601_VALUE" in
    1) mode=allowlist ;;
    2) mode=off ;;
    3) mode=open ;;
    *) exit 0 ;;
esac
[ "$(net_mode "$(net_file "$window_uuid" "$box" desired)")" = "$mode" ] && exit 0
if [ "$(main_row "$window_uuid" boxes "$box" | /usr/bin/cut -f2)" = "stopped" ]; then
    net_set_mode "$window_uuid" "$box" "$mode"
fi
net_paint "$window_uuid"
