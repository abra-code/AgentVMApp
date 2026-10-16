#!/bin/sh
# AgentVM.update.input.sh
# Choose <input>..., in a recipe's slot of an image's update window (the second step): a newer
# file for an input of a recipe the image keeps (a newer Xcode .xip). Its command in Command.json
# has a CHOOSE_FILE_DIALOG, so the engine asks for a file before this runs; Cancel leaves the
# chosen path empty and changes nothing. The file is kept for the input the button showed, and
# the window follows. A window that closed meanwhile keeps nothing.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.update.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
image="$(update_image "$window_uuid")"
[ -n "$image" ] || exit 0
file="$(ui_one_line "${OMC_DLG_CHOOSE_FILE_PATH:-}")"
[ -n "$file" ] || exit 0
case "${OMC_ACTIONUI_TRIGGER_VIEW_ID:-}" in
    ''|*[!0123456789]*) exit 0 ;;
esac
slot=$((OMC_ACTIONUI_TRIGGER_VIEW_ID - UPDATE_CHOOSE_BASE))
if [ "$slot" -lt 1 ] || [ "$slot" -gt "$UPDATE_SLOTS" ]; then
    exit 0
fi
# The buttons are on the second step, which is shown only while the tools are ticked.
[ "$(update_step "$window_uuid" "$image")" = "2" ] || exit 0
input="$(update_slot_input "$window_uuid" "$slot")"
[ -n "$input" ] || exit 0
# An input the image still has, by the window's last reading.
known="$(update_input_rows "$window_uuid" "$image" | /usr/bin/awk -F'\t' -v input="$input" '$1 "" == input { print "yes"; exit }')"
[ "$known" = "yes" ] || exit 0
update_choose "$window_uuid" "$input" "$file"
update_paint "$window_uuid"
[ -n "$(update_image "$window_uuid")" ] || ui_cache_clear "$window_uuid"
exit 0
