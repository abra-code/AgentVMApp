#!/bin/sh
# AgentVM.main.restore.remove.confirmed.sh
# Remove, in the question of the restore images: each restore image it named is removed (agent-vm
# refuses one a download or a build needs, and the alert says why), status is read again, and a
# toast says what was freed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
names="$(ui_get restore-remove "$window_uuid")"
ui_set restore-remove "$window_uuid" ""
[ -n "$names" ] || exit 0
freed=0
problems=""
for name in $names; do
    bytes="$(agentvm_restore_remove "$name")"
    status=$?
    if [ "$status" -ne 0 ]; then
        problems="$problems$(agentvm_last_error "$status") "
        continue
    fi
    case "$bytes" in
        ''|*[!0123456789]*) ;;
        *) freed=$((freed + bytes)) ;;
    esac
done
main_refresh "$window_uuid" status
if [ -n "$problems" ]; then
    main_alert "$window_uuid" "Not every restore image was removed" "$problems"
elif [ "$freed" -gt 0 ]; then
    "$dialog" "$window_uuid" omc_window omc_present_toast "Restore images removed: $(ui_size_text "$freed") freed." "$MAIN_TOAST_SECONDS"
fi
exit 0
