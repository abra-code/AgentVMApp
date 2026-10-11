#!/bin/sh
# AgentVM.rename.apply.sh
# Rename, in the Rename window: what cannot be a name is refused in the line under the field;
# anything else is asked of agent-vm, at once. Then the windows opened for the old name close,
# the main window shows the box or image under its new name, and this window closes. agent-vm's
# refusal is shown whole, in its words, the window stays, and the main window reads its lists
# again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.rename.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
target="$(rename_target "$window_uuid")"
rename_valid_target "$target" || exit 0
# One click at a time: a second Rename clicked while agent-vm works would ask it twice.
wizard_enter "$window_uuid" || exit 0
kind="${target%%:*}"
name="${target#*:}"
eval "new=\"\${OMC_ACTIONUI_VIEW_${RENAME_NAME_ID}_VALUE:-}\""
blocker="$(rename_blocker "$kind" "$name" "$new")"
"$dialog" "$window_uuid" "$RENAME_NOTE_ID" "$blocker"
[ -z "$blocker" ] || exit 0
ui_enable "$window_uuid" "$RENAME_APPLY_ID" 0
if [ "$kind" = "box" ]; then
    agentvm_box_rename "$name" "$new"
    status=$?
    title="Box $name was not renamed"
else
    agentvm_image_rename "$name" "$new"
    status=$?
    title="Image $name was not renamed"
fi
if [ "$status" -ne 0 ]; then
    "$dialog" "$window_uuid" omc_window omc_present_alert "$title" "$(agentvm_last_error "$status")" "OK::"
    ui_enable "$window_uuid" "$RENAME_APPLY_ID" 1
    # What agent-vm refused for (a box started meanwhile, say) is news to the main window too.
    main_window="$(ui_item_window main window)"
    [ -n "$main_window" ] && main_refresh "$main_window" status
    exit 0
fi
rename_done "$kind" "$name" "$new"
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
