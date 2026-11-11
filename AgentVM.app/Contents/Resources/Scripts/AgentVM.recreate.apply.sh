#!/bin/sh
# AgentVM.recreate.apply.sh
# Recreate, in the Recreate window: agent-vm's lists are read again first, and what stands in the
# way now (the box started, a job holds it, the image chosen went) is said in the line under the
# table instead. Else agent-vm makes the box again from the image chosen, the main window reads
# its lists again (after a failure too: agent-vm can delete the old box and then fail to make the
# new one, and the list must not show a box that is gone), and this window closes. agent-vm's
# refusal is shown whole, in its words, and the window stays.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.recreate.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(recreate_box "$window_uuid")"
[ -n "$box" ] && agentvm_valid_name "$box" || exit 0
# One click at a time: a second Recreate clicked while agent-vm works would ask it twice.
wizard_enter "$window_uuid" || exit 0
# The row selected as this click saw it: a row clicked just before Recreate may not be kept yet
# (AgentVM.recreate.image runs on its own). The row last kept when the click carries none.
clicked="$(newbox_picked "$window_uuid" "${OMC_ACTIONUI_TABLE_5203_COLUMN_5_VALUE:-}" "${OMC_ACTIONUI_TABLE_5203_COLUMN_1_VALUE:-}")"
[ -n "$clicked" ] && ui_set picked "$window_uuid" "$clicked"
recreate_read "$window_uuid"
recreate_is "$window_uuid" || exit 0
recreate_paint "$window_uuid"
if [ -n "$(recreate_blocker "$window_uuid")" ]; then
    recreate_tidy "$window_uuid"
    exit 0
fi
image="$(recreate_picked "$window_uuid")"
ui_enable "$window_uuid" "$RECREATE_APPLY_ID" 0
agentvm_box_recreate "$box" "$image"
status=$?
if [ "$status" -ne 0 ]; then
    "$dialog" "$window_uuid" omc_window omc_present_alert "Box $box was not recreated" "$(agentvm_last_error "$status")" "OK::"
    recreate_done "$box"
    recreate_read "$window_uuid"
    recreate_is "$window_uuid" || exit 0
    recreate_paint "$window_uuid"
    recreate_tidy "$window_uuid"
    exit 0
fi
recreate_done "$box"
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
