#!/bin/sh
# AgentVM.main.image.logs.build.sh
# Show Build Log, on the Logs row of the image pane: the log of the job that last built
# or updated the selected image, selected in a Finder window. Nothing when no image is selected,
# or agent-vm lists no such job any more.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get image "$window_uuid")"
[ -n "$name" ] || exit 0
job="$(main_image_log_job "$window_uuid" "$name")"
[ -n "$job" ] || exit 0
main_show_file "$(printf '%s\n' "$job" | /usr/bin/cut -f18)/log"
exit 0
