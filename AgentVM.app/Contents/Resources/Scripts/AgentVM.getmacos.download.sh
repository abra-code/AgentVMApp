#!/bin/sh
# AgentVM.getmacos.download.sh
# Download, in the Get macOS window: status is read again, and when nothing stands in the way
# (no download runs, the file is not here, it fits), `image fetch-ipsw` starts as an agent-vm
# job. The job's progress window opens, the main window reads the jobs again, and this window
# closes. agent-vm's refusal is shown in its words, and the window stays.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.getmacos.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
getmacos_is "$window_uuid" || exit 0
# One click at a time: a second Download clicked while agent-vm is read would start a second job.
wizard_enter "$window_uuid" || exit 0
getmacos_read "$window_uuid"
# The window closed while agent-vm was read: nothing is started, and the cache folder the
# reading made again goes.
if ! getmacos_is "$window_uuid"; then
    ui_cache_clear "$window_uuid"
    exit 0
fi
getmacos_paint "$window_uuid"
# The window closed while this painted: the same. Asked again here because a cache that is gone
# has nothing that stands in the way, and painting made its folder again.
if ! getmacos_is "$window_uuid"; then
    ui_cache_clear "$window_uuid"
    exit 0
fi
[ -z "$(getmacos_blocker "$window_uuid")" ] || exit 0
# Off from here: a second click while the job starts must not start a second one.
ui_enable "$window_uuid" "$GETMACOS_DOWNLOAD_ID" 0
job="$(agentvm_job_fetch_ipsw)"
status=$?
if [ "$status" -ne 0 ]; then
    "$dialog" "$window_uuid" omc_window omc_present_alert "The download was not started" \
        "$(agentvm_last_error "$status")" "OK::"
    ui_enable "$window_uuid" "$GETMACOS_DOWNLOAD_ID" 1
    exit 0
fi
ui_item_open progress "$job" "$OMC_CURRENT_COMMAND_GUID"
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
main_follow_job "$job"
exit 0
