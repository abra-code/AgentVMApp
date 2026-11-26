#!/bin/sh
# AgentVM.exclusions.add.sh
# Add Folder..., in the Exclusions window. Its command in Command.json has a CHOOSE_FOLDER_DIALOG
# that opens in the project, so the engine asks for a folder before this runs; Cancel leaves the
# chosen folder empty. A folder inside the project becomes a checked row (lib.agentvm.exclusions.sh,
# excl_add); nothing is saved until Save.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.exclusions.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
excl_is "$window_uuid" || exit 0
excl_add "$window_uuid" "${OMC_DLG_CHOOSE_FOLDER_PATH:-}"
exit 0
