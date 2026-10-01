#!/bin/sh
# AgentVM.update.start.sh
# Update, in an image's update window: status is read again, and when the image can still be
# updated, `image update` with the parts ticked starts as an agent-vm job. The job's progress
# window opens, the main window reads the jobs again, and this window closes. agent-vm's refusal
# is shown in its words, and the window stays.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.update.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
image="$(update_image "$window_uuid")"
[ -n "$image" ] || exit 0
update_read "$window_uuid"
# The window closed while agent-vm was read: nothing is started, and the cache folder the reading
# made again goes.
if [ -z "$(update_image "$window_uuid")" ]; then
    ui_cache_clear "$window_uuid"
    exit 0
fi
update_paint "$window_uuid"
[ -z "$(update_blocker "$window_uuid" "$image")" ] || exit 0
choices="$(update_choices "$window_uuid" "$image")"
[ -n "$(update_flags "$window_uuid" "$image")" ] || exit 0
# Off from here: a second click while the job starts must not start a second one.
ui_enable "$window_uuid" "$UPDATE_START_ID" 0
# Unquoted on purpose: three words, each 0 or 1.
job="$(agentvm_job_image_update "$image" $choices)"
status=$?
if [ "$status" -ne 0 ]; then
    "$dialog" "$window_uuid" omc_window omc_present_alert "The update of image $image was not started" \
        "$(agentvm_last_error "$status")" "OK::"
    ui_enable "$window_uuid" "$UPDATE_START_ID" 1
    exit 0
fi
ui_item_open progress "$job" "$OMC_CURRENT_COMMAND_GUID"
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
update_tell_main "$job"
exit 0
