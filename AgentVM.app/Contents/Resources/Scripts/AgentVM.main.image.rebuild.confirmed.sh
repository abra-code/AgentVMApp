#!/bin/sh
# AgentVM.main.image.rebuild.confirmed.sh
# Build Again, in the question AgentVM.main.image.rebuild asked: status is read again, and when the
# image asked about can still be built again, `image rebuild` starts as an agent-vm job, which the
# card and the pane follow (main_image_rebuild). agent-vm's refusal is shown in its words.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"
# For the one-click-at-a-time mark (wizard_enter).
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get image_rebuild "$window_uuid")"
# Read once: a second confirmation, or one without a question, starts nothing.
ui_set image_rebuild "$window_uuid" ""
[ -n "$name" ] && agentvm_valid_name "$name" || exit 0
wizard_enter "$window_uuid" || exit 0
main_read_status "$window_uuid"
read_status=$?
main_paint "$window_uuid"
[ "$read_status" -eq 0 ] || exit 0
main_image_rebuildable "$window_uuid" "$name" || exit 0
# Off from here: the job is being started.
ui_enable "$window_uuid" "$MAIN_IMAGE_REBUILD_ID" 0
main_image_rebuild "$window_uuid" "$name" "$OMC_CURRENT_COMMAND_GUID"
exit 0
