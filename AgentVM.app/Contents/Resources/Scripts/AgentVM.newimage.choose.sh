#!/bin/sh
# AgentVM.newimage.choose.sh
# Choose..., beside an input file of the Options step in the New Image window. Its command in
# Command.json has a CHOOSE_FILE_DIALOG, so the engine asks for a file before this runs; Cancel
# leaves the chosen path empty. The other fields are kept as this click saw them, and the file
# chosen becomes the value of the option whose button it was, in the field and in what is kept.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newimage_is "$window_uuid" || exit 0
[ "$(newimage_step "$window_uuid")" = "3" ] || exit 0
file="$(ui_one_line "${OMC_DLG_CHOOSE_FILE_PATH:-}")"
[ -n "$file" ] || exit 0
newimage_enter "$window_uuid" || exit 0
case "${OMC_ACTIONUI_TRIGGER_VIEW_ID:-}" in
    ''|*[!0123456789]*) exit 0 ;;
esac
slot=$((OMC_ACTIONUI_TRIGGER_VIEW_ID - NEW_OPTION_CHOOSE_BASE))
if [ "$slot" -lt 1 ] || [ "$slot" -gt "$NEW_OPTION_SLOTS" ]; then
    exit 0
fi
newimage_take_options "$window_uuid"
row="$(newimage_option_rows "$window_uuid" | /usr/bin/sed -n "${slot}p")"
[ "$(printf '%s\n' "$row" | /usr/bin/cut -f1)" = "input" ] || exit 0
newimage_keep_value "$window_uuid" input "$(printf '%s\n' "$row" | /usr/bin/cut -f2)" "$file"
"$dialog" "$window_uuid" "$((NEW_OPTION_FIELD_BASE + slot))" "$file"
"$dialog" "$window_uuid" "$NEW_NOTE_ID" ""
exit 0
