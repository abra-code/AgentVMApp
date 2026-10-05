#!/bin/sh
# AgentVM.access.open.sh
# Open the Image, in an image's Full Disk Access guide: status is read again, and when the image
# can still be opened, `image setup` starts as an agent-vm job, which boots the image and shows
# its screen in a window of agent-vm's. The guide follows the job from now, and the main window
# reads the jobs again. agent-vm's refusal is shown in its words.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.access.sh"
# For the one-click-at-a-time mark (wizard_enter).
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
image="$(access_image "$window_uuid")"
[ -n "$image" ] || exit 0
# One click at a time: a second Open the Image clicked while agent-vm is read would start a
# second job, which agent-vm fails (the image is in use).
wizard_enter "$window_uuid" || exit 0
access_refresh "$window_uuid"
# The window closed while agent-vm was read: nothing is started (access_refresh cleared the cache
# folder the reading made again).
[ -n "$(access_image "$window_uuid")" ] || exit 0
[ -z "$(access_blocker "$window_uuid" "$image")" ] || exit 0
case "$(access_phase "$window_uuid" "$image")" in
    needed|granted) ;;
    *) exit 0 ;;
esac
# Off from here: a second click while the job starts must not start a second one.
ui_enable "$window_uuid" "$ACCESS_OPEN_ID" 0
job="$(agentvm_job_image_setup "$image")"
status=$?
if [ "$status" -ne 0 ]; then
    "$dialog" "$window_uuid" omc_window omc_present_alert "Image $image was not opened" \
        "$(agentvm_last_error "$status")" "OK::"
    ui_enable "$window_uuid" "$ACCESS_OPEN_ID" 1
    exit 0
fi
# Followed from now, not from the next reading: one that fails within the moment (no free slot)
# would otherwise never be found on the image, and how it ended never said.
[ -n "$(access_image "$window_uuid")" ] && ui_set job "$window_uuid" "$job"
main_follow_job "$job"
access_refresh "$window_uuid"
access_moving "$window_uuid" || exit 0
access_poll_running "$window_uuid" && exit 0
"$next_command" "$OMC_CURRENT_COMMAND_GUID" "AgentVM.access.poll"
exit 0
