#!/bin/sh
# AgentVM.update.check.sh
# Check Now, in an image's update window: agent-vm asks Apple which macOS is the newest and keeps
# the answer, and the window says whether the image is behind it. Nothing is installed. When a
# newer macOS turns out to be available, its checkbox is ticked. A window that could not read
# agent-vm on opening gets its first ticks here (update_first_choices). A window that closed
# meanwhile keeps nothing.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.update.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
image="$(update_image "$window_uuid")"
[ -n "$image" ] || exit 0
"$dialog" "$window_uuid" "$UPDATE_NOTE_ID" "Asking Apple for the newest macOS..."
ui_enable "$window_uuid" "$UPDATE_CHECK_ID" 0
update_read "$window_uuid" check
ui_enable "$window_uuid" "$UPDATE_CHECK_ID" 1
toggles=""
update_first_choices "$window_uuid" && toggles="toggles"
if [ -n "$(update_image "$window_uuid")" ] && [ "$(update_field "$window_uuid" updates "$image" 6)" != "-" ]; then
    choices="$(update_choices "$window_uuid" "$image")"
    ui_set choices "$window_uuid" "1 ${choices#* }"
    toggles="toggles"
fi
update_paint "$window_uuid" "$toggles"
[ -n "$(update_image "$window_uuid")" ] || ui_cache_clear "$window_uuid"
exit 0
