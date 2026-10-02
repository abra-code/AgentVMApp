#!/bin/sh
# AgentVM.newimage.recipe.sh
# Add a Recipe File..., on the Tools step of the New Image window. Its command in Command.json
# has a CHOOSE_FILE_DIALOG, so the engine asks for a file before this runs; Cancel leaves the
# chosen path empty. The checkboxes are kept as this click saw them, and the file, when it is a
# recipe, joins the list with a checkbox of its own, which the user ticks; when it is not, the
# note line says why.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newimage_is "$window_uuid" || exit 0
[ "$(newimage_step "$window_uuid")" = "2" ] || exit 0
# The path is taken as it is, not put on one line: a path changed is another file's path.
file="${OMC_DLG_CHOOSE_FILE_PATH:-}"
[ -n "$file" ] || exit 0
newimage_enter "$window_uuid" || exit 0
newimage_take_ticks "$window_uuid"
why="$(newimage_add_own "$window_uuid" "$file")"
newimage_paint_recipes "$window_uuid"
if [ -n "$why" ]; then
    "$dialog" "$window_uuid" "$NEW_NOTE_ID" "$why"
else
    "$dialog" "$window_uuid" "$NEW_NOTE_ID" "$(agentvm_recipe_name "$file") is in the list now. Tick it to install it."
fi
exit 0
