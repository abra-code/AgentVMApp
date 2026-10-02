#!/bin/sh
# AgentVM.newimage.build.sh
# Build, on the last step of the New Image window: agent-vm is read again, and when nothing
# stands in the way, `image create` with what the steps hold starts as an agent-vm job. The job's
# progress window opens, the main window reads the jobs again, and this window closes.
# agent-vm's refusal is shown in its words, and the window stays.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newimage_is "$window_uuid" || exit 0
[ "$(newimage_step "$window_uuid")" = "5" ] || exit 0
# One click at a time: a second Build clicked while agent-vm is read would start a second job.
newimage_enter "$window_uuid" || exit 0
newimage_read "$window_uuid"
# The window closed while agent-vm was read: nothing is started, and the cache folder the reading
# made again goes.
if ! newimage_is "$window_uuid"; then
    ui_cache_clear "$window_uuid"
    exit 0
fi
newimage_paint_check "$window_uuid"
[ -z "$(newimage_blocker "$window_uuid")" ] || exit 0
name="$(ui_get name "$window_uuid")"
# Off from here: a second click while the job starts must not start a second one.
ui_enable "$window_uuid" "$NEW_BUILD_ID" 0
job="$(newimage_args "$window_uuid" | agentvm_job_image_create)"
status=$?
if [ "$status" -ne 0 ]; then
    "$dialog" "$window_uuid" omc_window omc_present_alert "The build of image $name was not started" \
        "$(agentvm_last_error "$status")" "OK::"
    ui_enable "$window_uuid" "$NEW_BUILD_ID" 1
    exit 0
fi
ui_item_open progress "$job" "$OMC_CURRENT_COMMAND_GUID"
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
main_follow_job "$job"
exit 0
