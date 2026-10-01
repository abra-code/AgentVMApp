#!/bin/sh
# AgentVM.network.apply.sh
# Apply Rules, in the Settings tab: the difference between the rules wanted and the box's rules
# becomes one `box network` call (lib.agentvm.sh, agentvm_box_network_change). Rules apply at once,
# even while the box runs; a mode picked waits until the box is stopped (net_sendable). When
# agent-vm refuses, nothing changed: its reason is shown and the edits stay. Afterwards the rules
# are read again, and what was not sent stays wanted. The main window shows the new rule count at
# its next reading.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(ui_get box "$window_uuid")"
[ -n "$box" ] && agentvm_valid_name "$box" || exit 0
# The box may have started or stopped since the window last read it: its state decides whether
# the mode is sent.
main_read_status "$window_uuid"
# A box `status` no longer lists, or a `status` that failed, leaves nothing to decide from:
# nothing is sent, the edits stay, and both tabs say why.
if [ -n "$(net_problem "$window_uuid" "$box")" ]; then
    net_paint "$window_uuid"
    exit 0
fi
changes="$(net_sendable "$window_uuid" "$box")"
[ -n "$changes" ] || exit 0
mode="$(printf '%s\n' "$changes" | /usr/bin/sed -n 's/^=//p')"
# One argument per change, read line by line: a rule such as *.example.com must not be expanded
# as a file name pattern.
set --
while IFS= read -r change; do
    [ -n "$change" ] && set -- "$@" "$change"
done <<CHANGES
$(printf '%s\n' "$changes" | /usr/bin/grep -v '^=')
CHANGES
agentvm_box_network_change "$box" "${mode:--}" "$@"
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "The rules of box $box were not changed" "$(agentvm_last_error "$status")"
    net_read "$window_uuid" "$box" rules
    net_paint "$window_uuid"
    exit 0
fi
net_read "$window_uuid" "$box" rules
net_paint "$window_uuid"
